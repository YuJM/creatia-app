# frozen_string_literal: true

# Task Model Alias for MongoDB Implementation
# This provides a clean interface while maintaining backward compatibility
# with the MongoDB-based execution data architecture.

class Task
  include Mongoid::Document
  include Mongoid::Timestamps

  # MongoDB 컬렉션 이름 설정
  store_in collection: "tasks"

  # Constants
  STATUSES = %w[todo in_progress review done blocked cancelled].freeze
  PRIORITIES = %w[low medium high urgent].freeze
  TASK_TYPES = %w[feature bug chore spike epic].freeze

  # Mongodb::MongoTask의 모든 필드 정의를 포함
  # (실제로는 MongoTask로부터 데이터를 읽고 쓰지만, 직접 정의하여 _type 문제 회피)

  # Core References (PostgreSQL UUIDs)
  field :organization_id, type: String
  field :service_id, type: String
  field :sprint_id, type: String
  field :milestone_id, type: String
  field :created_by_id, type: String

  # Task Identification
  field :task_id, type: String
  field :external_id, type: String

  # Task Core
  field :title, type: String
  field :description, type: String
  field :task_type, type: String, default: "feature"

  # Assignment
  field :assignee_id, type: String
  field :reviewer_id, type: String
  field :team_id, type: String

  # User Snapshots (별도 컬렉션 참조)
  field :assignee_snapshot_id, type: String
  field :reviewer_snapshot_id, type: String

  # Status & Priority
  field :status, type: String, default: "todo"
  field :priority, type: String, default: "medium"
  field :position, type: Integer, default: 0

  # Time Tracking
  field :estimated_hours, type: Float
  field :actual_hours, type: Float, default: 0.0
  field :remaining_hours, type: Float
  field :time_entries, type: Array, default: []

  # Dates
  field :due_date, type: Date
  field :start_date, type: Date
  field :completed_at, type: DateTime

  # Tags & Labels
  field :tags, type: Array, default: []
  field :labels, type: Array, default: []

  # Task 모델의 편의 메소드들 추가
  def self.from_model(task)
    task
  end

  # Assignee 접근자 (스냅샷 우선, PostgreSQL fallback)
  def assignee
    return nil unless assignee_id.present?

    # Level 1: Fresh snapshot
    if assignee_snapshot&.fresh?
      return assignee_snapshot.to_user
    end

    # Level 2: Stale snapshot (캐시 조회 + 백그라운드 업데이트)
    if assignee_snapshot.present?
      user = fetch_user_with_cache(assignee_id)
      UserSnapshotSyncJob.perform_later(assignee_id) if user
      return user
    end

    # Level 3: No snapshot (직접 조회 + 즉시 동기화)
    user = User.find_by(id: assignee_id)
    sync_assignee_snapshot!(user) if user
    user
  end

  # Assignee snapshot 접근자
  def assignee_snapshot
    @assignee_snapshot ||= UserSnapshot.where(user_id: assignee_id).first if assignee_id.present?
  end

  # Reviewer 접근자 (스냅샷 우선, PostgreSQL fallback)
  def reviewer
    return nil unless reviewer_id.present?

    if reviewer_snapshot&.fresh?
      return reviewer_snapshot.to_user
    end

    if reviewer_snapshot.present?
      user = fetch_user_with_cache(reviewer_id)
      UserSnapshotSyncJob.perform_later(reviewer_id) if user
      return user
    end

    user = User.find_by(id: reviewer_id)
    sync_reviewer_snapshot!(user) if user
    user
  end

  # Reviewer snapshot 접근자
  def reviewer_snapshot
    @reviewer_snapshot ||= UserSnapshot.where(user_id: reviewer_id).first if reviewer_id.present?
  end

  # Assignee 이름 접근자 (기존 코드 호환성)
  def assignee_name
    assignee_snapshot&.name || assignee&.name
  end

  # Assignee 스냅샷 동기화
  def sync_assignee_snapshot!(user = nil)
    user ||= User.find_by(id: assignee_id)
    return unless user

    snapshot = UserSnapshot.where(user_id: user.id.to_s).first

    if snapshot.present?
      snapshot.sync_from_user!(user)
      self.assignee_snapshot_id = snapshot.id.to_s
    else
      snapshot = UserSnapshot.from_user(user)
      snapshot.save!
      self.assignee_snapshot_id = snapshot.id.to_s
    end

    save! if changed?
    @assignee_snapshot = snapshot
  end

  # Reviewer 스냅샷 동기화
  def sync_reviewer_snapshot!(user = nil)
    user ||= User.find_by(id: reviewer_id)
    return unless user

    snapshot = UserSnapshot.where(user_id: user.id.to_s).first

    if snapshot.present?
      snapshot.sync_from_user!(user)
      self.reviewer_snapshot_id = snapshot.id.to_s
    else
      snapshot = UserSnapshot.from_user(user)
      snapshot.save!
      self.reviewer_snapshot_id = snapshot.id.to_s
    end

    save! if changed?
    @reviewer_snapshot = snapshot
  end

  # 모든 스냅샷 동기화
  def sync_all_snapshots!
    sync_assignee_snapshot! if assignee_id.present?
    sync_reviewer_snapshot! if reviewer_id.present?
  end

  # 스냅샷 신선도 확인
  def snapshots_fresh?
    assignee_fresh = assignee_id.blank? || assignee_snapshot&.fresh?
    reviewer_fresh = reviewer_id.blank? || reviewer_snapshot&.fresh?
    assignee_fresh && reviewer_fresh
  end

  private

  # 캐시를 통한 User 조회
  def fetch_user_with_cache(user_id)
    Rails.cache.fetch("user/#{user_id}", expires_in: 5.minutes) do
      User.find_by(id: user_id)
    end
  end

  # 배치 스냅샷 동기화 (클래스 메서드)
  def self.sync_stale_snapshots(tasks)
    stale_tasks = tasks.reject(&:snapshots_fresh?)
    return if stale_tasks.empty?

    # 필요한 모든 User ID 수집
    user_ids = stale_tasks.flat_map { |t| [ t.assignee_id, t.reviewer_id ] }.compact.uniq

    # 한 번의 쿼리로 모든 User 조회
    users = User.where(id: user_ids).index_by(&:id)

    # 각 Task의 스냅샷 업데이트
    stale_tasks.each do |task|
      task.sync_assignee_snapshot!(users[task.assignee_id]) if task.assignee_id && users[task.assignee_id]
      task.sync_reviewer_snapshot!(users[task.reviewer_id]) if task.reviewer_id && users[task.reviewer_id]
    end
  end
end
