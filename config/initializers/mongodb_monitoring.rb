# frozen_string_literal: true

# MongoDB 모니터링 및 경고 시스템 설정
Rails.application.config.after_initialize do
  if Rails.env.production? || Rails.env.staging?
    # 성능 메트릭 수집 스케줄 설정
    schedule_metrics_collection
    
    # MongoDB 프로파일링 설정
    setup_mongodb_profiling
    
    # 경고 임계값 설정
    configure_alert_thresholds
  end
end

def schedule_metrics_collection
  # Whenever gem이나 Sidekiq-cron을 사용하는 경우
  if defined?(Sidekiq::Cron)
    # 5분마다 시스템 메트릭 수집
    Sidekiq::Cron::Job.create(
      name: 'MongoDB System Metrics',
      cron: '*/5 * * * *',
      class: 'MongodbMetricsCollectorJob',
      args: ['system']
    )
    
    # 15분마다 컬렉션 통계 수집
    Sidekiq::Cron::Job.create(
      name: 'MongoDB Collection Metrics',
      cron: '*/15 * * * *',
      class: 'MongodbMetricsCollectorJob',
      args: ['collections']
    )
    
    # 10분마다 쿼리 분석
    Sidekiq::Cron::Job.create(
      name: 'MongoDB Query Analysis',
      cron: '*/10 * * * *',
      class: 'MongodbMetricsCollectorJob',
      args: ['queries']
    )
    
    # 30분마다 인덱스 분석
    Sidekiq::Cron::Job.create(
      name: 'MongoDB Index Analysis',
      cron: '*/30 * * * *',
      class: 'MongodbMetricsCollectorJob',
      args: ['indexes']
    )
    
    # 매일 자정에 메트릭 정리
    Sidekiq::Cron::Job.create(
      name: 'MongoDB Metrics Cleanup',
      cron: '0 0 * * *',
      class: 'MongodbMetricsCleanupJob'
    )
  end
  
  Rails.logger.info "MongoDB metrics collection scheduled"
rescue => e
  Rails.logger.error "Failed to schedule MongoDB metrics collection: #{e.message}"
end

def setup_mongodb_profiling
  # 프로덕션 환경에서 슬로우 쿼리 프로파일링 활성화
  threshold_ms = ENV['MONGODB_SLOW_QUERY_MS']&.to_i || 100
  
  begin
    client = Mongoid.default_client
    
    # 프로파일링 레벨 설정
    # 0: 비활성화, 1: 슬로우 쿼리만, 2: 모든 쿼리
    client.database.command(
      profile: 1,
      slowms: threshold_ms
    )
    
    Rails.logger.info "MongoDB profiling enabled for queries > #{threshold_ms}ms"
  rescue => e
    Rails.logger.error "Failed to setup MongoDB profiling: #{e.message}"
  end
end

def configure_alert_thresholds
  # 경고 임계값 설정
  Rails.application.config.mongodb_alerts = {
    # 연결 관련
    max_connections: ENV['MONGODB_MAX_CONNECTIONS']&.to_i || 950,
    connection_warning_percent: 80,
    
    # 성능 관련
    slow_query_ms: ENV['MONGODB_SLOW_QUERY_MS']&.to_i || 100,
    slow_query_count_threshold: 10, # 5분 내 10개 이상
    
    # 에러 관련
    error_rate_threshold: 5.0, # 5% 이상
    
    # 메모리 관련
    memory_usage_threshold_mb: ENV['MONGODB_MEMORY_THRESHOLD_MB']&.to_i || 4096,
    
    # 복제 관련
    replication_lag_threshold_ms: 5000,
    
    # 디스크 관련
    disk_usage_threshold_percent: 85
  }
  
  Rails.logger.info "MongoDB alert thresholds configured"
end

