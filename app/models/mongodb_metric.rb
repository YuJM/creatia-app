# frozen_string_literal: true

# MongoDB 성능 메트릭 수집 및 저장
class MongodbMetric
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields - 기본 정보
  field :metric_type, type: String # query, write, index, connection, replication
  field :collection_name, type: String
  field :operation, type: String # find, insert, update, delete, aggregate
  field :database_name, type: String, default: -> { Mongoid.default_client.database.name }
  
  # Fields - 성능 메트릭
  field :execution_time_ms, type: Float
  field :documents_examined, type: Integer
  field :documents_returned, type: Integer
  field :index_used, type: Boolean, default: false
  field :index_name, type: String
  
  # Fields - 리소스 사용량
  field :memory_usage_mb, type: Float
  field :cpu_usage_percent, type: Float
  field :disk_io_ops, type: Integer
  field :network_bytes_in, type: Integer
  field :network_bytes_out, type: Integer
  
  # Fields - 연결 정보
  field :connection_count, type: Integer
  field :active_connections, type: Integer
  field :available_connections, type: Integer
  field :connection_pool_size, type: Integer
  
  # Fields - 복제 정보
  field :replication_lag_ms, type: Integer
  field :oplog_size_mb, type: Float
  field :oplog_used_mb, type: Float
  
  # Fields - 에러 정보
  field :error_count, type: Integer, default: 0
  field :error_messages, type: Array, default: []
  field :slow_query, type: Boolean, default: false
  field :slow_query_threshold_ms, type: Integer, default: 100
  
  # Fields - 집계 데이터
  field :hour, type: Integer # 0-23
  field :day_of_week, type: Integer # 0-6
  field :date, type: Date
  field :metadata, type: Hash, default: {}

  # Indexes
  index({ metric_type: 1, created_at: -1 })
  index({ collection_name: 1, operation: 1, created_at: -1 })
  index({ slow_query: 1, created_at: -1 })
  index({ date: 1, hour: 1 })
  index({ created_at: 1 }, { expire_after_seconds: 2592000 }) # 30일 후 자동 삭제

  # Validations
  validates :metric_type, presence: true
  validates :operation, presence: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :slow_queries, -> { where(slow_query: true) }
  scope :by_collection, ->(name) { where(collection_name: name) }
  scope :by_operation, ->(op) { where(operation: op) }
  scope :today, -> { where(:created_at.gte => Time.zone.now.beginning_of_day) }
  scope :this_hour, -> { where(:created_at.gte => 1.hour.ago) }

  # Callbacks
  before_save :set_time_fields
  before_save :check_slow_query

  class << self
    # 현재 MongoDB 상태 수집
    def collect_current_metrics
      client = Mongoid.default_client
      
      # 서버 상태
      server_status = client.command(serverStatus: 1).first
      
      # 연결 정보
      connection_metrics = {
        connection_count: server_status['connections']['current'],
        active_connections: server_status['connections']['active'],
        available_connections: server_status['connections']['available']
      }
      
      # 메모리 정보
      memory_metrics = {
        memory_usage_mb: server_status['mem']['resident'],
        memory_mapped_mb: server_status['mem']['mapped']
      }
      
      # 네트워크 정보
      network_metrics = {
        network_bytes_in: server_status['network']['bytesIn'],
        network_bytes_out: server_status['network']['bytesOut']
      }
      
      create!(
        metric_type: 'system',
        operation: 'status',
        **connection_metrics,
        **memory_metrics,
        **network_metrics,
        metadata: {
          uptime: server_status['uptime'],
          version: server_status['version']
        }
      )
    rescue => e
      Rails.logger.error "Failed to collect MongoDB metrics: #{e.message}"
    end

    # 컬렉션별 통계 수집
    def collect_collection_stats
      Mongoid.default_client.collections.each do |collection|
        next if collection.name.start_with?('system.')
        
        stats = collection.database.command(collStats: collection.name).first
        
        create!(
          metric_type: 'collection',
          collection_name: collection.name,
          operation: 'stats',
          metadata: {
            count: stats['count'],
            size: stats['size'],
            storage_size: stats['storageSize'],
            index_count: stats['nindexes'],
            index_size: stats['totalIndexSize']
          }
        )
      end
    rescue => e
      Rails.logger.error "Failed to collect collection stats: #{e.message}"
    end

    # 슬로우 쿼리 분석
    def analyze_slow_queries(threshold_ms = 100)
      # MongoDB 프로파일링 데이터 조회
      profile_collection = Mongoid.default_client.database['system.profile']
      
      slow_queries = profile_collection.find(
        millis: { '$gte' => threshold_ms },
        ts: { '$gte' => 1.hour.ago }
      )
      
      slow_queries.each do |query|
        create!(
          metric_type: 'query',
          collection_name: query['ns']&.split('.')&.last,
          operation: query['op'],
          execution_time_ms: query['millis'],
          documents_examined: query['docsExamined'],
          documents_returned: query['nreturned'],
          slow_query: true,
          slow_query_threshold_ms: threshold_ms,
          metadata: {
            command: query['command'],
            plan_summary: query['planSummary']
          }
        )
      end
    rescue => e
      Rails.logger.error "Failed to analyze slow queries: #{e.message}"
    end

    # 인덱스 사용률 분석
    def analyze_index_usage
      Mongoid.default_client.collections.each do |collection|
        next if collection.name.start_with?('system.')
        
        # 인덱스 통계
        index_stats = collection.aggregate([
          { '$indexStats' => {} }
        ])
        
        index_stats.each do |stat|
          create!(
            metric_type: 'index',
            collection_name: collection.name,
            operation: 'usage',
            index_name: stat['name'],
            metadata: {
              accesses: stat['accesses']['ops'],
              since: stat['accesses']['since']
            }
          )
        end
      end
    rescue => e
      Rails.logger.error "Failed to analyze index usage: #{e.message}"
    end

    # 성능 요약 생성
    def performance_summary(period = :hour)
      range = case period
              when :hour then 1.hour.ago..Time.current
              when :day then 1.day.ago..Time.current
              when :week then 1.week.ago..Time.current
              else 1.hour.ago..Time.current
              end
      
      metrics = where(:created_at.in => range)
      
      {
        total_operations: metrics.count,
        slow_queries: metrics.slow_queries.count,
        avg_execution_time: metrics.avg(:execution_time_ms),
        max_execution_time: metrics.max(:execution_time_ms),
        total_documents_examined: metrics.sum(:documents_examined),
        total_documents_returned: metrics.sum(:documents_returned),
        error_count: metrics.sum(:error_count),
        by_operation: metrics.group_by(&:operation).transform_values(&:count),
        by_collection: metrics.group_by(&:collection_name).transform_values(&:count)
      }
    end

    # 성능 트렌드 분석
    def performance_trends(days = 7)
      start_date = days.days.ago.to_date
      end_date = Date.current
      
      trends = {}
      
      (start_date..end_date).each do |date|
        daily_metrics = where(date: date)
        
        trends[date] = {
          operations: daily_metrics.count,
          avg_time: daily_metrics.avg(:execution_time_ms),
          slow_queries: daily_metrics.slow_queries.count,
          errors: daily_metrics.sum(:error_count)
        }
      end
      
      trends
    end

    # 경고 임계값 체크
    def check_thresholds
      warnings = []
      
      # 최근 5분 메트릭
      recent = where(:created_at.gte => 5.minutes.ago)
      
      # 슬로우 쿼리 체크
      slow_count = recent.slow_queries.count
      if slow_count > 10
        warnings << {
          level: 'high',
          type: 'slow_queries',
          message: "High number of slow queries: #{slow_count} in last 5 minutes"
        }
      end
      
      # 에러율 체크
      error_rate = recent.sum(:error_count).to_f / recent.count * 100
      if error_rate > 5
        warnings << {
          level: 'critical',
          type: 'error_rate',
          message: "High error rate: #{error_rate.round(2)}%"
        }
      end
      
      # 연결 수 체크
      latest_system = where(metric_type: 'system').recent.first
      if latest_system && latest_system.connection_count > 900
        warnings << {
          level: 'medium',
          type: 'connections',
          message: "High connection count: #{latest_system.connection_count}/1000"
        }
      end
      
      warnings
    end
  end

  private

  def set_time_fields
    self.hour = created_at.hour
    self.day_of_week = created_at.wday
    self.date = created_at.to_date
  end

  def check_slow_query
    if execution_time_ms && execution_time_ms > slow_query_threshold_ms
      self.slow_query = true
    end
  end
end