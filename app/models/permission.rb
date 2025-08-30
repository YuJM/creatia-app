class Permission < ApplicationRecord
  # Constants
  ACTIONS = %w[read create update delete manage].freeze
  
  RESOURCES = %w[
    Organization Service Task Sprint Team 
    User OrganizationMembership Role Permission
    PomodoroSession PermissionAuditLog
  ].freeze
  
  CATEGORIES = {
    organization_management: '조직 관리',
    service_management: '서비스 관리',
    task_management: '작업 관리',
    sprint_management: '스프린트 관리',
    team_management: '팀 관리',
    user_management: '사용자 관리',
    permission_management: '권한 관리',
    system_administration: '시스템 관리'
  }.freeze
  
  # Associations
  has_many :role_permissions, dependent: :destroy
  has_many :roles, through: :role_permissions
  has_many :resource_permissions, dependent: :destroy
  
  # Callbacks
  before_destroy :check_permission_usage
  after_create :normalize_case
  
  # Validations
  validates :resource, presence: true
  validates :action, presence: true
  validates :action, uniqueness: { scope: :resource }
  
  # Scopes
  scope :by_category, ->(category) { where(category: category) }
  scope :by_resource, ->(resource) { where(resource: resource) }
  scope :by_action, ->(action) { where(action: action) }
  scope :for_resource, ->(resource) { where('LOWER(resource) = LOWER(?)', resource) }
  scope :for_action, ->(action) { where('LOWER(action) = LOWER(?)', action) }
  scope :crud, -> { where(action: %w[create read update delete]) }
  scope :system_permissions, -> { where(system_permission: true) }
  
  # Class methods
  def self.create_crud_for(resource)
    permissions = []
    %w[create read update delete].each do |action|
      permission = find_or_create_by(resource: resource, action: action) do |p|
        p.description = "Permission to #{action} #{resource}"
      end
      permissions << permission if permission.persisted?
    end
    permissions
  end
  
  def self.seed_defaults
    RESOURCES.each do |resource|
      create_crud_for(resource)
    end
    
    # Add special management permissions
    find_or_create_by(resource: 'Organization', action: 'manage')
    find_or_create_by(resource: 'Service', action: 'manage')
    find_or_create_by(resource: 'Task', action: 'manage')
  end
  
  def self.seed_permissions
    permissions_data = []
    
    RESOURCES.each do |resource|
      ACTIONS.each do |action|
        next if action == 'manage' && resource == 'Permission' # 권한은 manage 제외
        
        category = case resource
                   when 'Organization', 'OrganizationMembership'
                     :organization_management
                   when 'Service'
                     :service_management
                   when 'Task', 'PomodoroSession'
                     :task_management
                   when 'Sprint'
                     :sprint_management
                   when 'Team'
                     :team_management
                   when 'User'
                     :user_management
                   when 'Role', 'Permission', 'PermissionAuditLog'
                     :permission_management
                   else
                     :system_administration
                   end
        
        name = "#{resource_name_ko(resource)} #{action_name_ko(action)}"
        description = "#{resource_name_ko(resource)}에 대한 #{action_name_ko(action)} 권한"
        
        permissions_data << {
          resource: resource,
          action: action,
          name: name,
          description: description,
          category: category,
          system_permission: true
        }
      end
    end
    
    permissions_data.each do |data|
      Permission.find_or_create_by(
        resource: data[:resource],
        action: data[:action]
      ) do |permission|
        permission.assign_attributes(data)
      end
    end
  end
  
  def self.resource_name_ko(resource)
    {
      'Organization' => '조직',
      'Service' => '서비스',
      'Task' => '작업',
      'Sprint' => '스프린트',
      'Team' => '팀',
      'User' => '사용자',
      'OrganizationMembership' => '조직 멤버십',
      'Role' => '역할',
      'Permission' => '권한',
      'PomodoroSession' => '뽀모도로 세션',
      'PermissionAuditLog' => '권한 감사 로그'
    }[resource] || resource
  end
  
  def self.action_name_ko(action)
    {
      'read' => '조회',
      'create' => '생성',
      'update' => '수정',
      'delete' => '삭제',
      'manage' => '관리'
    }[action] || action
  end
  
  # Instance methods
  def display_name
    "#{resource.capitalize} - #{action.capitalize}"
  end
  
  def full_key
    "#{resource}:#{action}"
  end
  
  def full_name
    "#{resource}:#{action}"
  end
  
  def crud?
    %w[create read update delete].include?(action)
  end
  
  def management?
    %w[manage administer control].include?(action)
  end
  
  def custom?
    !crud? && !management?
  end
  
  def category_name
    CATEGORIES[category&.to_sym] || category
  end
  
  def applies_to?(user, organization, target = nil)
    # 직접 권한 확인
    if target && resource_permission_for(user, organization, target)
      return true
    end
    
    # 역할 기반 권한 확인
    membership = user.organization_memberships.find_by(organization: organization)
    return false unless membership&.role
    
    membership.role.has_permission?(resource, action)
  end
  
  private
  
  def resource_permission_for(user, organization, target)
    resource_permissions
      .where(user: user, organization: organization)
      .where(resource_type: target.class.name, resource_id: target.id)
      .where('expires_at IS NULL OR expires_at > ?', Time.current)
      .where(granted: true)
      .exists?
  end
  
  def check_permission_usage
    if role_permissions.any?
      errors.add(:base, 'Cannot delete permission that is in use')
      throw(:abort)
    end
  end
  
  def normalize_case
    # Normalize resource to PascalCase and action to lowercase
    if resource.present? && resource != resource.camelize
      update_column(:resource, resource.camelize)
    end
    if action.present? && action != action.downcase
      update_column(:action, action.downcase)
    end
  end
end