# MongoDB 경고 시스템 클래스
class MongodbAlertSystem
  class << self
    def check_all
      alerts = []
      
      alerts += check_connection_alerts
      alerts += check_performance_alerts
      alerts += check_resource_alerts
      alerts += check_replication_alerts
      
      process_alerts(alerts) if alerts.any?
      
      alerts
    end
    
    private
    
    def check_connection_alerts
      alerts = []
      config = Rails.application.config.mongodb_alerts
      
      begin
        client = Mongoid.default_client
        server_status = client.command(serverStatus: 1).first
        connections = server_status['connections']['current']
        
        if connections > config[:max_connections]
          alerts << {
            level: :critical,
            type: :connections,
            message: "MongoDB connections (#{connections}) exceeded maximum (#{config[:max_connections]})"
          }
        elsif connections > config[:max_connections] * config[:connection_warning_percent] / 100
          alerts << {
            level: :warning,
            type: :connections,
            message: "MongoDB connections (#{connections}) approaching maximum"
          }
        end
      rescue => e
        alerts << {
          level: :critical,
          type: :connection_error,
          message: "Failed to check MongoDB connections: #{e.message}"
        }
      end
      
      alerts
    end
    
    def check_performance_alerts
      alerts = []
      config = Rails.application.config.mongodb_alerts
      
      # 최근 5분간 슬로우 쿼리 체크
      slow_queries = MongodbMetric.slow_queries
                                 .where(:created_at.gte => 5.minutes.ago)
                                 .count
      
      if slow_queries > config[:slow_query_count_threshold]
        alerts << {
          level: :warning,
          type: :slow_queries,
          message: "High number of slow queries: #{slow_queries} in last 5 minutes"
        }
      end
      
      # 에러율 체크
      recent_metrics = MongodbMetric.where(:created_at.gte => 5.minutes.ago)
      if recent_metrics.any?
        error_rate = recent_metrics.sum(:error_count).to_f / recent_metrics.count * 100
        
        if error_rate > config[:error_rate_threshold]
          alerts << {
            level: :critical,
            type: :error_rate,
            message: "High error rate: #{error_rate.round(2)}%"
          }
        end
      end
      
      alerts
    end
    
    def check_resource_alerts
      alerts = []
      config = Rails.application.config.mongodb_alerts
      
      begin
        client = Mongoid.default_client
        server_status = client.command(serverStatus: 1).first
        
        # 메모리 사용량 체크
        memory_mb = server_status['mem']['resident']
        if memory_mb > config[:memory_usage_threshold_mb]
          alerts << {
            level: :warning,
            type: :memory,
            message: "High memory usage: #{memory_mb}MB"
          }
        end
        
        # 디스크 사용량 체크
        db_stats = client.database.command(dbStats: 1).first
        if db_stats['fsTotalSize'] > 0
          disk_percent = (db_stats['fsUsedSize'].to_f / db_stats['fsTotalSize'] * 100).round(2)
          
          if disk_percent > config[:disk_usage_threshold_percent]
            alerts << {
              level: :critical,
              type: :disk,
              message: "High disk usage: #{disk_percent}%"
            }
          end
        end
      rescue => e
        Rails.logger.error "Failed to check resource alerts: #{e.message}"
      end
      
      alerts
    end
    
    def check_replication_alerts
      alerts = []
      config = Rails.application.config.mongodb_alerts
      
      begin
        client = Mongoid.default_client
        
        # 복제 상태 체크
        repl_status = client.command(replSetGetStatus: 1).first
        
        if repl_status['members']
          primary = repl_status['members'].find { |m| m['stateStr'] == 'PRIMARY' }
          secondaries = repl_status['members'].select { |m| m['stateStr'] == 'SECONDARY' }
          
          secondaries.each do |secondary|
            if primary && secondary['optimeDate'] && primary['optimeDate']
              lag_ms = (primary['optimeDate'] - secondary['optimeDate']) * 1000
              
              if lag_ms > config[:replication_lag_threshold_ms]
                alerts << {
                  level: :warning,
                  type: :replication_lag,
                  message: "Replication lag on #{secondary['name']}: #{lag_ms.round}ms"
                }
              end
            end
          end
        end
      rescue Mongo::Error::OperationFailure
        # 복제셋이 설정되지 않은 경우 무시
      rescue => e
        Rails.logger.error "Failed to check replication alerts: #{e.message}"
      end
      
      alerts
    end
    
    def process_alerts(alerts)
      # 알림 처리 로직
      alerts.each do |alert|
        case alert[:level]
        when :critical
          # 즉시 알림 발송
          send_immediate_notification(alert)
        when :warning
          # 경고 누적 후 알림
          accumulate_warning(alert)
        else
          # 로그만 기록
          Rails.logger.info "MongoDB Alert: #{alert[:message]}"
        end
      end
    end
    
    def send_immediate_notification(alert)
      Rails.logger.error "CRITICAL MongoDB Alert: #{alert[:message]}"
      
      # Email, Slack, PagerDuty 등으로 알림 발송
      # MongodbAlertMailer.critical_alert(alert).deliver_later
      # SlackNotifier.notify(alert)
    end
    
    def accumulate_warning(alert)
      cache_key = "mongodb_alert:#{alert[:type]}"
      count = Rails.cache.increment(cache_key, 1, expires_in: 10.minutes)
      
      if count >= 3
        send_immediate_notification(alert.merge(level: :warning_escalated))
        Rails.cache.delete(cache_key)
      else
        Rails.logger.warn "MongoDB Warning (#{count}/3): #{alert[:message]}"
      end
    end
  end
end