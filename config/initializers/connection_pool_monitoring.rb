# config/initializers/connection_pool_monitoring.rb
# PostgreSQL 연결 풀 모니터링 및 디버깅

Rails.application.configure do
  if Rails.env.development?
    # 개발 환경에서 연결 풀 상태를 주기적으로 로깅
    config.after_initialize do
      # 5분마다 연결 풀 상태 로깅
      Thread.new do
        loop do
          sleep 300 # 5분 대기
          
          pool = ActiveRecord::Base.connection_pool
          Rails.logger.info "=== Connection Pool Status ==="
          Rails.logger.info "Pool size: #{pool.size}"
          Rails.logger.info "Connections: #{pool.connections.size}"
          Rails.logger.info "Busy connections: #{pool.connections.count(&:in_use?)}"
          Rails.logger.info "Idle connections: #{pool.connections.count { |c| !c.in_use? }}"
          Rails.logger.info "Available connections: #{pool.size - pool.connections.count(&:in_use?)}"
          Rails.logger.info "=============================="
        end
      end
    end
  end
end

# ActiveRecord에 연결 풀 디버깅 메서드 추가
module ConnectionPoolDebugger
  def debug_connection_info
    pool = ActiveRecord::Base.connection_pool
    
    {
      pool_size: pool.size,
      total_connections: pool.connections.size,
      busy_connections: pool.connections.count(&:in_use?),
      idle_connections: pool.connections.count { |c| !c.in_use? },
      available_connections: pool.size - pool.connections.count(&:in_use?),
      checkout_timeout: pool.checkout_timeout,
      timestamp: Time.current
    }
  end
  
  def log_connection_warning_if_needed
    pool = ActiveRecord::Base.connection_pool
    busy_ratio = pool.connections.count(&:in_use?).to_f / pool.size
    
    if busy_ratio > 0.8  # 80% 이상 사용 중일 때 경고
      Rails.logger.warn "High connection usage detected: #{(busy_ratio * 100).round(1)}% (#{pool.connections.count(&:in_use?)}/#{pool.size})"
    end
  end
end

# ApplicationController에 디버깅 메서드 추가 (Rails 초기화 후)
Rails.application.config.after_initialize do
  if defined?(ApplicationController)
    ApplicationController.include ConnectionPoolDebugger
  end
end

# 연결 풀 고갈 시 상세 정보 로깅
module DetailedConnectionTimeoutLogging
  def checkout(checkout_timeout = @checkout_timeout)
    result = super
    # 연결 가져오기 성공 시 상태 확인
    log_connection_warning_if_needed if respond_to?(:log_connection_warning_if_needed)
    result
  rescue ActiveRecord::ConnectionTimeoutError => e
    # 연결 풀 고갈 시 상세 상태 로깅
    Rails.logger.error "=== Connection Pool Exhausted ==="
    Rails.logger.error "Pool size: #{size}"
    Rails.logger.error "Total connections: #{connections.size}"
    Rails.logger.error "Busy connections: #{connections.count(&:in_use?)}"
    Rails.logger.error "Idle connections: #{connections.count { |c| !c.in_use? }}"
    Rails.logger.error "Checkout timeout: #{checkout_timeout}s"
    Rails.logger.error "Current thread: #{Thread.current.inspect}"
    Rails.logger.error "================================"
    raise e
  end
end

# Rails 7+ 호환성을 위한 조건부 패치
if defined?(ActiveRecord::ConnectionAdapters::ConnectionPool)
  ActiveRecord::ConnectionAdapters::ConnectionPool.prepend DetailedConnectionTimeoutLogging
end