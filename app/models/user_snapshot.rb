# frozen_string_literal: true

# UserSnapshot은 MongoDB에 별도 컬렉션으로 저장되는 PostgreSQL User 데이터의 스냅샷입니다.
# Task, Sprint 등 여러 곳에서 참조하여 Cross-database 조인을 방지합니다.
class UserSnapshot
  include Mongoid::Document
  include Mongoid::Timestamps::Updated

  # MongoDB 컬렉션 이름 설정
  store_in collection: "user_snapshots"

  # PostgreSQL User 모델의 주요 필드들
  field :user_id, type: String  # PostgreSQL User ID (String으로 저장)
  field :name, type: String
  field :email, type: String
  field :avatar_url, type: String
  field :role, type: String
  field :department, type: String
  field :position, type: String

  # 스냅샷 메타데이터
  field :synced_at, type: DateTime, default: -> { DateTime.current }
  field :version, type: Integer, default: 1
  field :deleted_at, type: DateTime

  # 인덱스 설정
  index({ user_id: 1 }, { unique: true })
  index({ synced_at: 1 })
  index({ email: 1 })

  # 스냅샷 신선도 확인 (기본 1시간)
  def fresh?(ttl = 1.hour)
    return false if synced_at.nil?
    synced_at > ttl.ago
  end

  # 스냅샷이 오래되었는지 확인
  def stale?(ttl = 1.hour)
    !fresh?(ttl)
  end

  # User 객체로 변환 (읽기 전용)
  def to_user
    User.new(
      id: user_id,
      name: name,
      email: email,
      avatar_url: avatar_url,
      role: role
    ).tap { |u| u.readonly! }
  end

  # PostgreSQL User로부터 스냅샷 업데이트
  def sync_from_user!(user)
    return unless user.present?

    self.user_id = user.id
    self.name = user.name
    self.email = user.email
    self.avatar_url = user.respond_to?(:avatar_url) ? user.avatar_url : nil
    self.role = user.role
    self.department = user.respond_to?(:department) ? user.department : nil
    self.position = user.respond_to?(:position) ? user.position : nil
    self.synced_at = DateTime.current
    self.version = (version || 0) + 1

    save!
  end

  # 스냅샷 생성 (클래스 메서드)
  def self.from_user(user)
    return nil unless user.present?

    new(
      user_id: user.id,
      name: user.name,
      email: user.email,
      avatar_url: user.respond_to?(:avatar_url) ? user.avatar_url : nil,
      role: user.role,
      department: user.respond_to?(:department) ? user.department : nil,
      position: user.respond_to?(:position) ? user.position : nil,
      synced_at: DateTime.current,
      version: 1
    )
  end

  # 배치 업데이트를 위한 메서드
  def self.bulk_sync_from_users(users)
    snapshots = users.map { |user| from_user(user) }
    snapshots.compact
  end
end
