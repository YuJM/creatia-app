class OrganizationMembership < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :organization
  
  # Constants
  ROLES = %w[owner admin member viewer].freeze
  
  # Validations
  validates :role, presence: true, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { 
    scope: :organization_id, 
    message: "이미 이 조직의 멤버입니다" 
  }
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_role, ->(role) { where(role: role) }
  scope :owners, -> { where(role: 'owner') }
  scope :admins, -> { where(role: %w[owner admin]) }
  scope :members, -> { where(role: %w[owner admin member]) }
  
  # Callbacks
  before_validation :set_default_role, on: :create
  after_create :ensure_single_owner, if: -> { role == 'owner' }
  
  # Instance methods
  def admin?
    role.in?(%w[owner admin])
  end
  
  def owner?
    role == 'owner'
  end
  
  def can_manage_members?
    admin?
  end
  
  def can_manage_organization?
    owner?
  end
  
  def display_role
    case role
    when 'owner' then '소유자'
    when 'admin' then '관리자'
    when 'member' then '멤버'
    when 'viewer' then '뷰어'
    else role.humanize
    end
  end
  
  private
  
  def set_default_role
    self.role ||= 'member'
  end
  
  def ensure_single_owner
    # 새로운 owner가 생성되면 기존 owner를 admin으로 변경
    organization.organization_memberships
                .where(role: 'owner')
                .where.not(id: id)
                .update_all(role: 'admin')
  end
end
