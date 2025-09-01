# frozen_string_literal: true

# Sprint Model Alias for MongoDB Implementation
# This provides a clean interface while maintaining backward compatibility
# with the MongoDB-based execution data architecture.

class Sprint
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # MongoDB 컬렉션 이름 설정
  store_in collection: "sprints"
  
  # Core References
  field :organization_id, type: String
  field :service_id, type: String
  field :created_by_id, type: String
  
  # User Snapshots (별도 컬렉션 참조)
  field :created_by_snapshot_id, type: String
  
  # Sprint Definition
  field :name, type: String
  field :goal, type: String
  field :status, type: String, default: 'planning'
  field :sprint_number, type: Integer
  
  # Timeline
  field :start_date, type: Date
  field :end_date, type: Date
  
  # Capacity
  field :planned_capacity, type: Float
  field :actual_capacity, type: Float
  
  # Created by 접근자 (스냅샷 우선, PostgreSQL fallback)
  def created_by
    return nil unless created_by_id.present?
    
    # Level 1: Fresh snapshot
    if created_by_snapshot&.fresh?
      return created_by_snapshot.to_user
    end
    
    # Level 2: Stale snapshot (캐시 조회 + 백그라운드 업데이트)
    if created_by_snapshot.present?
      user = fetch_user_with_cache(created_by_id)
      UserSnapshotSyncJob.perform_later(created_by_id) if user
      return user
    end
    
    # Level 3: No snapshot (직접 조회 + 즉시 동기화)
    user = User.find_by(id: created_by_id)
    sync_created_by_snapshot!(user) if user
    user
  end

  # Created by snapshot 접근자
  def created_by_snapshot
    @created_by_snapshot ||= UserSnapshot.where(user_id: created_by_id).first if created_by_id.present?
  end
  
  # Created by 이름 접근자 (기존 코드 호환성)
  def created_by_name
    created_by_snapshot&.name || created_by&.name
  end
  
  # Created by 스냅샷 동기화
  def sync_created_by_snapshot!(user = nil)
    user ||= User.find_by(id: created_by_id)
    return unless user
    
    snapshot = UserSnapshot.where(user_id: user.id.to_s).first
    
    if snapshot.present?
      snapshot.sync_from_user!(user)
      self.created_by_snapshot_id = snapshot.id.to_s
    else
      snapshot = UserSnapshot.from_user(user)
      snapshot.save!
      self.created_by_snapshot_id = snapshot.id.to_s
    end
    
    save! if changed?
    @created_by_snapshot = snapshot
  end

  # Sprint 모델의 편의 메소드들 추가
  def self.from_model(sprint)
    sprint
  end
  
  private
  
  # 캐시를 통한 User 조회
  def fetch_user_with_cache(user_id)
    Rails.cache.fetch("user/#{user_id}", expires_in: 5.minutes) do
      User.find_by(id: user_id)
    end
  end
end