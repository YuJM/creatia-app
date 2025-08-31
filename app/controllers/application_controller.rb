class ApplicationController < ActionController::Base
  # Include AppRoutes constants
  include AppRoutes
  
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  # Multi-tenancy support
  set_current_tenant_through_filter
  before_action :set_current_tenant
  before_action :authenticate_user!, unless: :skip_authentication?
  before_action :ensure_organization_access, unless: :skip_organization_check?
  
  # Logging
  after_action :log_activity, unless: :skip_logging?
  after_action :track_user_action, unless: :skip_action_tracking?
  around_action :handle_exceptions
  
  # Devise 인증 메서드 정의
  helper_method :user_signed_in?, :current_user
  
  def authenticate_user!
    unless user_signed_in?
      # API 요청인 경우 401 반환
      if request.format.json?
        render json: { error: 'Authentication required' }, status: :unauthorized
      else
        # 현재 서브도메인을 return_to 파라미터로 전달
        subdomain = DomainService.extract_subdomain(request)
        return_param = subdomain.present? && !DomainService.reserved_subdomain?(subdomain) ? "?return_to=#{subdomain}" : ""
        redirect_to DomainService.auth_url("login#{return_param}"), allow_other_host: true
      end
    end
  end
  
  def user_signed_in?
    current_user.present?
  end
  
  def current_user
    return @current_user if defined?(@current_user)
    
    # 1. Warden에서 확인
    if warden && warden.user(:user)
      user_data = warden.user(:user)
      # Handle different data types returned by warden
      @current_user = case user_data
                      when Array
                        # Devise 직렬화에서 배열이 반환되는 경우
                        user_data.first.is_a?(User) ? user_data.first : User.find(user_data.first)
                      when Hash
                        # If warden returns a hash (can happen in tests)
                        User.find_by(id: user_data['id'] || user_data[:id])
                      when User
                        # 이미 User 객체인 경우
                        user_data
                      else
                        # ID나 다른 형태인 경우
                        user_data.is_a?(Integer) ? User.find(user_data) : user_data
                      end
    # 2. JWT 토큰에서 확인 (크로스 도메인 지원)
    elsif cookies[:jwt_access_token].present? || cookies[:jwt_refresh_token].present?
      @current_user = authenticate_from_jwt_token
    else
      @current_user = nil
    end
  end
  
  def authenticate_from_jwt_token
    # JWT 액세스 토큰 확인
    access_token = cookies[:jwt_access_token]
    
    # 액세스 토큰이 없거나 만료된 경우 리프레시 토큰으로 갱신 시도
    if access_token.blank?
      access_token = refresh_jwt_access_token
      return nil unless access_token
    end
    
    # JWT 토큰 검증
    token_data = JwtService.verify_sso_token(access_token)
    return nil unless token_data
    
    # 사용자 찾기 및 Warden 세션 설정
    user = token_data[:user]
    if user && warden
      warden.set_user(user, scope: :user)
    end
    
    user
  rescue => e
    Rails.logger.error "JWT Authentication Error: #{e.message}"
    nil
  end
  
  # JWT 액세스 토큰 갱신
  def refresh_jwt_access_token
    refresh_token = cookies[:jwt_refresh_token]
    return nil unless refresh_token
    
    # 새 액세스 토큰 발급
    new_access_token = JwtService.refresh_access_token(refresh_token)
    return nil unless new_access_token
    
    # 쿠키 업데이트
    domain = Rails.env.production? ? ".creatia.io" : ".creatia.local"
    cookies[:jwt_access_token] = {
      value: new_access_token,
      domain: domain,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax,
      expires: 8.hours.from_now
    }
    
    new_access_token
  end
  
  private
  
  def warden
    request.env['warden']
  end
  
  # CanCanCan authorization check
  check_authorization unless: :skip_authorization?
  
  # CanCanCan exception handling
  rescue_from CanCan::AccessDenied, with: :access_denied
  rescue_from ActsAsTenant::Errors::NoTenantSet, with: :tenant_not_found
  
  protected
  
  # 현재 조직 반환
  def current_organization
    ActsAsTenant.current_tenant
  end
  helper_method :current_organization
  
  # 현재 사용자의 조직에서의 멤버십 반환
  def current_membership
    return nil unless current_user && current_organization
    @current_membership ||= current_user.organization_memberships
                                       .find_by(organization: current_organization, active: true)
  end
  helper_method :current_membership
  
  # 현재 사용자의 조직에서의 역할 반환
  def current_role
    current_membership&.role
  end
  helper_method :current_role
  
  # CanCanCan을 위한 current_ability 메서드
  def current_ability
    @current_ability ||= Ability.new(current_user, current_organization)
  end
  
  # 테넌트 컨텍스트 정보 반환
  def tenant_context
    @tenant_context
  end
  helper_method :tenant_context
  
  # 테넌트 전환 서비스 반환
  def tenant_switcher
    @tenant_switcher ||= TenantSwitcher.new(current_user, session)
  end
  helper_method :tenant_switcher
  
  private
  
  # 멀티테넌트 설정
  def set_current_tenant
    # 인증이 필요하지 않은 컨트롤러에서는 current_user가 nil일 수 있음
    user = user_signed_in? ? current_user : nil
    @tenant_context = TenantContextService.new(request, user)
    
    begin
      @tenant_context.setup_tenant_context!
    rescue TenantContextService::TenantNotFound => e
      raise ActionController::RoutingError, e.message
    rescue TenantContextService::AccessDenied => e
      redirect_to_auth_with_error(e.message)
    rescue TenantContextService::InvalidTenant => e
      redirect_to_auth_with_error(e.message)
    end
  end
  
  # 조직 접근 권한 확인
  def ensure_organization_access
    return unless current_organization && current_user
    return if @tenant_context&.user_can_access?
    
    redirect_to_auth_with_error("이 조직에 접근할 권한이 없습니다.")
  end
  
  def redirect_to_auth_with_error(message)
    if request.format.json?
      render json: { error: message }, status: :forbidden
    else
      flash[:alert] = message
      # 무한 리다이렉트 방지: auth 도메인으로 리다이렉트
      subdomain = DomainService.extract_subdomain(request)
      return_param = subdomain.present? && !DomainService.reserved_subdomain?(subdomain) ? "?return_to=#{subdomain}" : ""
      redirect_to DomainService.auth_url("login#{return_param}"), allow_other_host: true
    end
  end
  
  # Skip 조건들
  def skip_authentication?
    devise_controller? || 
    params[:controller] =~ /(^(rails_)?admin)|(^pages$)/ ||
    params[:controller] == 'users/omniauth_callbacks'
  end
  
  def skip_organization_check?
    devise_controller? || 
    params[:controller] =~ /(^(rails_)?admin)|(^pages$)/ ||
    params[:controller] == 'users/omniauth_callbacks' ||
    !current_organization
  end
  
  # Alba JSON Serialization 헬퍼 메서드들
  
  # 기본적인 직렬화를 수행합니다.
  # @param serializer_class [Class] 사용할 Serializer 클래스
  # @param object [Object] 직렬화할 객체 (단일 객체 또는 컬렉션)
  # @param options [Hash] 추가 옵션 (status, params 등)
  def render_serialized(serializer_class, object, options = {})
    params_hash = options[:params] || {}
    
    # 자동으로 전달되는 컨텍스트들
    params_hash[:time_helper] = helpers unless params_hash.key?(:time_helper)
    params_hash[:current_user] = current_user unless params_hash.key?(:current_user)
    params_hash[:current_organization] = current_organization unless params_hash.key?(:current_organization)
    params_hash[:current_membership] = current_membership unless params_hash.key?(:current_membership)
    
    render json: serializer_class.new(object, params: params_hash).serializable_hash, 
           status: options[:status] || :ok
  end
  
  # 성공 응답 형태로 래핑하여 직렬화합니다.
  # @param serializer_class [Class] 사용할 Serializer 클래스
  # @param object [Object] 직렬화할 객체
  # @param options [Hash] 추가 옵션
  def render_with_success(serializer_class, object, options = {})
    params_hash = options[:params] || {}
    
    # 자동으로 전달되는 컨텍스트들
    params_hash[:time_helper] = helpers unless params_hash.key?(:time_helper)
    params_hash[:current_user] = current_user unless params_hash.key?(:current_user)
    params_hash[:current_organization] = current_organization unless params_hash.key?(:current_organization)
    params_hash[:current_membership] = current_membership unless params_hash.key?(:current_membership)
    
    render json: {
      success: true,
      data: serializer_class.new(object, params: params_hash).serializable_hash
    }, status: options[:status] || :ok
  end
  
  # 에러 응답을 표준화된 형태로 반환합니다.
  # @param errors [ActiveModel::Errors, String, Array] 에러 데이터
  # @param options [Hash] 추가 옵션 (status, single_error 등)
  def render_error(errors, options = {})
    error_data = {
      success: false,
      errors: errors
    }
    
    # 단일 에러 메시지가 지정된 경우 우선 사용
    if options[:single_error]
      error_data[:errors] = options[:single_error]
    end
    
    render json: ErrorSerializer.new(error_data).serializable_hash,
           status: options[:status] || :unprocessable_entity
  end
  
  def access_denied(exception)
    # 무권한 접근 감사 로그
    if current_user && current_organization
      PermissionAuditLog.log_denial(
        user: current_user,
        organization: current_organization,
        action: exception.action,
        resource: exception.subject,
        context: { message: exception.message },
        request: request
      )
    end
    
    if request.format.json?
      render json: { error: exception.message || "이 작업을 수행할 권한이 없습니다." }, status: :forbidden
    else
      flash[:alert] = exception.message || "이 작업을 수행할 권한이 없습니다."
      redirect_to(request.referrer || root_path, allow_other_host: true)
    end
  end
  
  def tenant_not_found
    if request.format.json?
      render json: { error: "조직을 찾을 수 없습니다." }, status: :not_found
    else
      flash[:alert] = "조직을 찾을 수 없습니다."
      redirect_to DomainService.main_url, allow_other_host: true
    end
  end
  
  def route_not_found
    subdomain = DomainService.extract_subdomain(request)
    
    if request.format.json?
      render json: { 
        error: "조직을 찾을 수 없습니다: #{subdomain}",
        suggested_url: DomainService.main_url
      }, status: :not_found
    else
      flash[:alert] = "조직 '#{subdomain}'을 찾을 수 없습니다."
      redirect_to DomainService.main_url, allow_other_host: true
    end
  end
  
  def skip_authorization?
    devise_controller? || 
    params[:controller] =~ /(^(rails_)?admin)|(^pages$)/ || 
    params[:controller] == 'users/omniauth_callbacks' ||
    params[:controller] =~ /^devise/ ||
    params[:controller] =~ /^organizations/ # 조직 관리는 별도 처리
  end
  
  def skip_logging?
    # health check나 시스템 endpoint는 로깅하지 않음
    params[:controller] == 'up' ||
    params[:controller] =~ /^rails\/conductor/ ||
    params[:controller] =~ /^active_storage/
  end
  
  def skip_action_tracking?
    # 액션 추적을 건너뛸 조건
    skip_logging? ||
    devise_controller? ||
    request.format.json? == false && action_name == 'index' # 리스트 조회는 제외
  end
  
  # 활동 로깅
  def log_activity
    LogService.log_activity(
      self,
      action_name,
      current_user,
      current_organization,
      metadata: log_metadata
    )
  end
  
  # 사용자 액션 추적 (MongoDB)
  def track_user_action
    return unless current_user
    
    # 리소스 찾기
    resource = find_tracked_resource
    return unless resource
    
    # 액션 타입 결정
    action_type = determine_action_type
    
    # UserActionLog에 기록
    metadata = {
      controller: controller_name,
      action: action_name,
      response_status: response.status
    }
    metadata[:duration_ms] = (Time.current - @_start_time) * 1000 if @_start_time
    
    UserActionLog.track(
      current_user,
      action_type,
      resource,
      request,
      metadata
    )
  rescue => e
    Rails.logger.error "Failed to track user action: #{e.message}"
  end
  
  # 추적할 리소스 찾기
  def find_tracked_resource
    # 일반적인 RESTful 패턴 처리
    if params[:id].present?
      model_class = controller_name.classify.safe_constantize
      model_class&.find_by(id: params[:id])
    elsif instance_variable_defined?("@#{controller_name.singularize}")
      instance_variable_get("@#{controller_name.singularize}")
    elsif instance_variable_defined?("@#{controller_name}")
      collection = instance_variable_get("@#{controller_name}")
      collection.is_a?(ActiveRecord::Relation) ? collection.first : collection
    else
      current_organization # 기본값으로 현재 조직
    end
  end
  
  # 액션 타입 결정
  def determine_action_type
    case action_name
    when 'show', 'index'
      'view'
    when 'new'
      'preview'
    when 'create'
      'create'
    when 'edit'
      'preview'
    when 'update'
      'update'
    when 'destroy'
      'delete'
    else
      action_name # 기본값으로 액션 이름 사용
    end
  end
  
  # 예외 처리 및 에러 로깅
  def handle_exceptions
    yield
  rescue => exception
    LogService.log_error(exception, self, current_user, current_organization)
    raise # 에러를 다시 발생시켜 Rails의 기본 에러 처리가 동작하도록 함
  end
  
  # 로깅에 포함할 추가 메타데이터
  def log_metadata
    {
      session_id: session.id,
      request_id: request.request_id,
      subdomain: DomainService.extract_subdomain(request)
    }
  end
end
