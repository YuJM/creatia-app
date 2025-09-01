# frozen_string_literal: true

# SnapshotPreloadable - Controller concern for batch preloading user snapshots
module SnapshotPreloadable
  extend ActiveSupport::Concern
  
  included do
    # 배치 프리로딩을 위한 헬퍼 메서드
    helper_method :preload_snapshots_for if respond_to?(:helper_method)
  end
  
  # Task 컬렉션의 스냅샷을 배치로 프리로드
  def preload_snapshots_for(tasks)
    return tasks if tasks.blank?
    
    # 배열로 변환 (Mongoid::Criteria 처리)
    tasks_array = tasks.to_a
    
    # 스냅샷이 없거나 오래된 Task 필터링
    stale_tasks = filter_stale_tasks(tasks_array)
    
    if stale_tasks.any?
      # 필요한 모든 User ID 수집
      user_ids = collect_user_ids(stale_tasks)
      
      # 한 번의 쿼리로 모든 User 조회
      users = fetch_users(user_ids)
      
      # 배치로 스냅샷 동기화
      sync_snapshots_batch(stale_tasks, users)
      
      log_preload_stats(stale_tasks.size, users.size)
    end
    
    tasks_array
  end
  
  # 스냅샷 프리로딩 통계
  def snapshot_preload_stats
    @snapshot_preload_stats ||= {
      total_preloaded: 0,
      cache_hits: 0,
      db_queries: 0
    }
  end
  
  private
  
  # 오래된 스냅샷을 가진 Task 필터링
  def filter_stale_tasks(tasks, ttl = 1.hour)
    tasks.select do |task|
      # Assignee 스냅샷 체크
      assignee_stale = task.assignee_id.present? && 
                       (!task.assignee_snapshot || task.assignee_snapshot.stale?(ttl))
      
      # Reviewer 스냅샷 체크
      reviewer_stale = task.reviewer_id.present? && 
                       (!task.reviewer_snapshot || task.reviewer_snapshot.stale?(ttl))
      
      assignee_stale || reviewer_stale
    end
  end
  
  # Task들에서 User ID 수집
  def collect_user_ids(tasks)
    user_ids = []
    
    tasks.each do |task|
      user_ids << task.assignee_id.to_i if task.assignee_id.present?
      user_ids << task.reviewer_id.to_i if task.reviewer_id.present?
    end
    
    user_ids.uniq.compact
  end
  
  # User 일괄 조회 (캐시 활용)
  def fetch_users(user_ids)
    return {} if user_ids.empty?
    
    users = {}
    uncached_ids = []
    
    # 캐시에서 먼저 조회
    user_ids.each do |id|
      cached_user = Rails.cache.read("user/#{id}")
      if cached_user
        users[id] = cached_user
        snapshot_preload_stats[:cache_hits] += 1
      else
        uncached_ids << id
      end
    end
    
    # 캐시에 없는 User들만 DB 조회
    if uncached_ids.any?
      db_users = User.where(id: uncached_ids)
      snapshot_preload_stats[:db_queries] += 1
      
      db_users.each do |user|
        users[user.id] = user
        # 캐시에 저장
        Rails.cache.write("user/#{user.id}", user, expires_in: 5.minutes)
      end
    end
    
    users
  end
  
  # 배치로 스냅샷 동기화
  def sync_snapshots_batch(tasks, users)
    tasks.each do |task|
      # Assignee 스냅샷 동기화
      if task.assignee_id.present?
        user = users[task.assignee_id.to_i]
        task.sync_assignee_snapshot!(user) if user
      end
      
      # Reviewer 스냅샷 동기화
      if task.reviewer_id.present?
        user = users[task.reviewer_id.to_i]
        task.sync_reviewer_snapshot!(user) if user
      end
      
      snapshot_preload_stats[:total_preloaded] += 1
    end
  end
  
  # 프리로드 통계 로깅
  def log_preload_stats(tasks_count, users_count)
    Rails.logger.info "[SnapshotPreload] 프리로드 완료 - Tasks: #{tasks_count}, Users: #{users_count}"
    Rails.logger.debug "[SnapshotPreload] 통계: #{snapshot_preload_stats.inspect}"
  end
  
  # 성능 측정 래퍼
  def with_performance_tracking(operation_name)
    start_time = Time.current
    
    result = yield
    
    elapsed_time = Time.current - start_time
    
    if elapsed_time > 0.1 # 100ms 이상 걸린 경우 경고
      Rails.logger.warn "[SnapshotPreload] #{operation_name} took #{(elapsed_time * 1000).round(2)}ms"
    end
    
    result
  end
end