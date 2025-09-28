# lib/tasks/connection_pool_debug.rake
# PostgreSQL 연결 풀 디버깅 Rake 태스크

namespace :db do
  desc "현재 연결 풀 상태 확인"
  task connection_status: :environment do
    pool = ActiveRecord::Base.connection_pool
    
    puts "=== PostgreSQL Connection Pool Status ==="
    puts "Pool size: #{pool.size}"
    puts "Current connections: #{pool.connections.size}"
    puts "Busy connections: #{pool.connections.count(&:in_use?)}"
    puts "Idle connections: #{pool.connections.count { |c| !c.in_use? }}"
    puts "Available slots: #{pool.size - pool.connections.count(&:in_use?)}"
    puts "Checkout timeout: #{pool.checkout_timeout}s"
    puts "Reaping frequency: #{pool.reaper&.frequency || 'N/A'}s"
    puts "=========================================="
    
    if pool.connections.count(&:in_use?) > pool.size * 0.8
      puts "⚠️  WARNING: High connection usage detected!"
    end
  end
  
  desc "연결 풀 연결 해제 및 재초기화"
  task reset_connections: :environment do
    puts "Disconnecting all connections..."
    ActiveRecord::Base.connection_pool.disconnect!
    
    puts "Reconnecting..."
    ActiveRecord::Base.establish_connection
    
    puts "Connection pool reset complete."
    Rake::Task["db:connection_status"].invoke
  end
  
  desc "캐시된 사용자 데이터 통계 확인"
  task cache_stats: :environment do
    puts "=== User Cache Statistics ==="
    
    # Rails.cache가 메모리 저장소인지 확인
    if Rails.cache.respond_to?(:stats)
      stats = Rails.cache.stats
      puts "Cache hits: #{stats[:hits] || 'N/A'}"
      puts "Cache misses: #{stats[:misses] || 'N/A'}"
    else
      puts "Cache statistics not available for current store"
    end
    
    # 캐시 키 샘플링 (Redis나 Memcached인 경우)
    begin
      # 사용자 캐시 키 확인
      sample_users = User.limit(5).pluck(:id)
      cached_count = 0
      
      sample_users.each do |user_id|
        if Rails.cache.exist?("user/#{user_id}")
          cached_count += 1
        end
      end
      
      puts "Sample cached users: #{cached_count}/#{sample_users.count}"
    rescue => e
      puts "Error checking cache: #{e.message}"
    end
    
    puts "=============================="
  end
  
  desc "연결 풀 부하 테스트 (개발 환경 전용)"
  task load_test: :environment do
    unless Rails.env.development?
      puts "This task is only available in development environment"
      exit 1
    end
    
    puts "Starting connection pool load test..."
    puts "Creating #{ActiveRecord::Base.connection_pool.size + 5} concurrent database queries..."
    
    threads = []
    start_time = Time.current
    
    (ActiveRecord::Base.connection_pool.size + 5).times do |i|
      threads << Thread.new do
        begin
          User.cached_find(1)  # 임의 사용자 조회
          puts "Thread #{i}: Success"
        rescue => e
          puts "Thread #{i}: ERROR - #{e.message}"
        end
      end
    end
    
    threads.each(&:join)
    end_time = Time.current
    
    puts "Load test completed in #{(end_time - start_time).round(2)}s"
    Rake::Task["db:connection_status"].invoke
  end
end