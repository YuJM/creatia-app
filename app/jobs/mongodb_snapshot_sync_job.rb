# frozen_string_literal: true

# MongodbSnapshotSyncJob - User 변경 시 관련된 모든 MongoDB 스냅샷 동기화
class MongodbSnapshotSyncJob < ApplicationJob
  queue_as :low
  
  # 대량 업데이트를 위한 배치 사이즈
  BATCH_SIZE = 100
  
  def perform(user)
    return unless user.present?
    
    Rails.logger.info "[MongoDbSync] User #{user.id} 변경 감지 - 스냅샷 동기화 시작"
    
    # Assignee로 할당된 모든 Task 업데이트
    sync_assignee_tasks(user)
    
    # Reviewer로 할당된 모든 Task 업데이트
    sync_reviewer_tasks(user)
    
    # 캐시 무효화
    invalidate_user_cache(user)
    
    Rails.logger.info "[MongoDbSync] User #{user.id} 스냅샷 동기화 완료"
  end
  
  private
  
  def sync_assignee_tasks(user)
    total_updated = 0
    
    Task.where(assignee_id: user.id.to_s).each_slice(BATCH_SIZE) do |tasks|
      tasks.each do |task|
        task.sync_assignee_snapshot!(user)
        total_updated += 1
      end
    end
    
    Rails.logger.info "[MongoDbSync] User #{user.id} - Assignee Task #{total_updated}개 업데이트"
  end
  
  def sync_reviewer_tasks(user)
    total_updated = 0
    
    Task.where(reviewer_id: user.id.to_s).each_slice(BATCH_SIZE) do |tasks|
      tasks.each do |task|
        task.sync_reviewer_snapshot!(user)
        total_updated += 1
      end
    end
    
    Rails.logger.info "[MongoDbSync] User #{user.id} - Reviewer Task #{total_updated}개 업데이트"
  end
  
  def invalidate_user_cache(user)
    Rails.cache.delete("user/#{user.id}")
    Rails.cache.delete("user_with_organization/#{user.id}")
  end
end