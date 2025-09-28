# frozen_string_literal: true

# CleanupMongoDbReferencesJob - User 삭제 시 MongoDB Task의 참조 정리
class CleanupMongoDbReferencesJob < ApplicationJob
  queue_as :low
  
  def perform(user_id)
    Rails.logger.info "[MongoDbCleanup] User #{user_id} 참조 정리 시작"
    
    # Assignee로 할당된 Task들의 참조 제거
    cleanup_assignee_references(user_id)
    
    # Reviewer로 할당된 Task들의 참조 제거
    cleanup_reviewer_references(user_id)
    
    Rails.logger.info "[MongoDbCleanup] User #{user_id} 참조 정리 완료"
  end
  
  private
  
  def cleanup_assignee_references(user_id)
    tasks = Task.where(assignee_id: user_id.to_s)
    
    tasks.each do |task|
      # 스냅샷은 유지하되 assignee_id를 null로 설정
      # 이렇게 하면 삭제된 사용자 정보를 히스토리로 보존 가능
      task.update!(
        assignee_id: nil
      )
      
      # 스냅샷에 삭제 플래그 추가
      if task.assignee_snapshot.present?
        task.assignee_snapshot.update!(
          deleted_at: DateTime.current
        )
      end
    end
    
    Rails.logger.info "[MongoDbCleanup] User #{user_id} - Assignee #{tasks.count}개 참조 제거"
  end
  
  def cleanup_reviewer_references(user_id)
    tasks = Task.where(reviewer_id: user_id.to_s)
    
    tasks.each do |task|
      task.update!(
        reviewer_id: nil
      )
      
      if task.reviewer_snapshot.present?
        task.reviewer_snapshot.update!(
          deleted_at: DateTime.current
        )
      end
    end
    
    Rails.logger.info "[MongoDbCleanup] User #{user_id} - Reviewer #{tasks.count}개 참조 제거"
  end
end