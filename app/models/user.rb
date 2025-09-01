class User < ApplicationRecord
  include UserCacheable
  
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :trackable,
         :omniauthable, omniauth_providers: [:google_oauth2, :github]
  
  # Callbacks for MongoDB snapshot synchronization
  after_update :sync_mongodb_snapshots
  after_destroy :cleanup_mongodb_references
         
  # Validations
  validates :username, uniqueness: { case_sensitive: false }, length: { minimum: 3, maximum: 30 }, format: { with: /\A[a-zA-Z0-9_-]+\z/ }, allow_nil: true, allow_blank: true
  validates :role, inclusion: { in: %w[user admin moderator] }
  
  # Multi-tenant associations
  has_many :organization_memberships, dependent: :destroy
  has_many :organizations, through: :organization_memberships
  has_many :team_members, dependent: :destroy
  has_many :teams, through: :team_members
  
  # Role helper methods
  def admin?
    role == 'admin'
  end
  
  def moderator?
    role == 'moderator'
  end
  
  def regular_user?
    role == 'user'
  end
  
  # Organization-specific role methods
  def find_organization(subdomain)
    organizations.find_by(subdomain: subdomain)
  end
  
  def current_organization
    ActsAsTenant.current_tenant
  end
  
  def member_of?(organization)
    organization_memberships.active.exists?(organization: organization)
  end
  
  def role_in(organization)
    organization_memberships.find_by(organization: organization, active: true)&.role
  end
  
  def owner_of?(organization)
    role_in(organization) == 'owner'
  end
  
  def admin_of?(organization)
    role_in(organization).in?(%w[owner admin])
  end
  
  def can_access?(organization)
    member_of?(organization) && organization.active?
  end
  
  def team_ids
    teams.pluck(:id)
  end
  
  def owned_organizations
    organizations.joins(:organization_memberships)
                 .where(organization_memberships: { user: self, role: 'owner', active: true })
  end
  
  def administered_organizations
    organizations.joins(:organization_memberships)
                 .where(organization_memberships: { user: self, role: %w[owner admin], active: true })
  end
         
  def self.from_omniauth(access_token)
    data = access_token.info
    user = User.where(email: data['email']).first

    unless user
      user = User.create(
        name: data['name'],
        email: data['email'],
        password: Devise.friendly_token[0, 20],
        provider: access_token.provider,
        uid: access_token.uid
      )
    end
    user
  end
  
  private
  
  # MongoDB 스냅샷 동기화 (User 정보 변경 시)
  def sync_mongodb_snapshots
    # 중요한 필드가 변경되었는지 확인
    important_fields_changed = saved_change_to_name? || saved_change_to_email? || saved_change_to_role?
    
    # avatar_url, department, position은 필드가 있는 경우에만 체크
    important_fields_changed ||= saved_change_to_avatar_url? if respond_to?(:avatar_url)
    important_fields_changed ||= saved_change_to_department? if respond_to?(:department)
    important_fields_changed ||= saved_change_to_position? if respond_to?(:position)
    
    if important_fields_changed
      # 비동기로 MongoDB 스냅샷 업데이트
      MongodbSnapshotSyncJob.perform_later(self)
      
      Rails.logger.info "[User] ID: #{id} 정보 변경 - MongoDB 동기화 예약"
    end
  end
  
  # MongoDB 참조 정리 (User 삭제 시)
  def cleanup_mongodb_references
    # 비동기로 MongoDB Task의 참조 정리
    CleanupMongoDbReferencesJob.perform_later(id)
    
    Rails.logger.info "[User] ID: #{id} 삭제 - MongoDB 참조 정리 예약"
  end
end
