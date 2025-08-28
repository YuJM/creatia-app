# frozen_string_literal: true

# TenantSecurity - 테넌트 격리 보안을 위한 Concern
# 
# 이 모듈은 다음을 제공합니다:
# - 크로스 테넌트 접근 방지
# - SQL 인젝션 방지를 위한 서브도메인 검증
# - 메모리 정리 및 세션 보안
# - 감사 로그 기록
module TenantSecurity
  extend ActiveSupport::Concern
  
  included do
    before_action :verify_tenant_isolation
    after_action :clear_tenant_data
    around_action :audit_tenant_access
  end
  
  private
  
  # 테넌트 격리 보안 검증
  def verify_tenant_isolation
    # 서브도메인 검증 (SQL 인젝션 방지)
    verify_subdomain_format
    
    # 테넌트 컨텍스트 검증
    verify_tenant_context_integrity
    
    # 사용자 권한 검증
    verify_user_tenant_permissions if current_user
    
    # 세션 보안 검증
    verify_session_security
  end
  
  # 요청 종료 후 테넌트 데이터 정리
  def clear_tenant_data
    # 메모리에서 민감한 테넌트 정보 제거
    clear_sensitive_instance_variables
    
    # 테넌트 컨텍스트 리셋 (개발 환경에서만)
    ActsAsTenant.current_tenant = nil if Rails.env.development?
  end
  
  # 테넌트 접근 감사 로그
  def audit_tenant_access
    start_time = Time.current
    
    begin
      yield
    ensure
      log_tenant_access(start_time, Time.current)
    end
  end
  
  # 서브도메인 형식 검증 (SQL 인젝션 방지)
  def verify_subdomain_format
    subdomain = DomainService.extract_subdomain(request)
    return if subdomain.blank?
    
    # 서브도메인 형식 검증 (영숫자, 하이픈만 허용)
    unless subdomain.match?(/\A[a-z0-9\-]{1,63}\z/)
      Rails.logger.security "Invalid subdomain format detected: #{subdomain.inspect}"
      raise ActionController::BadRequest, "유효하지 않은 서브도메인 형식입니다"
    end
    
    # 예약된 서브도메인 체크
    if DomainService.reserved_subdomain?(subdomain)
      return # 예약된 서브도메인은 정상 처리
    end
    
    # 존재하지 않는 조직에 대한 접근 차단
    unless Organization.exists?(subdomain: subdomain)
      Rails.logger.security "Access attempt to non-existent organization: #{subdomain}"
      raise ActionController::RoutingError, "조직을 찾을 수 없습니다"
    end
  end
  
  # 테넌트 컨텍스트 무결성 검증
  def verify_tenant_context_integrity
    current_tenant = ActsAsTenant.current_tenant
    return unless current_tenant
    
    # 현재 요청의 서브도메인과 설정된 테넌트가 일치하는지 확인
    request_subdomain = DomainService.extract_subdomain(request)
    
    if request_subdomain.present? && 
       !DomainService.reserved_subdomain?(request_subdomain) &&
       current_tenant.subdomain != request_subdomain
      
      Rails.logger.security "Tenant context mismatch: request=#{request_subdomain}, context=#{current_tenant.subdomain}"
      ActsAsTenant.current_tenant = nil
      raise ActionController::Forbidden, "테넌트 컨텍스트가 일치하지 않습니다"
    end
  end
  
  # 사용자의 테넌트 권한 검증
  def verify_user_tenant_permissions
    current_tenant = ActsAsTenant.current_tenant
    return unless current_tenant
    
    # 사용자가 현재 테넌트에 접근할 권한이 있는지 확인
    unless current_user.can_access?(current_tenant)
      Rails.logger.security "Unauthorized tenant access: user=#{current_user.id}, tenant=#{current_tenant.subdomain}"
      
      # 세션에서 조직 정보 제거
      session.delete(:current_organization_id)
      
      # 접근 거부 처리
      handle_unauthorized_tenant_access(current_tenant)
    end
  end
  
  # 세션 보안 검증
  def verify_session_security
    # 세션 하이재킹 방지를 위한 IP 확인 (선택적)
    if Rails.env.production? && session[:last_ip] && session[:last_ip] != request.remote_ip
      Rails.logger.security "Session IP mismatch: stored=#{session[:last_ip]}, current=#{request.remote_ip}"
      reset_session
      redirect_to DomainService.auth_url('login'), alert: "보안상의 이유로 다시 로그인해주세요.", allow_other_host: true
      return false
    end
    
    # 세션 IP 업데이트
    session[:last_ip] = request.remote_ip
    
    # 세션 타임아웃 검증
    verify_session_timeout
  end
  
  # 세션 타임아웃 검증
  def verify_session_timeout
    return unless session[:last_activity_at]
    
    last_activity = Time.parse(session[:last_activity_at])
    timeout_duration = Rails.env.production? ? 8.hours : 24.hours
    
    if last_activity < timeout_duration.ago
      Rails.logger.security "Session timeout: user=#{current_user&.id}, last_activity=#{last_activity}"
      reset_session
      redirect_to DomainService.auth_url('login'), alert: "세션이 만료되었습니다. 다시 로그인해주세요.", allow_other_host: true
      return false
    end
    
    # 마지막 활동 시간 업데이트
    session[:last_activity_at] = Time.current.iso8601
  end
  
  # 민감한 인스턴스 변수 정리
  def clear_sensitive_instance_variables
    sensitive_vars = %w[@tenant_context @tenant_switcher @current_membership @current_organization]
    
    sensitive_vars.each do |var|
      instance_variable_set(var, nil) if instance_variable_defined?(var)
    end
  end
  
  # 무권한 테넌트 접근 처리
  def handle_unauthorized_tenant_access(organization)
    if request.format.json?
      render json: { 
        error: "이 조직에 접근할 권한이 없습니다.",
        organization: organization.subdomain,
        redirect_url: DomainService.auth_url("access_denied?org=#{organization.subdomain}")
      }, status: :forbidden
    else
      redirect_to DomainService.auth_url("access_denied?org=#{organization.subdomain}"), allow_other_host: true
    end
  end
  
  # 테넌트 접근 로그 기록
  def log_tenant_access(start_time, end_time)
    return unless Rails.env.production? || ENV['LOG_TENANT_ACCESS'] == 'true'
    
    log_data = {
      timestamp: start_time.iso8601,
      duration_ms: ((end_time - start_time) * 1000).round(2),
      user_id: current_user&.id,
      tenant_subdomain: ActsAsTenant.current_tenant&.subdomain,
      request_subdomain: DomainService.extract_subdomain(request),
      controller: params[:controller],
      action: params[:action],
      method: request.method,
      path: request.path,
      ip_address: request.remote_ip,
      user_agent: request.user_agent&.truncate(100),
      session_id: session.id&.truncate(10)
    }
    
    Rails.logger.tagged("TENANT_ACCESS") do
      Rails.logger.info log_data.to_json
    end
  end
  
  class_methods do
    # 특정 액션에서 테넌트 보안 체크를 건너뛰기
    def skip_tenant_security(*actions)
      skip_before_action :verify_tenant_isolation, only: actions
      skip_after_action :clear_tenant_data, only: actions
      skip_around_action :audit_tenant_access, only: actions
    end
    
    # 강화된 보안 모드 활성화
    def enable_enhanced_tenant_security
      before_action :verify_csrf_token_for_tenant_actions
      before_action :verify_request_origin
      after_action :add_security_headers
    end
  end
  
  # CSRF 토큰 검증 (테넌트 관련 액션)
  def verify_csrf_token_for_tenant_actions
    return unless request.post? || request.patch? || request.put? || request.delete?
    return if request.format.json? && api_request?
    
    verify_authenticity_token
  end
  
  # 요청 출처 검증
  def verify_request_origin
    return unless Rails.env.production?
    return unless request.referer
    
    allowed_origins = [
      DomainService.base_domain,
      "auth.#{DomainService.base_domain}",
      "*.#{DomainService.base_domain}"
    ]
    
    referer_host = URI.parse(request.referer).host
    unless allowed_origins.any? { |origin| origin.include?('*') ? referer_host.ends_with?(origin.gsub('*.', '')) : referer_host == origin }
      Rails.logger.security "Suspicious request origin: #{request.referer}"
      head :forbidden
    end
  rescue URI::InvalidURIError
    Rails.logger.security "Invalid referer URI: #{request.referer}"
    head :forbidden
  end
  
  # 보안 헤더 추가
  def add_security_headers
    response.headers['X-Tenant-Context'] = ActsAsTenant.current_tenant&.subdomain || 'none'
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'SAMEORIGIN'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    
    if Rails.env.production?
      response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
    end
  end
  
  # API 요청인지 확인
  def api_request?
    request.headers['Content-Type']&.include?('application/json') ||
    request.headers['Accept']&.include?('application/json') ||
    params[:format] == 'json'
  end
end
