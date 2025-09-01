# frozen_string_literal: true

module Api
  module V1
    # 시스템 헬스체크 엔드포인트
    class HealthController < BaseController
      skip_before_action :authenticate_user!, only: [:status, :ping]

      # GET /api/v1/health/status
      def status
        health_status = check_all_systems
        status_code = health_status[:healthy] ? :ok : :service_unavailable
        
        render json: health_status, status: status_code
      end

      # GET /api/v1/health/ping
      def ping
        render json: { pong: Time.current.to_i }
      end

      # GET /api/v1/health/mongodb
      def mongodb
        mongodb_health = check_mongodb_health
        status_code = mongodb_health[:healthy] ? :ok : :service_unavailable
        
        render json: mongodb_health, status: status_code
      end

      # GET /api/v1/health/postgresql
      def postgresql
        postgresql_health = check_postgresql_health
        status_code = postgresql_health[:healthy] ? :ok : :service_unavailable
        
        render json: postgresql_health, status: status_code
      end


      # GET /api/v1/health/detailed
      def detailed
        return render_unauthorized unless current_user&.admin?
        
        detailed_status = {
          timestamp: Time.current,
          environment: Rails.env,
          version: Rails.application.config.version || '1.0.0',
          services: {
            mongodb: check_mongodb_health_detailed,
            postgresql: check_postgresql_health_detailed,
            sidekiq: check_sidekiq_health
          },
          system: check_system_resources,
          performance: recent_performance_metrics
        }
        
        render json: detailed_status
      end

      private

      def check_all_systems
        checks = {
          mongodb: check_mongodb_health,
          postgresql: check_postgresql_health
        }
        
        healthy = checks.values.all? { |check| check[:healthy] }
        
        {
          healthy: healthy,
          timestamp: Time.current,
          services: checks,
          version: Rails.application.config.version || '1.0.0'
        }
      end

      def check_mongodb_health
        start_time = Time.current
        
        # 기본 연결 체크
        Mongoid.default_client.database.ping
        response_time = ((Time.current - start_time) * 1000).round(2)
        
        # 간단한 읽기 테스트
        MongodbMetric.limit(1).to_a
        
        {
          healthy: true,
          status: 'connected',
          response_time_ms: response_time
        }
      rescue => e
        {
          healthy: false,
          status: 'error',
          error: e.message
        }
      end

      def check_mongodb_health_detailed
        client = Mongoid.default_client
        server_status = client.command(serverStatus: 1).first
        
        {
          healthy: true,
          status: 'connected',
          version: server_status['version'],
          uptime_seconds: server_status['uptime'],
          connections: {
            current: server_status['connections']['current'],
            available: server_status['connections']['available']
          },
          memory: {
            resident_mb: server_status['mem']['resident'],
            virtual_mb: server_status['mem']['virtual']
          },
          operations: {
            insert: server_status['opcounters']['insert'],
            query: server_status['opcounters']['query'],
            update: server_status['opcounters']['update'],
            delete: server_status['opcounters']['delete']
          },
          replication: check_replication_status(client),
          collections: count_collections,
          slow_queries_last_hour: MongodbMetric.slow_queries.this_hour.count
        }
      rescue => e
        {
          healthy: false,
          status: 'error',
          error: e.message
        }
      end

      def check_postgresql_health
        start_time = Time.current
        
        # 연결 체크
        ActiveRecord::Base.connection.execute('SELECT 1')
        response_time = ((Time.current - start_time) * 1000).round(2)
        
        # 연결 풀 상태
        pool = ActiveRecord::Base.connection_pool
        
        {
          healthy: true,
          status: 'connected',
          response_time_ms: response_time,
          connections: {
            size: pool.size,
            connections: pool.connections.size,
            busy: pool.connections.count(&:in_use?),
            idle: pool.connections.count { |c| !c.in_use? }
          }
        }
      rescue => e
        {
          healthy: false,
          status: 'error',
          error: e.message
        }
      end

      def check_postgresql_health_detailed
        conn = ActiveRecord::Base.connection
        
        # 데이터베이스 크기
        db_size = conn.execute(
          "SELECT pg_database_size(current_database()) as size"
        ).first['size']
        
        # 연결 통계
        connection_stats = conn.execute(
          "SELECT count(*) as total,
                  count(*) FILTER (WHERE state = 'active') as active,
                  count(*) FILTER (WHERE state = 'idle') as idle
           FROM pg_stat_activity
           WHERE datname = current_database()"
        ).first
        
        # 테이블 통계
        table_stats = conn.execute(
          "SELECT count(*) as table_count,
                  sum(n_live_tup) as total_rows
           FROM pg_stat_user_tables"
        ).first
        
        {
          healthy: true,
          status: 'connected',
          version: conn.execute("SELECT version()").first['version'],
          database_size_mb: (db_size.to_f / 1024 / 1024).round(2),
          connections: {
            total: connection_stats['total'],
            active: connection_stats['active'],
            idle: connection_stats['idle']
          },
          tables: {
            count: table_stats['table_count'],
            total_rows: table_stats['total_rows']
          },
          cache_hit_ratio: calculate_cache_hit_ratio(conn)
        }
      rescue => e
        {
          healthy: false,
          status: 'error',
          error: e.message
        }
      end


      def check_sidekiq_health
        return { healthy: true, status: 'not_configured' } unless defined?(Sidekiq)
        
        stats = Sidekiq::Stats.new
        
        {
          healthy: true,
          status: 'running',
          processed: stats.processed,
          failed: stats.failed,
          queues: stats.queues,
          enqueued: stats.enqueued,
          scheduled: stats.scheduled_size,
          retries: stats.retry_size,
          dead: stats.dead_size,
          workers: Sidekiq::Workers.new.size
        }
      rescue => e
        {
          healthy: false,
          status: 'error',
          error: e.message
        }
      end

      def check_system_resources
        memory = get_memory_info
        disk = get_disk_info
        
        {
          memory: memory,
          disk: disk,
          load_average: get_load_average,
          cpu_count: get_cpu_count
        }
      end

      def recent_performance_metrics
        return {} unless MongodbMetric.exists?
        
        summary = MongodbMetric.performance_summary(:hour)
        
        {
          total_operations: summary[:total_operations],
          slow_queries: summary[:slow_queries],
          avg_execution_time_ms: summary[:avg_execution_time],
          error_count: summary[:error_count]
        }
      rescue => e
        {
          error: e.message
        }
      end

      def check_replication_status(client)
        repl_status = client.command(replSetGetStatus: 1).first
        
        {
          set: repl_status['set'],
          members: repl_status['members']&.count,
          primary: repl_status['members']&.find { |m| m['stateStr'] == 'PRIMARY' }&.dig('name')
        }
      rescue
        { status: 'not_configured' }
      end

      def count_collections
        Mongoid.default_client.collections.reject { |c| c.name.start_with?('system.') }.count
      end

      def calculate_cache_hit_ratio(conn)
        stats = conn.execute(
          "SELECT sum(heap_blks_read) as heap_read,
                  sum(heap_blks_hit) as heap_hit
           FROM pg_statio_user_tables"
        ).first
        
        return 0 if stats['heap_hit'].to_i == 0
        
        total = stats['heap_read'].to_i + stats['heap_hit'].to_i
        return 0 if total == 0
        
        (stats['heap_hit'].to_f / total * 100).round(2)
      end

      def parse_keyspace_info(info)
        keyspace = {}
        
        info.keys.select { |k| k.start_with?('db') }.each do |db_key|
          db_info = info[db_key]
          if db_info =~ /keys=(\d+),expires=(\d+)/
            keyspace[db_key] = {
              keys: $1.to_i,
              expires: $2.to_i
            }
          end
        end
        
        keyspace
      end

      def get_memory_info
        if File.exist?('/proc/meminfo')
          meminfo = File.read('/proc/meminfo')
          total = meminfo[/MemTotal:\s+(\d+)/, 1].to_i / 1024
          available = meminfo[/MemAvailable:\s+(\d+)/, 1].to_i / 1024
          
          {
            total_mb: total,
            available_mb: available,
            used_mb: total - available,
            percent_used: ((total - available).to_f / total * 100).round(2)
          }
        else
          { status: 'not_available' }
        end
      end

      def get_disk_info
        if command_available?('df')
          output = `df -m /`.split("\n")[1]
          parts = output.split(/\s+/)
          
          {
            total_mb: parts[1].to_i,
            used_mb: parts[2].to_i,
            available_mb: parts[3].to_i,
            percent_used: parts[4].to_i
          }
        else
          { status: 'not_available' }
        end
      end

      def get_load_average
        if File.exist?('/proc/loadavg')
          File.read('/proc/loadavg').split.first(3).map(&:to_f)
        else
          []
        end
      end

      def get_cpu_count
        if File.exist?('/proc/cpuinfo')
          File.read('/proc/cpuinfo').scan(/processor/).count
        else
          1
        end
      end

      def command_available?(cmd)
        system("which #{cmd} > /dev/null 2>&1")
      end
    end
  end
end