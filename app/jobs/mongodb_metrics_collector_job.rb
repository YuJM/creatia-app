# frozen_string_literal: true

# MongoDB 성능 메트릭을 주기적으로 수집하는 Job
class MongodbMetricsCollectorJob < ApplicationJob
  queue_as :low_priority

  # 재시도 설정
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(collection_type = 'all')
    Rails.logger.info "Starting MongoDB metrics collection: #{collection_type}"
    
    case collection_type
    when 'system'
      collect_system_metrics
    when 'collections'
      collect_collection_metrics
    when 'queries'
      collect_query_metrics
    when 'indexes'
      collect_index_metrics
    when 'all'
      collect_all_metrics
    else
      Rails.logger.warn "Unknown collection type: #{collection_type}"
    end
    
    # 임계값 체크 및 경고 발송
    check_and_alert_thresholds
    
    Rails.logger.info "MongoDB metrics collection completed: #{collection_type}"
  end

  private

  def collect_all_metrics
    collect_system_metrics
    collect_collection_metrics
    collect_query_metrics
    collect_index_metrics
  end

  def collect_system_metrics
    MongodbMetric.collect_current_metrics
    
    # 상세 시스템 메트릭 수집
    client = Mongoid.default_client
    db_stats = client.database.command(dbStats: 1).first
    
    MongodbMetric.create!(
      metric_type: 'database',
      operation: 'stats',
      metadata: {
        db_name: db_stats['db'],
        collections: db_stats['collections'],
        views: db_stats['views'],
        objects: db_stats['objects'],
        avg_obj_size: db_stats['avgObjSize'],
        data_size: db_stats['dataSize'],
        storage_size: db_stats['storageSize'],
        indexes: db_stats['indexes'],
        index_size: db_stats['indexSize'],
        fs_used_size: db_stats['fsUsedSize'],
        fs_total_size: db_stats['fsTotalSize']
      }
    )
  rescue => e
    Rails.logger.error "Failed to collect system metrics: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def collect_collection_metrics
    MongodbMetric.collect_collection_stats
    
    # 각 컬렉션의 상세 메트릭 수집
    Mongoid.default_client.collections.each do |collection|
      next if collection.name.start_with?('system.')
      
      # 최근 작업 통계
      begin
        stats = collection.database.command(
          collStats: collection.name,
          indexDetails: true
        ).first
        
        MongodbMetric.create!(
          metric_type: 'collection_detail',
          collection_name: collection.name,
          operation: 'detailed_stats',
          metadata: {
            count: stats['count'],
            size: stats['size'],
            avg_obj_size: stats['avgObjSize'],
            storage_size: stats['storageSize'],
            capped: stats['capped'],
            nindexes: stats['nindexes'],
            total_index_size: stats['totalIndexSize'],
            index_sizes: stats['indexSizes']
          }
        )
      rescue => e
        Rails.logger.error "Failed to collect metrics for #{collection.name}: #{e.message}"
      end
    end
  end

  def collect_query_metrics
    MongodbMetric.analyze_slow_queries(100) # 100ms 이상 쿼리
    
    # 프로파일링 데이터 분석
    profile_collection = Mongoid.default_client.database['system.profile']
    
    if profile_collection.count > 0
      # 최근 1시간 쿼리 패턴 분석
      recent_queries = profile_collection.find(
        ts: { '$gte' => 1.hour.ago }
      ).limit(100)
      
      query_patterns = analyze_query_patterns(recent_queries)
      
      MongodbMetric.create!(
        metric_type: 'query_patterns',
        operation: 'analysis',
        metadata: {
          total_queries: query_patterns[:total],
          by_operation: query_patterns[:by_operation],
          by_collection: query_patterns[:by_collection],
          avg_time_ms: query_patterns[:avg_time],
          slow_count: query_patterns[:slow_count]
        }
      )
    end
  rescue => e
    Rails.logger.error "Failed to collect query metrics: #{e.message}"
  end

  def collect_index_metrics
    MongodbMetric.analyze_index_usage
    
    # 인덱스 효율성 분석
    Mongoid.default_client.collections.each do |collection|
      next if collection.name.start_with?('system.')
      
      begin
        # 인덱스별 통계 수집
        index_stats = collection.aggregate([
          { '$indexStats' => {} }
        ]).to_a
        
        index_stats.each do |stat|
          efficiency = calculate_index_efficiency(stat)
          
          MongodbMetric.create!(
            metric_type: 'index_efficiency',
            collection_name: collection.name,
            operation: 'efficiency',
            index_name: stat['name'],
            metadata: {
              accesses: stat['accesses']['ops'],
              since: stat['accesses']['since'],
              efficiency_score: efficiency,
              host: stat['host']
            }
          )
        end
      rescue => e
        Rails.logger.error "Failed to collect index metrics for #{collection.name}: #{e.message}"
      end
    end
  end

  def analyze_query_patterns(queries)
    patterns = {
      total: 0,
      by_operation: Hash.new(0),
      by_collection: Hash.new(0),
      execution_times: [],
      slow_count: 0
    }
    
    queries.each do |query|
      patterns[:total] += 1
      patterns[:by_operation][query['op']] += 1
      
      if query['ns']
        collection = query['ns'].split('.').last
        patterns[:by_collection][collection] += 1
      end
      
      if query['millis']
        patterns[:execution_times] << query['millis']
        patterns[:slow_count] += 1 if query['millis'] > 100
      end
    end
    
    patterns[:avg_time] = if patterns[:execution_times].any?
                            patterns[:execution_times].sum / patterns[:execution_times].size
                          else
                            0
                          end
    
    patterns
  end

  def calculate_index_efficiency(index_stat)
    # 인덱스 효율성 점수 계산 (0-100)
    accesses = index_stat['accesses']['ops'].to_f
    since = index_stat['accesses']['since']
    
    return 0 if accesses == 0
    
    # 생성 이후 경과 시간 (시간 단위)
    hours_since_creation = (Time.current - since) / 3600.0
    return 100 if hours_since_creation < 1
    
    # 시간당 접근 횟수
    accesses_per_hour = accesses / hours_since_creation
    
    # 효율성 점수 계산 (로그 스케일)
    score = Math.log10(accesses_per_hour + 1) * 20
    [score, 100].min.round(2)
  end

  def check_and_alert_thresholds
    warnings = MongodbMetric.check_thresholds
    
    return if warnings.empty?
    
    # 경고 레벨별 처리
    critical_warnings = warnings.select { |w| w[:level] == 'critical' }
    high_warnings = warnings.select { |w| w[:level] == 'high' }
    medium_warnings = warnings.select { |w| w[:level] == 'medium' }
    
    # Critical 경고는 즉시 알림
    if critical_warnings.any?
      send_critical_alert(critical_warnings)
    end
    
    # High 경고는 5분 내 반복되면 알림
    if high_warnings.any?
      handle_high_warnings(high_warnings)
    end
    
    # Medium 경고는 로그만
    medium_warnings.each do |warning|
      Rails.logger.warn "MongoDB Warning: #{warning[:message]}"
    end
  end

  def send_critical_alert(warnings)
    # Slack, Email 등으로 즉시 알림
    warnings.each do |warning|
      Rails.logger.error "CRITICAL MongoDB Alert: #{warning[:message]}"
      
      # 알림 발송
      MongodbAlertMailer.critical_alert(warning).deliver_later if defined?(MongodbAlertMailer)
      
      # Slack 알림
      send_slack_alert(warning) if Rails.application.config.slack_webhook_url
    end
  end

  def handle_high_warnings(warnings)
    # Redis를 사용한 경고 횟수 추적
    warnings.each do |warning|
      cache_key = "mongodb_warning:#{warning[:type]}"
      count = Rails.cache.increment(cache_key, 1, expires_in: 5.minutes)
      
      if count >= 3
        Rails.logger.error "HIGH MongoDB Alert (repeated #{count} times): #{warning[:message]}"
        send_high_alert(warning)
        Rails.cache.delete(cache_key)
      else
        Rails.logger.warn "MongoDB Warning (#{count}/3): #{warning[:message]}"
      end
    end
  end

  def send_high_alert(warning)
    # 높은 우선순위 경고 발송
    MongodbAlertMailer.high_alert(warning).deliver_later if defined?(MongodbAlertMailer)
  end

  def send_slack_alert(warning)
    require 'net/http'
    require 'json'
    
    webhook_url = Rails.application.config.slack_webhook_url
    
    payload = {
      text: "🚨 MongoDB Alert",
      attachments: [{
        color: warning[:level] == 'critical' ? 'danger' : 'warning',
        title: "#{warning[:level].upcase}: #{warning[:type]}",
        text: warning[:message],
        footer: "MongoDB Monitor",
        ts: Time.current.to_i
      }]
    }
    
    uri = URI(webhook_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    request.content_type = 'application/json'
    request.body = payload.to_json
    
    http.request(request)
  rescue => e
    Rails.logger.error "Failed to send Slack alert: #{e.message}"
  end
end