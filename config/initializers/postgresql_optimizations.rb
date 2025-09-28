# config/initializers/postgresql_optimizations.rb

# PostgreSQL 캐싱 최적화 설정
if Rails.env.production? || Rails.env.development?
  
  # 1. Prepared Statements 활성화 (쿼리 플랜 캐싱)
  # database.yml에서 설정하거나 여기서 설정
  ActiveRecord::Base.connection_pool.with_connection do |conn|
    # Prepared statements로 쿼리 플랜 재사용
    conn.execute("SET SESSION plan_cache_mode = 'force_generic_plan'") rescue nil
    
    # 자주 사용하는 쿼리에 대한 통계 수집 강화
    conn.execute("SET SESSION default_statistics_target = 100") rescue nil
  end
  
  # 2. 커넥션 풀 최적화 (캐시 워밍 유지) - 수정됨
  Rails.application.config.after_initialize do
    ActiveRecord::Base.connection_pool.size.times do
      conn = ActiveRecord::Base.connection_pool.checkout
      ActiveRecord::Base.connection_pool.checkin(conn)  # 반드시 반환!
    end
  end
  
  # 3. 자주 사용하는 테이블 메모리에 고정 (선택적)
  if Rails.env.production?
    Rails.application.config.after_initialize do
      ActiveRecord::Base.connection.execute(<<-SQL) rescue nil
        -- User 테이블을 메모리에 프리로드
        SELECT pg_prewarm('users');
        SELECT pg_prewarm('organizations');
        SELECT pg_prewarm('services');
        SELECT pg_prewarm('teams');
      SQL
    end
  end
end

# 4. Active Record 쿼리 캐싱 강화
module PostgresCacheOptimization
  extend ActiveSupport::Concern
  
  included do
    # 자주 사용하는 쿼리 패턴을 Prepared Statement로
    scope :cached_find_by_id, ->(id) {
      # Prepared statement로 쿼리 플랜 캐싱
      where("#{table_name}.id = ?", id).limit(1)
    }
    
    # Association preloading 최적화
    def self.with_cached_associations(*associations)
      # Includes로 N+1 방지 + 쿼리 플랜 캐싱
      includes(*associations).references(*associations)
    end
  end
  
  class_methods do
    # PostgreSQL의 Result Set 캐싱 활용
    def cached_query(sql_key, *args)
      # 동일한 쿼리는 PostgreSQL의 캐시에서 제공
      connection.select_all(
        sanitize_sql_array([sql_key, *args]),
        "#{name} Cached Query",
        preparable: true  # Prepared statement 사용
      )
    end
    
    # 통계 정보 갱신 (캐시 효율성 향상)
    def analyze_table
      connection.execute("ANALYZE #{table_name}")
    end
    
    # 인덱스 캐시 워밍
    def warm_indexes
      connection.execute(<<-SQL)
        SELECT pg_prewarm(indexrelid::regclass::text)
        FROM pg_index
        WHERE indrelid = '#{table_name}'::regclass;
      SQL
    end
  end
end

# User 모델에 적용
ActiveSupport.on_load(:active_record) do
  User.include PostgresCacheOptimization if defined?(User)
  Organization.include PostgresCacheOptimization if defined?(Organization)
  Service.include PostgresCacheOptimization if defined?(Service)
  Team.include PostgresCacheOptimization if defined?(Team)
end