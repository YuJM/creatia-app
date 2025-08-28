# frozen_string_literal: true

# SecurityAuditService - 보안 감사 로깅 서비스
# 
# 이 서비스는 다음을 제공합니다:
# - 보안 이벤트 로깅
# - 의심스러운 활동 탐지
# - 감사 로그 분석
# - 보안 알림 발송
class SecurityAuditService
  class << self
    prepend MemoWise
  end
  # 보안 이벤트 유형
  SECURITY_EVENTS = {
    # 인증 관련
    login_success: 'LOGIN_SUCCESS',
    login_failure: 'LOGIN_FAILURE',
    logout: 'LOGOUT',
    password_change: 'PASSWORD_CHANGE',
    account_locked: 'ACCOUNT_LOCKED',
    
    # 권한 관련
    unauthorized_access: 'UNAUTHORIZED_ACCESS',
    privilege_escalation: 'PRIVILEGE_ESCALATION',
    permission_denied: 'PERMISSION_DENIED',
    
    # 테넌트 관련
    tenant_switch: 'TENANT_SWITCH',
    cross_tenant_access: 'CROSS_TENANT_ACCESS',
    tenant_data_breach: 'TENANT_DATA_BREACH',
    
    # 데이터 관련
    sensitive_data_access: 'SENSITIVE_DATA_ACCESS',
    data_export: 'DATA_EXPORT',
    bulk_operation: 'BULK_OPERATION',
    
    # 시스템 관련
    suspicious_activity: 'SUSPICIOUS_ACTIVITY',
    rate_limit_exceeded: 'RATE_LIMIT_EXCEEDED',
    invalid_request: 'INVALID_REQUEST',
    
    # 관리 관련
    admin_action: 'ADMIN_ACTION',
    configuration_change: 'CONFIGURATION_CHANGE',
    user_management: 'USER_MANAGEMENT'
  }.freeze
  
  # 위험 수준
  RISK_LEVELS = {
    low: 'LOW',
    medium: 'MEDIUM',
    high: 'HIGH',
    critical: 'CRITICAL'
  }.freeze
  
  class << self
    # 보안 이벤트 로깅
    def log_security_event(event_type, details = {})
      return unless enabled?
      
      event_data = build_event_data(event_type, details)
      
      # 로그 기록
      write_security_log(event_data)
      
      # 위험 수준에 따른 추가 처리
      handle_risk_level(event_data)
      
      # 의심스러운 패턴 감지
      detect_suspicious_patterns(event_data)
      
      event_data
    end
    
    # 로그인 성공 이벤트
    def log_login_success(user, request, additional_data = {})
      log_security_event(:login_success, {
        user_id: user.id,
        email: user.email,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        subdomain: extract_subdomain(request),
        session_id: request.session.id,
        **additional_data
      }.merge(risk_level: :low))
    end
    
    # 로그인 실패 이벤트
    def log_login_failure(email, request, reason = nil)
      log_security_event(:login_failure, {
        email: email,
        reason: reason,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        subdomain: extract_subdomain(request),
        risk_level: determine_login_failure_risk(email, request.remote_ip)
      })
    end
    
    # 무권한 접근 이벤트
    def log_unauthorized_access(user, resource, request, action = nil)
      log_security_event(:unauthorized_access, {
        user_id: user&.id,
        email: user&.email,
        resource_type: resource.class.name,
        resource_id: resource.try(:id),
        action: action,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        subdomain: extract_subdomain(request),
        tenant_id: ActsAsTenant.current_tenant&.id,
        risk_level: :medium
      })
    end
    
    # 테넌트 전환 이벤트
    def log_tenant_switch(user, from_tenant, to_tenant, request)
      log_security_event(:tenant_switch, {
        user_id: user.id,
        email: user.email,
        from_tenant_id: from_tenant&.id,
        from_tenant_subdomain: from_tenant&.subdomain,
        to_tenant_id: to_tenant.id,
        to_tenant_subdomain: to_tenant.subdomain,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        risk_level: :low
      })
    end
    
    # 크로스 테넌트 접근 시도 이벤트
    def log_cross_tenant_access(user, requested_tenant, current_tenant, request)
      log_security_event(:cross_tenant_access, {
        user_id: user&.id,
        email: user&.email,
        requested_tenant_id: requested_tenant&.id,
        requested_tenant_subdomain: requested_tenant&.subdomain,
        current_tenant_id: current_tenant&.id,
        current_tenant_subdomain: current_tenant&.subdomain,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        risk_level: :high
      })
    end
    
    # 민감한 데이터 접근 이벤트
    def log_sensitive_data_access(user, data_type, request, details = {})
      log_security_event(:sensitive_data_access, {
        user_id: user.id,
        email: user.email,
        data_type: data_type,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        subdomain: extract_subdomain(request),
        tenant_id: ActsAsTenant.current_tenant&.id,
        risk_level: :medium,
        **details
      })
    end
    
    # Rate limit 초과 이벤트
    def log_rate_limit_exceeded(request, limit_type, current_count, max_count)
      log_security_event(:rate_limit_exceeded, {
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        subdomain: extract_subdomain(request),
        limit_type: limit_type,
        current_count: current_count,
        max_count: max_count,
        path: request.path,
        method: request.method,
        risk_level: determine_rate_limit_risk(limit_type, current_count, max_count)
      })
    end
    
    # 관리자 액션 이벤트
    def log_admin_action(admin_user, action, target, request, details = {})
      log_security_event(:admin_action, {
        admin_user_id: admin_user.id,
        admin_email: admin_user.email,
        action: action,
        target_type: target.class.name,
        target_id: target.try(:id),
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        subdomain: extract_subdomain(request),
        risk_level: :medium,
        **details
      })
    end
    
    # 의심스러운 활동 패턴 감지
    def detect_suspicious_patterns(event_data)
      # 같은 IP에서 연속 로그인 실패
      detect_brute_force_attacks(event_data)
      
      # 비정상적인 시간대 접근
      detect_unusual_access_times(event_data)
      
      # 지리적으로 불가능한 접근
      detect_impossible_travel(event_data)
      
      # 비정상적인 테넌트 전환 패턴
      detect_unusual_tenant_switching(event_data)
    end
    
    # 보안 메트릭 수집
    def collect_security_metrics(time_range = 24.hours)
      end_time = Time.current
      start_time = end_time - time_range
      
      {
        total_events: count_events_in_range(start_time, end_time),
        events_by_type: count_events_by_type(start_time, end_time),
        events_by_risk_level: count_events_by_risk_level(start_time, end_time),
        top_source_ips: top_source_ips(start_time, end_time),
        failed_logins: count_failed_logins(start_time, end_time),
        unauthorized_access_attempts: count_unauthorized_access(start_time, end_time),
        cross_tenant_access_attempts: count_cross_tenant_access(start_time, end_time)
      }
    end
    
    private
    
    # 보안 로깅 활성화 여부
    def enabled?
      Rails.env.production? || ENV['ENABLE_SECURITY_AUDIT'] == 'true'
    end
    
    # 이벤트 데이터 구성
    def build_event_data(event_type, details)
      {
        event_id: SecureRandom.uuid,
        event_type: SECURITY_EVENTS[event_type] || event_type.to_s.upcase,
        timestamp: Time.current.iso8601,
        risk_level: details[:risk_level] || :low,
        environment: Rails.env,
        application: 'creatia-app',
        version: Rails.application.config.try(:version) || '1.0.0',
        **details.except(:risk_level)
      }
    end
    
    # 보안 로그 작성
    def write_security_log(event_data)
      # 구조화된 로그 형태로 기록
      Rails.logger.tagged("SECURITY", event_data[:event_type], event_data[:risk_level]) do
        Rails.logger.info event_data.to_json
      end
      
      # 프로덕션에서는 별도 보안 로그 파일에도 기록
      if Rails.env.production?
        security_logger.info event_data.to_json
      end
    end
    
    # 위험 수준별 처리
    def handle_risk_level(event_data)
      case event_data[:risk_level].to_s
      when 'HIGH', 'CRITICAL'
        # 즉시 알림 발송
        send_security_alert(event_data)
        
        # 슬랙/이메일 알림 (프로덕션)
        notify_security_team(event_data) if Rails.env.production?
      when 'MEDIUM'
        # 일정 횟수 이상 발생시 알림
        check_medium_risk_threshold(event_data)
      end
    end
    
    # 로그인 실패 위험도 결정
    def determine_login_failure_risk(email, ip_address)
      # 최근 실패 횟수 확인
      recent_failures = count_recent_login_failures(email, ip_address, 1.hour)
      
      case recent_failures
      when 0..2 then :low
      when 3..5 then :medium
      when 6..10 then :high
      else :critical
      end
    end
    
    # Rate limit 위험도 결정
    def determine_rate_limit_risk(limit_type, current_count, max_count)
      ratio = current_count.to_f / max_count
      
      case ratio
      when 0..1.5 then :low
      when 1.5..3.0 then :medium
      when 3.0..5.0 then :high
      else :critical
      end
    end
    
    # 브루트포스 공격 감지
    def detect_brute_force_attacks(event_data)
      return unless event_data[:event_type] == 'LOGIN_FAILURE'
      
      ip_address = event_data[:ip_address]
      failures_in_hour = count_recent_login_failures(nil, ip_address, 1.hour)
      
      if failures_in_hour >= 10
        log_security_event(:suspicious_activity, {
          activity_type: 'brute_force_attack',
          ip_address: ip_address,
          failure_count: failures_in_hour,
          time_window: '1 hour',
          risk_level: :critical
        })
      end
    end
    
    # 비정상적인 접근 시간 감지
    def detect_unusual_access_times(event_data)
      return unless event_data[:user_id]
      
      hour = Time.current.hour
      # 새벽 2-6시 접근을 의심스러운 시간으로 간주
      if hour.between?(2, 6)
        log_security_event(:suspicious_activity, {
          activity_type: 'unusual_access_time',
          user_id: event_data[:user_id],
          access_hour: hour,
          risk_level: :medium
        })
      end
    end
    
    # 지리적으로 불가능한 이동 감지 (간단 버전)
    def detect_impossible_travel(event_data)
      # 실제 구현에서는 IP 지리적 위치 서비스 사용
      # 여기서는 간단히 다른 국가 IP 변경을 감지
    end
    
    # 비정상적인 테넌트 전환 패턴 감지
    def detect_unusual_tenant_switching(event_data)
      return unless event_data[:event_type] == 'TENANT_SWITCH'
      
      user_id = event_data[:user_id]
      switches_in_hour = count_recent_tenant_switches(user_id, 1.hour)
      
      if switches_in_hour >= 20
        log_security_event(:suspicious_activity, {
          activity_type: 'excessive_tenant_switching',
          user_id: user_id,
          switch_count: switches_in_hour,
          time_window: '1 hour',
          risk_level: :high
        })
      end
    end
    
    # 보안 알림 발송
    def send_security_alert(event_data)
      # 실시간 알림 시스템 (WebSocket, Push 등)
      Rails.logger.warn "HIGH RISK SECURITY EVENT: #{event_data[:event_type]}"
    end
    
    # 보안팀 알림
    def notify_security_team(event_data)
      # 이메일, 슬랙 등을 통한 알림
      # 실제 환경에서는 AlertManager, PagerDuty 등 사용
    end
    
    # 서브도메인 추출 (메모이제이션 적용)
    memo_wise def extract_subdomain(request)
      return nil unless request.respond_to?(:subdomain)
      request.subdomain.presence
    end
    
    # 보안 전용 로거 (메모이제이션 적용)
    memo_wise def security_logger
      Logger.new(Rails.root.join('log', 'security.log'))
    end
    
    # 헬퍼 메서드들 (실제 구현에서는 Redis나 DB 사용)
    # 메모이제이션 적용: 같은 email/IP/시간범위로 반복 호출 시 캐시된 결과 반환
    memo_wise def count_recent_login_failures(email, ip_address, time_range)
      # 간단한 구현 - 실제로는 Redis나 로그 분석 사용
      rand(0..15)
    end
    
    # 메모이제이션 적용: 같은 user_id/시간범위로 반복 호출 시 캐시된 결과 반환
    memo_wise def count_recent_tenant_switches(user_id, time_range)
      # 간단한 구현 - 실제로는 Redis나 DB 사용
      rand(0..25)
    end
    
    def count_events_in_range(start_time, end_time)
      rand(100..1000)
    end
    
    def count_events_by_type(start_time, end_time)
      SECURITY_EVENTS.values.map { |type| [type, rand(10..100)] }.to_h
    end
    
    def count_events_by_risk_level(start_time, end_time)
      RISK_LEVELS.values.map { |level| [level, rand(5..50)] }.to_h
    end
    
    def top_source_ips(start_time, end_time)
      5.times.map { Faker::Internet.ip_v4_address }
    end
    
    def count_failed_logins(start_time, end_time)
      rand(20..200)
    end
    
    def count_unauthorized_access(start_time, end_time)
      rand(5..50)
    end
    
    def count_cross_tenant_access(start_time, end_time)
      rand(0..10)
    end
    
    def check_medium_risk_threshold(event_data)
      # 중위험 이벤트 임계치 확인 로직
    end
  end
end
