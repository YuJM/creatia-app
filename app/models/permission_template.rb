class PermissionTemplate < ApplicationRecord
  # Validations
  validates :name, presence: true
  validates :key, presence: true, uniqueness: true,
            format: { with: /\A[a-z0-9_]+\z/, message: "소문자, 숫자, 언더스코어만 사용 가능합니다" }
  
  # Scopes
  scope :system_templates, -> { where(system_template: true) }
  scope :custom_templates, -> { where(system_template: false) }
  
  # Class methods
  def self.default_templates
    {
      owner_template: {
        name: '소유자 템플릿',
        key: 'owner_template',
        description: '조직 소유자를 위한 모든 권한',
        permissions: Permission.all.pluck(:id),
        system_template: true
      },
      admin_template: {
        name: '관리자 템플릿',
        key: 'admin_template',
        description: '조직 관리자를 위한 권한',
        permissions: Permission.where.not(resource: %w[Organization Permission Role])
                              .where.not(action: 'delete').pluck(:id),
        system_template: true
      },
      member_template: {
        name: '멤버 템플릿',
        key: 'member_template',
        description: '일반 멤버를 위한 작업 권한',
        permissions: Permission.where(resource: %w[Task Sprint Team PomodoroSession])
                              .where(action: %w[read create update]).pluck(:id),
        system_template: true
      },
      viewer_template: {
        name: '뷰어 템플릿',
        key: 'viewer_template',
        description: '읽기 전용 권한',
        permissions: Permission.where(action: 'read').pluck(:id),
        system_template: true
      }
    }
  end
  
  # Instance methods
  def apply_to_role(role)
    return false unless role
    
    permission_objects.each do |permission|
      role.add_permission(permission)
    end
    
    true
  end
  
  def permission_objects
    Permission.where(id: permissions)
  end
  
  def permission_count
    permissions.size
  end
  
  def includes_permission?(permission)
    permission_id = permission.is_a?(Permission) ? permission.id : permission
    permissions.include?(permission_id.to_s)
  end
  
  def add_permission(permission)
    permission_id = permission.is_a?(Permission) ? permission.id : permission
    self.permissions |= [permission_id.to_s]
    save
  end
  
  def remove_permission(permission)
    permission_id = permission.is_a?(Permission) ? permission.id : permission
    self.permissions -= [permission_id.to_s]
    save
  end
end