class Role < ApplicationRecord
  # Multi-tenant support
  acts_as_tenant(:organization)
  
  # Associations
  belongs_to :organization
  has_many :role_permissions, dependent: :destroy
  has_many :permissions, through: :role_permissions
  has_many :organization_memberships, dependent: :nullify
  has_many :users, through: :organization_memberships
  has_many :permission_delegations, dependent: :destroy
  
  # Validations
  validates :name, presence: true
  validates :key, presence: true, 
            uniqueness: { scope: :organization_id },
            format: { with: /\A[a-z0-9_]+\z/, message: "소문자, 숫자, 언더스코어만 사용 가능합니다" }
  validates :priority, numericality: { greater_than_or_equal_to: 0 }
  
  # Scopes
  scope :system, -> { where(system_role: true) }
  scope :custom, -> { where(system_role: false) }
  scope :system_roles, -> { where(system_role: true) }
  scope :custom_roles, -> { where(system_role: false) }
  scope :editable, -> { where(editable: true) }
  scope :by_priority, -> { order(priority: :desc) }
  
  # Callbacks
  before_validation :set_key_from_name, on: :create
  before_destroy :check_destroyable
  
  # Class methods
  def self.default_roles
    {
      owner: { 
        name: '소유자', 
        priority: 100,
        system_role: true,
        editable: false,
        description: '조직의 모든 권한을 가진 최고 관리자'
      },
      admin: { 
        name: '관리자', 
        priority: 80,
        system_role: true,
        editable: false,
        description: '조직 관리 권한을 가진 관리자'
      },
      member: { 
        name: '멤버', 
        priority: 50,
        system_role: true,
        editable: true,
        description: '일반 작업 권한을 가진 멤버'
      },
      viewer: { 
        name: '뷰어', 
        priority: 10,
        system_role: true,
        editable: true,
        description: '읽기 전용 권한을 가진 사용자'
      }
    }
  end
  
  # Instance methods
  def has_permission?(resource, action)
    permissions.exists?(
      'LOWER(resource) = LOWER(?) AND LOWER(action) = LOWER(?)',
      resource, action
    )
  end
  
  def add_permission(permission_or_resource, action = nil, conditions: {}, scope: {})
    permission = if permission_or_resource.is_a?(Permission)
                   permission_or_resource
                 else
                   Permission.find_by(resource: permission_or_resource, action: action)
                 end
    
    return false unless permission
    
    role_permissions.find_or_create_by(permission: permission) do |rp|
      rp.conditions = conditions
      rp.scope = scope
    end
  end
  
  def remove_permission(permission_or_resource, action = nil)
    permission = if permission_or_resource.is_a?(Permission)
                   permission_or_resource
                 else
                   Permission.find_by(resource: permission_or_resource, action: action)
                 end
    
    return false unless permission
    
    role_permissions.where(permission: permission).destroy_all
  end
  
  def grant_all_permissions_for(resource)
    Permission.where(resource: resource).find_each do |permission|
      add_permission(permission)
    end
  end
  
  def revoke_all_permissions_for(resource)
    permissions.where(resource: resource).find_each do |permission|
      remove_permission(permission)
    end
  end
  
  def clone_permissions_from(source_role)
    source_role.role_permissions.find_each do |rp|
      role_permissions.find_or_create_by(
        permission_id: rp.permission_id,
        conditions: rp.conditions,
        scope: rp.scope
      )
    end
  end
  
  def system?
    system_role
  end
  
  def custom?
    !system_role
  end
  
  def destroyable?
    !system_role && organization_memberships.empty?
  end
  
  def editable?
    return false if system_role
    editable
  end
  
  def admin_level?
    priority >= 80
  end
  
  def owner_level?
    priority >= 100
  end
  
  def duplicate(new_name, new_key = nil)
    new_role = organization.roles.build(
      name: new_name,
      key: new_key || "#{new_name.downcase.gsub(/[^a-z0-9]+/, '_')}_#{Time.current.to_i}",
      description: "Duplicated from #{name}",
      system_role: false,
      editable: true,
      priority: priority
    )
    
    if new_role.save
      role_permissions.each do |rp|
        new_role.role_permissions.create!(
          permission: rp.permission,
          conditions: rp.conditions,
          scope: rp.scope
        )
      end
    end
    
    new_role
  end
  
  private
  
  def set_key_from_name
    return if key.present?
    self.key = name.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/^_|_$/, '') if name.present?
  end
  
  def check_destroyable
    if system_role
      errors.add(:base, 'System roles cannot be deleted')
      throw(:abort)
    elsif organization_memberships.any?
      errors.add(:base, 'Cannot delete role with active memberships')
      throw(:abort)
    end
  end
end