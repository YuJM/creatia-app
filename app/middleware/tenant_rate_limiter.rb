# frozen_string_literal: true

# TenantRateLimiter - 조직별 Rate Limiting 미들웨어
# 
# 이 미들웨어는 다음을 제공합니다:
# - 조직별 API 요청 제한
# - IP별 요청 제한
# - 사용자별 요청 제한
# - Redis 기반 분산 Rate Limiting
class TenantRateLimiter
  class RateLimitExceeded < StandardError
    attr_reader :retry_after, :limit_type
    
    def initialize(message, retry_after: nil, limit_type: nil)
      super(message)
      @retry_after = retry_after
      @limit_type = limit_type
    end
  end
  
  def initialize(app)
    @app = app
    @redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
  rescue Redis::CannotConnectError
    Rails.logger.warn "Redis not available for rate limiting"
    @redis = nil
  end
  
  def call(env)
    request = ActionDispatch::Request.new(env)
    
    # Rate limiting이 필요한 요청인지 확인
    return @app.call(env) unless should_rate_limit?(request)
    
    begin
      # Rate limit 검사
      check_rate_limits!(request)
      
      # 요청 처리
      status, headers, response = @app.call(env)
      
      # 성공한 요청에 대한 카운터 증가
      increment_counters(request) if status < 400
      
      [status, headers, response]
      
    rescue RateLimitExceeded => e
      handle_rate_limit_exceeded(e)
    end
  end
  
  private
  
  # Rate limiting 대상인지 확인
  def should_rate_limit?(request)
    # Redis가 없으면 비활성화
    return false unless @redis
    
    # 개발 환경에서는 선택적 활성화
    return false if Rails.env.development? && ENV['ENABLE_RATE_LIMITING'] != 'true'
    
    # Health check는 제외
    return false if request.path == '/up'
    
    # Static assets는 제외
    return false if request.path.start_with?('/assets/')
    
    # API 요청이거나 민감한 액션만 제한
    api_request?(request) || sensitive_action?(request)
  end
  
  # Rate limit 검사
  def check_rate_limits!(request)
    # IP별 제한 (가장 엄격)
    check_ip_rate_limit!(request)
    
    # 사용자별 제한 (로그인한 경우)
    check_user_rate_limit!(request) if authenticated_user_id(request)
    
    # 조직별 제한 (테넌트 컨텍스트가 있는 경우)
    check_tenant_rate_limit!(request) if tenant_subdomain(request)
  end
  
  # IP별 Rate limit 검사
  def check_ip_rate_limit!(request)
    ip = request.remote_ip
    limits = ip_rate_limits(request)
    
    limits.each do |window, max_requests|
      key = "rate_limit:ip:#{ip}:#{window}"
      current_count = get_counter(key, window)
      
      if current_count >= max_requests
        retry_after = get_retry_after(key, window)
        raise RateLimitExceeded.new(
          "IP rate limit exceeded: #{max_requests} requests per #{window} seconds",
          retry_after: retry_after,
          limit_type: 'ip'
        )
      end
    end
  end
  
  # 사용자별 Rate limit 검사
  def check_user_rate_limit!(request)
    user_id = authenticated_user_id(request)
    limits = user_rate_limits(request)
    
    limits.each do |window, max_requests|
      key = "rate_limit:user:#{user_id}:#{window}"
      current_count = get_counter(key, window)
      
      if current_count >= max_requests
        retry_after = get_retry_after(key, window)
        raise RateLimitExceeded.new(
          "User rate limit exceeded: #{max_requests} requests per #{window} seconds",
          retry_after: retry_after,
          limit_type: 'user'
        )
      end
    end
  end
  
  # 조직별 Rate limit 검사
  def check_tenant_rate_limit!(request)
    subdomain = tenant_subdomain(request)
    limits = tenant_rate_limits(request)
    
    limits.each do |window, max_requests|
      key = "rate_limit:tenant:#{subdomain}:#{window}"
      current_count = get_counter(key, window)
      
      if current_count >= max_requests
        retry_after = get_retry_after(key, window)
        raise RateLimitExceeded.new(
          "Organization rate limit exceeded: #{max_requests} requests per #{window} seconds",
          retry_after: retry_after,
          limit_type: 'tenant'
        )
      end
    end
  end
  
  # 요청 카운터 증가
  def increment_counters(request)
    ip = request.remote_ip
    user_id = authenticated_user_id(request)
    subdomain = tenant_subdomain(request)
    
    # IP 카운터
    ip_rate_limits(request).each do |window, _|
      increment_counter("rate_limit:ip:#{ip}:#{window}", window)
    end
    
    # 사용자 카운터
    if user_id
      user_rate_limits(request).each do |window, _|
        increment_counter("rate_limit:user:#{user_id}:#{window}", window)
      end
    end
    
    # 조직 카운터
    if subdomain
      tenant_rate_limits(request).each do |window, _|
        increment_counter("rate_limit:tenant:#{subdomain}:#{window}", window)
      end
    end
  end
  
  # Rate limit 설정 반환
  def ip_rate_limits(request)
    if api_request?(request)
      { 60 => 60, 3600 => 1000 }  # 분당 60회, 시간당 1000회
    else
      { 60 => 100, 3600 => 2000 } # 분당 100회, 시간당 2000회
    end
  end
  
  def user_rate_limits(request)
    if api_request?(request)
      { 60 => 100, 3600 => 2000 }  # 분당 100회, 시간당 2000회
    else
      { 60 => 200, 3600 => 5000 }  # 분당 200회, 시간당 5000회
    end
  end
  
  def tenant_rate_limits(request)
    # 조직 플랜에 따른 차등 제한 (추후 구현 가능)
    if api_request?(request)
      { 60 => 500, 3600 => 10000 }  # 분당 500회, 시간당 10000회
    else
      { 60 => 1000, 3600 => 20000 } # 분당 1000회, 시간당 20000회
    end
  end
  
  # Redis 카운터 조회
  def get_counter(key, window)
    return 0 unless @redis
    @redis.get(key).to_i
  end
  
  # Redis 카운터 증가
  def increment_counter(key, window)
    return unless @redis
    
    @redis.multi do |multi|
      multi.incr(key)
      multi.expire(key, window)
    end
  end
  
  # 재시도 가능 시간 계산
  def get_retry_after(key, window)
    return window unless @redis
    ttl = @redis.ttl(key)
    ttl > 0 ? ttl : window
  end
  
  # API 요청 여부 확인
  def api_request?(request)
    request.path.start_with?('/api/') ||
    request.headers['Content-Type']&.include?('application/json') ||
    request.headers['Accept']&.include?('application/json')
  end
  
  # 민감한 액션 여부 확인
  def sensitive_action?(request)
    # 로그인, 회원가입, 비밀번호 변경 등
    sensitive_paths = [
      '/users/sign_in', '/users/sign_up', '/users/password',
      '/users/auth/', '/tenant_switcher/switch'
    ]
    
    sensitive_paths.any? { |path| request.path.include?(path) }
  end
  
  # 인증된 사용자 ID 추출
  def authenticated_user_id(request)
    # 세션에서 사용자 ID 추출 (간단한 방법)
    session_data = request.session[:user_id] || request.session['warden.user.user.key']&.first&.first
    session_data
  rescue StandardError
    nil
  end
  
  # 테넌트 서브도메인 추출
  def tenant_subdomain(request)
    subdomain = request.subdomain.presence
    return nil if subdomain.blank?
    return nil if %w[www auth api admin].include?(subdomain)
    subdomain
  end
  
  # Rate limit 초과 처리
  def handle_rate_limit_exceeded(error)
    headers = {
      'Content-Type' => 'application/json',
      'Retry-After' => error.retry_after.to_s,
      'X-RateLimit-Limit-Type' => error.limit_type
    }
    
    body = {
      error: 'Rate limit exceeded',
      message: error.message,
      retry_after: error.retry_after,
      limit_type: error.limit_type
    }.to_json
    
    [429, headers, [body]]
  end
end
