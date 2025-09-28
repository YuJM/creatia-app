# frozen_string_literal: true

module Admin
  # MongoDB 모니터링 대시보드 컨트롤러
  class MongodbMonitoringController < ApplicationController
    before_action :authenticate_admin!
    
    # GET /admin/mongodb_monitoring
    def index
      @current_metrics = gather_current_metrics
      @performance_summary = MongodbMetric.performance_summary(:hour)
      @warnings = MongodbMetric.check_thresholds
      @recent_slow_queries = MongodbMetric.slow_queries.recent.limit(10)
    end

    # GET /admin/mongodb_monitoring/metrics
    def metrics
      period = params[:period] || 'hour'
      @summary = MongodbMetric.performance_summary(period.to_sym)
      
      render json: {
        summary: @summary,
        timestamp: Time.current
      }
    end

    # GET /admin/mongodb_monitoring/trends
    def trends
      days = params[:days]&.to_i || 7
      @trends = MongodbMetric.performance_trends(days)
      
      respond_to do |format|
        format.json { render json: @trends }
        format.html
      end
    end

    # GET /admin/mongodb_monitoring/slow_queries
    def slow_queries
      @slow_queries = MongodbMetric.slow_queries
                                  .recent
                                  .page(params[:page])
                                  .per(20)
      
      respond_to do |format|
        format.html
        format.json { render json: format_slow_queries(@slow_queries) }
      end
    end

    # GET /admin/mongodb_monitoring/collections
    def collections
      @collections = gather_collection_stats
      
      respond_to do |format|
        format.html
        format.json { render json: @collections }
      end
    end

    # GET /admin/mongodb_monitoring/connections
    def connections
      @connection_stats = gather_connection_stats
      
      render json: @connection_stats
    end

    # POST /admin/mongodb_monitoring/refresh
    def refresh
      # 최신 메트릭 수집
      MongodbMetric.collect_current_metrics
      MongodbMetric.collect_collection_stats
      MongodbMetric.analyze_slow_queries
      MongodbMetric.analyze_index_usage
      
      redirect_to admin_mongodb_monitoring_path, 
                  notice: 'Metrics refreshed successfully'
    end

    # GET /admin/mongodb_monitoring/export
    def export
      period = params[:period] || 'day'
      format_type = params[:format] || 'csv'
      
      data = export_metrics(period, format_type)
      
      respond_to do |format|
        format.csv { send_data data, filename: "mongodb_metrics_#{Date.current}.csv" }
        format.json { render json: data }
      end
    end

    private

    def authenticate_admin!
      # Admin 인증 로직
      redirect_to root_path unless current_user&.admin?
    end

    def gather_current_metrics
      client = Mongoid.default_client
      server_status = client.command(serverStatus: 1).first
      
      {
        version: server_status['version'],
        uptime: format_uptime(server_status['uptime']),
        connections: {
          current: server_status['connections']['current'],
          available: server_status['connections']['available'],
          total_created: server_status['connections']['totalCreated']
        },
        memory: {
          resident_mb: server_status['mem']['resident'],
          virtual_mb: server_status['mem']['virtual'],
          mapped_mb: server_status['mem']['mapped']
        },
        network: {
          bytes_in: format_bytes(server_status['network']['bytesIn']),
          bytes_out: format_bytes(server_status['network']['bytesOut']),
          requests: server_status['network']['numRequests']
        },
        operations: gather_operation_stats(server_status)
      }
    rescue => e
      Rails.logger.error "Failed to gather metrics: #{e.message}"
      {}
    end

    def gather_operation_stats(server_status)
      opcounters = server_status['opcounters'] || {}
      
      {
        insert: opcounters['insert'],
        query: opcounters['query'],
        update: opcounters['update'],
        delete: opcounters['delete'],
        command: opcounters['command']
      }
    end

    def gather_collection_stats
      collections = []
      
      Mongoid.default_client.collections.each do |collection|
        next if collection.name.start_with?('system.')
        
        stats = collection.database.command(collStats: collection.name).first
        
        collections << {
          name: collection.name,
          count: stats['count'],
          size: format_bytes(stats['size']),
          avg_obj_size: format_bytes(stats['avgObjSize']),
          storage_size: format_bytes(stats['storageSize']),
          indexes: stats['nindexes'],
          index_size: format_bytes(stats['totalIndexSize'])
        }
      end
      
      collections.sort_by { |c| -c[:count] }
    rescue => e
      Rails.logger.error "Failed to gather collection stats: #{e.message}"
      []
    end

    def gather_connection_stats
      client = Mongoid.default_client
      
      # 연결 풀 상태
      pool_stats = client.cluster.pool.inspect
      
      # 활성 연결 정보
      active_connections = client.database.command(
        currentOp: 1,
        '$all': true
      ).first['inprog']
      
      {
        pool: {
          size: client.cluster.pool.size,
          available: client.cluster.pool.available_count,
          pending: client.cluster.pool.queue.length
        },
        active_operations: active_connections.map do |op|
          {
            operation: op['op'],
            namespace: op['ns'],
            duration_ms: op['microsecs_running'] / 1000.0,
            client: op['client']
          }
        end.take(20)
      }
    rescue => e
      Rails.logger.error "Failed to gather connection stats: #{e.message}"
      {}
    end

    def format_slow_queries(queries)
      queries.map do |query|
        {
          id: query.id.to_s,
          collection: query.collection_name,
          operation: query.operation,
          execution_time_ms: query.execution_time_ms,
          documents_examined: query.documents_examined,
          documents_returned: query.documents_returned,
          index_used: query.index_used,
          created_at: query.created_at,
          metadata: query.metadata
        }
      end
    end

    def export_metrics(period, format_type)
      range = case period
              when 'hour' then 1.hour.ago..Time.current
              when 'day' then 1.day.ago..Time.current
              when 'week' then 1.week.ago..Time.current
              else 1.day.ago..Time.current
              end
      
      metrics = MongodbMetric.where(:created_at.in => range)
      
      case format_type
      when 'csv'
        generate_csv(metrics)
      when 'json'
        metrics.to_json
      end
    end

    def generate_csv(metrics)
      require 'csv'
      
      CSV.generate do |csv|
        csv << [
          'Timestamp', 'Type', 'Collection', 'Operation',
          'Execution Time (ms)', 'Documents Examined', 
          'Documents Returned', 'Slow Query', 'Error Count'
        ]
        
        metrics.each do |metric|
          csv << [
            metric.created_at,
            metric.metric_type,
            metric.collection_name,
            metric.operation,
            metric.execution_time_ms,
            metric.documents_examined,
            metric.documents_returned,
            metric.slow_query,
            metric.error_count
          ]
        end
      end
    end

    def format_uptime(seconds)
      days = seconds / 86400
      hours = (seconds % 86400) / 3600
      minutes = (seconds % 3600) / 60
      
      "#{days}d #{hours}h #{minutes}m"
    end

    def format_bytes(bytes)
      return '0 B' if bytes.nil? || bytes == 0
      
      units = ['B', 'KB', 'MB', 'GB', 'TB']
      index = (Math.log(bytes) / Math.log(1024)).floor
      size = (bytes / (1024.0 ** index)).round(2)
      
      "#{size} #{units[index]}"
    end
  end
end