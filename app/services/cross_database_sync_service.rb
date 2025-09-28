# frozen_string_literal: true

# CrossDatabaseSyncService - PostgreSQL과 MongoDB 간 데이터 동기화 서비스
class CrossDatabaseSyncService
  include Singleton
  
  # 동기화 통계
  attr_accessor :stats
  
  def initialize
    @stats = {
      total_synced: 0,
      failed_syncs: 0,
      last_sync_at: nil
    }
  end
  
  # 조직 전체 스냅샷 동기화
  def sync_organization_snapshots(organization)
    Rails.logger.info "[CrossDBSync] 조직 #{organization.subdomain} 동기화 시작"
    
    start_time = Time.current
    synced_count = 0
    
    # 조직의 모든 User 조회
    users = organization.members.includes(:user).map(&:user)
    user_map = users.index_by(&:id)
    
    # 조직의 모든 Task 조회 및 동기화 (Mongoid)
    Task.where(organization_id: organization.id.to_s).each_slice(100) do |tasks|
      sync_batch_snapshots(tasks, user_map)
      synced_count += tasks.size
    end
    
    elapsed_time = Time.current - start_time
    
    Rails.logger.info "[CrossDBSync] 조직 #{organization.subdomain} 동기화 완료 - #{synced_count}개 Task, #{elapsed_time.round(2)}초"
    
    update_stats(synced_count)
    synced_count
  end
  
  # 배치 스냅샷 동기화
  def sync_batch_snapshots(tasks, user_map = nil)
    # user_map이 없으면 필요한 User들만 조회
    if user_map.nil?
      user_ids = tasks.flat_map { |t| [t.assignee_id, t.reviewer_id] }.compact.uniq
      users = User.where(id: user_ids)
      user_map = users.index_by(&:id)
    end
    
    # 각 Task의 스냅샷 업데이트
    tasks.each do |task|
      sync_task_snapshots(task, user_map)
    end
  end
  
  # 개별 Task 스냅샷 동기화
  def sync_task_snapshots(task, user_map)
    # Assignee 스냅샷 동기화
    if task.assignee_id.present?
      user = user_map[task.assignee_id.to_i]
      task.sync_assignee_snapshot!(user) if user
    end
    
    # Reviewer 스냅샷 동기화
    if task.reviewer_id.present?
      user = user_map[task.reviewer_id.to_i]
      task.sync_reviewer_snapshot!(user) if user
    end
  rescue => e
    Rails.logger.error "[CrossDBSync] Task #{task.id} 동기화 실패: #{e.message}"
    @stats[:failed_syncs] += 1
  end
  
  # 오래된 스냅샷 정리
  def cleanup_stale_snapshots(ttl = 7.days)
    Rails.logger.info "[CrossDBSync] #{ttl} 이상 오래된 스냅샷 정리 시작"
    
    cutoff_date = ttl.ago
    cleaned_count = 0
    
    # 오래되고 사용되지 않는 스냅샷 제거
    Task.where('assignee_snapshot.synced_at' => { '$lt' => cutoff_date }).each do |task|
      if task.assignee_id.blank?
        task.unset(:assignee_snapshot)
        cleaned_count += 1
      end
    end
    
    Task.where('reviewer_snapshot.synced_at' => { '$lt' => cutoff_date }).each do |task|
      if task.reviewer_id.blank?
        task.unset(:reviewer_snapshot)
        cleaned_count += 1
      end
    end
    
    Rails.logger.info "[CrossDBSync] #{cleaned_count}개 스냅샷 정리 완료"
    cleaned_count
  end
  
  # 동기화 상태 확인
  def health_check
    {
      healthy: true,
      stats: @stats,
      stale_snapshots_count: count_stale_snapshots,
      missing_snapshots_count: count_missing_snapshots
    }
  end
  
  private
  
  def update_stats(synced_count)
    @stats[:total_synced] += synced_count
    @stats[:last_sync_at] = Time.current
  end
  
  def count_stale_snapshots(ttl = 1.hour)
    cutoff_date = ttl.ago
    
    Task.or(
      { 'assignee_snapshot.synced_at' => { '$lt' => cutoff_date } },
      { 'reviewer_snapshot.synced_at' => { '$lt' => cutoff_date } }
    ).count
  end
  
  def count_missing_snapshots
    Task.or(
      { assignee_id: { '$ne' => nil }, assignee_snapshot: nil },
      { reviewer_id: { '$ne' => nil }, reviewer_snapshot: nil }
    ).count
  end
end