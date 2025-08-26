# frozen_string_literal: true

# 시스템 레벨 통합 테스트를 위한 헬퍼 메서드들
module SystemTestHelpers
  # 애플리케이션 부팅 상태 확인
  def ensure_application_booted
    return if @application_booted

    Rails.application.initialize! unless Rails.application.initialized?
    @application_booted = true
  end

  # 서브도메인 시뮬레이션
  def simulate_subdomain(subdomain)
    allow(DomainService).to receive(:extract_subdomain).and_return(subdomain)
    
    if subdomain.present?
      allow_any_instance_of(ActionController::TestRequest)
        .to receive(:subdomain).and_return(subdomain)
      allow_any_instance_of(ActionDispatch::Request)
        .to receive(:subdomain).and_return(subdomain)
    end
  end

  # 테넌트 컨텍스트 설정
  def set_tenant_context(organization)
    ActsAsTenant.current_tenant = organization
    simulate_subdomain(organization&.subdomain)
  end

  # 테넌트 컨텍스트 정리
  def clear_tenant_context
    ActsAsTenant.current_tenant = nil
    simulate_subdomain(nil)
  end

  # 인증된 사용자로 요청 수행
  def authenticated_request(method, path, user: nil, **options)
    user ||= create(:user)
    login_as(user, scope: :user)
    
    case method.to_sym
    when :get
      visit path
    when :post
      page.driver.post path, options[:params] || {}
    when :patch, :put
      page.driver.put path, options[:params] || {}
    when :delete
      page.driver.delete path, options[:params] || {}
    end
  end

  # JavaScript 오류 확인
  def check_javascript_errors
    return unless page.driver.respond_to?(:browser)
    
    logs = page.driver.browser.manage.logs.get(:browser)
    js_errors = logs.select { |log| log.level == 'SEVERE' && log.message.include?('javascript') }
    
    expect(js_errors).to be_empty, 
      "JavaScript 오류 발견: #{js_errors.map(&:message).join(', ')}"
  end

  # 응답 시간 측정
  def measure_response_time
    start_time = Time.current
    yield
    end_time = Time.current
    end_time - start_time
  end

  # 데이터베이스 쿼리 수 측정
  def count_database_queries
    query_count = 0
    
    subscription = ActiveSupport::Notifications.subscribe 'sql.active_record' do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      query_count += 1 unless event.payload[:sql].match?(/PRAGMA|SCHEMA|TRANSACTION/)
    end
    
    yield
    
    ActiveSupport::Notifications.unsubscribe(subscription)
    query_count
  end

  # 메모리 사용량 측정 (대략적)
  def measure_memory_usage
    before = `ps -o rss= -p #{Process.pid}`.to_i
    yield
    after = `ps -o rss= -p #{Process.pid}`.to_i
    after - before
  end

  # 세션 쿠키 확인
  def session_cookie_present?
    cookies = page.driver.browser.manage.all_cookies
    cookies.any? { |cookie| cookie[:name].include?('session') }
  end

  # CSRF 토큰 확인
  def csrf_token_present?
    page.has_css?('meta[name="csrf-token"]', visible: false) ||
      page.has_css?('input[name="authenticity_token"]', visible: false)
  end

  # HTTP 응답 헤더 확인
  def response_headers
    page.response_headers
  end

  # JSON 응답 파싱
  def json_response
    JSON.parse(page.body)
  rescue JSON::ParserError
    nil
  end

  # 특정 서브도메인에서 테스트 실행
  def with_subdomain(subdomain)
    original_subdomain = DomainService.extract_subdomain(double('request'))
    simulate_subdomain(subdomain)
    
    yield
  ensure
    simulate_subdomain(original_subdomain)
  end

  # 특정 조직 컨텍스트에서 테스트 실행
  def with_organization(organization)
    original_tenant = ActsAsTenant.current_tenant
    set_tenant_context(organization)
    
    yield
  ensure
    ActsAsTenant.current_tenant = original_tenant
  end

  # 보안 헤더 확인
  def security_headers_present?
    headers = response_headers
    
    [
      'X-Frame-Options',
      'X-Content-Type-Options',
      'X-XSS-Protection'
    ].all? { |header| headers[header].present? }
  end

  # 캐시 헤더 확인
  def cache_headers_appropriate?
    headers = response_headers
    content_type = headers['Content-Type']
    
    if content_type&.include?('text/html')
      headers['Cache-Control']&.include?('no-cache') ||
        headers['Cache-Control']&.include?('private')
    else
      headers['Cache-Control'].present?
    end
  end

  # 권한 오류 메시지 확인
  def has_authorization_error?
    page.has_content?('권한') ||
      page.has_content?('authorized') ||
      page.has_content?('permission') ||
      page.has_http_status?(:forbidden) ||
      page.has_http_status?(:unauthorized)
  end

  # 인증 오류 메시지 확인
  def has_authentication_error?
    page.has_content?('로그인') ||
      page.has_content?('sign in') ||
      page.has_content?('log in') ||
      page.has_current_path?(new_main_user_session_path) ||
      page.has_current_path?(new_auth_user_session_path)
  end

  # 성공 메시지 확인
  def has_success_message?
    page.has_css?('.alert-success') ||
      page.has_css?('.notice') ||
      page.has_css?('[data-alert="success"]') ||
      page.has_content?('성공') ||
      page.has_content?('완료')
  end

  # 오류 메시지 확인
  def has_error_message?
    page.has_css?('.alert-danger') ||
      page.has_css?('.alert-error') ||
      page.has_css?('[data-alert="error"]') ||
      page.has_content?('오류') ||
      page.has_content?('error') ||
      page.has_content?('실패')
  end
end

RSpec.configure do |config|
  config.include SystemTestHelpers, type: :system
  config.include SystemTestHelpers, type: :feature
  config.include SystemTestHelpers, type: :request
end
