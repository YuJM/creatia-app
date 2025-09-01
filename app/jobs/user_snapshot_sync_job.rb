# frozen_string_literal: true

# UserSnapshotSyncJob - 개별 User 스냅샷 동기화 (별도 컬렉션)
class UserSnapshotSyncJob < ApplicationJob
  queue_as :default
  
  # 재시도 정책: 네트워크 이슈 등으로 실패할 수 있음
  retry_on ActiveRecord::RecordNotFound, wait: 5.seconds, attempts: 3
  retry_on Mongoid::Errors::DocumentNotFound, wait: 5.seconds, attempts: 3
  
  # 개별 User의 스냅샷 동기화
  def perform(user_id)
    return unless user_id.present?
    
    user = User.find_by(id: user_id)
    return unless user
    
    # UserSnapshot 별도 컬렉션에서 처리
    snapshot = UserSnapshot.where(user_id: user_id.to_s).first
    
    if snapshot.present?
      snapshot.sync_from_user!(user)
    else
      snapshot = UserSnapshot.from_user(user)
      snapshot.save!
    end
    
    Rails.logger.info "[SnapshotSync] User #{user_id} 스냅샷 동기화 완료"
  end
end