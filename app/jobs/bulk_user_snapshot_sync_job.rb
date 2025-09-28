# frozen_string_literal: true

# BulkUserSnapshotSyncJob - 여러 사용자의 스냅샷을 배치로 동기화
class BulkUserSnapshotSyncJob < ApplicationJob
  queue_as :default
  
  # 재시도 정책
  retry_on ActiveRecord::RecordNotFound, wait: 5.seconds, attempts: 3
  retry_on Mongoid::Errors::DocumentNotFound, wait: 5.seconds, attempts: 3
  
  # 배치 User 스냅샷 동기화
  def perform(user_ids)
    return if user_ids.blank?
    
    Rails.logger.info "[BulkSnapshotSync] #{user_ids.size}개 User 스냅샷 동기화 시작"
    
    # PostgreSQL에서 사용자들 배치 조회
    users = User.where(id: user_ids).index_by { |u| u.id.to_s }
    
    success_count = 0
    error_count = 0
    
    user_ids.each do |user_id|
      user = users[user_id.to_s]
      next unless user
      
      begin
        # UserSnapshot 생성 또는 업데이트
        snapshot = UserSnapshot.where(user_id: user_id.to_s).first
        
        if snapshot.present?
          snapshot.sync_from_user!(user)
        else
          snapshot = UserSnapshot.from_user(user)
          snapshot.save!
        end
        
        success_count += 1
        
      rescue => e
        error_count += 1
        Rails.logger.error "[BulkSnapshotSync] User #{user_id} 동기화 실패: #{e.message}"
      end
    end
    
    Rails.logger.info "[BulkSnapshotSync] 완료 - 성공: #{success_count}, 실패: #{error_count}"
  end
end