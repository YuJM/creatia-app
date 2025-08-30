class MigrateExistingRolesToDynamicRbac < ActiveRecord::Migration[8.0]
  def up
    # 1. 시스템 권한 생성
    create_system_permissions
    
    # 2. 권한 템플릿 생성
    create_permission_templates
    
    # 3. 각 조직에 기본 역할 생성 및 기존 멤버십 마이그레이션
    migrate_organizations_and_memberships
  end
  
  def down
    # 역할 ID 참조 제거
    OrganizationMembership.update_all(role_id: nil)
  end
  
  private
  
  def create_system_permissions
    puts "Creating system permissions..."
    
    Permission::RESOURCES.each do |resource|
      Permission::ACTIONS.each do |action|
        next if action == 'manage' && resource == 'Permission'
        
        category = determine_category(resource)
        name = "#{Permission.resource_name_ko(resource)} #{Permission.action_name_ko(action)}"
        description = "#{Permission.resource_name_ko(resource)}에 대한 #{Permission.action_name_ko(action)} 권한"
        
        Permission.find_or_create_by(
          resource: resource,
          action: action
        ) do |permission|
          permission.name = name
          permission.description = description
          permission.category = category
          permission.system_permission = true
        end
      end
    end
    
    puts "Created #{Permission.count} permissions"
  end
  
  def create_permission_templates
    puts "Creating permission templates..."
    
    # Owner 템플릿 - 모든 권한
    owner_template = PermissionTemplate.find_or_create_by(key: 'owner_template') do |template|
      template.name = '소유자 템플릿'
      template.description = '조직 소유자를 위한 모든 권한'
      template.permissions = Permission.all.pluck(:id)
      template.system_template = true
    end
    
    # Admin 템플릿 - 삭제 제한
    admin_permissions = Permission.where.not(action: 'delete')
                                 .or(Permission.where(resource: %w[Task Sprint PomodoroSession]))
                                 .pluck(:id)
    
    admin_template = PermissionTemplate.find_or_create_by(key: 'admin_template') do |template|
      template.name = '관리자 템플릿'
      template.description = '조직 관리자를 위한 권한'
      template.permissions = admin_permissions
      template.system_template = true
    end
    
    # Member 템플릿 - 작업 중심
    member_permissions = Permission.where(
      resource: %w[Task Sprint Team PomodoroSession Service],
      action: %w[read create update]
    ).pluck(:id)
    
    member_template = PermissionTemplate.find_or_create_by(key: 'member_template') do |template|
      template.name = '멤버 템플릿'
      template.description = '일반 멤버를 위한 작업 권한'
      template.permissions = member_permissions
      template.system_template = true
    end
    
    # Viewer 템플릿 - 읽기 전용
    viewer_permissions = Permission.where(action: 'read').pluck(:id)
    
    viewer_template = PermissionTemplate.find_or_create_by(key: 'viewer_template') do |template|
      template.name = '뷰어 템플릿'
      template.description = '읽기 전용 권한'
      template.permissions = viewer_permissions
      template.system_template = true
    end
    
    puts "Created #{PermissionTemplate.count} permission templates"
  end
  
  def migrate_organizations_and_memberships
    puts "Migrating organizations and memberships..."
    
    Organization.find_each do |organization|
      puts "Processing organization: #{organization.name}"
      
      # 기본 역할 생성
      roles = create_default_roles_for_organization(organization)
      
      # 기존 멤버십 마이그레이션
      organization.organization_memberships.find_each do |membership|
        old_role_key = membership.role # 기존 string role (owner, admin, member, viewer)
        next unless old_role_key.present?
        
        # 새 역할 찾기
        new_role = roles[old_role_key.to_sym]
        
        if new_role
          membership.update_column(:role_id, new_role.id)
          puts "  Migrated #{membership.user.email} from '#{old_role_key}' to role ID #{new_role.id}"
        else
          puts "  Warning: Could not find role '#{old_role_key}' for #{membership.user.email}"
        end
      end
    end
    
    puts "Migration completed!"
  end
  
  def create_default_roles_for_organization(organization)
    roles = {}
    
    # Owner 역할
    roles[:owner] = organization.roles.find_or_create_by(key: 'owner') do |role|
      role.name = '소유자'
      role.description = '조직의 모든 권한을 가진 최고 관리자'
      role.priority = 100
      role.system_role = true
      role.editable = false
    end
    
    # Admin 역할
    roles[:admin] = organization.roles.find_or_create_by(key: 'admin') do |role|
      role.name = '관리자'
      role.description = '조직 관리 권한을 가진 관리자'
      role.priority = 80
      role.system_role = true
      role.editable = false
    end
    
    # Member 역할
    roles[:member] = organization.roles.find_or_create_by(key: 'member') do |role|
      role.name = '멤버'
      role.description = '일반 작업 권한을 가진 멤버'
      role.priority = 50
      role.system_role = true
      role.editable = true
    end
    
    # Viewer 역할
    roles[:viewer] = organization.roles.find_or_create_by(key: 'viewer') do |role|
      role.name = '뷰어'
      role.description = '읽기 전용 권한을 가진 사용자'
      role.priority = 10
      role.system_role = true
      role.editable = true
    end
    
    # 각 역할에 권한 할당
    apply_permissions_to_roles(roles)
    
    roles
  end
  
  def apply_permissions_to_roles(roles)
    # Owner - 모든 권한
    owner_template = PermissionTemplate.find_by(key: 'owner_template')
    owner_template&.apply_to_role(roles[:owner]) if owner_template
    
    # Admin - 관리자 권한
    admin_template = PermissionTemplate.find_by(key: 'admin_template')
    admin_template&.apply_to_role(roles[:admin]) if admin_template
    
    # Member - 작업 권한
    member_template = PermissionTemplate.find_by(key: 'member_template')
    member_template&.apply_to_role(roles[:member]) if member_template
    
    # Viewer - 읽기 권한
    viewer_template = PermissionTemplate.find_by(key: 'viewer_template')
    viewer_template&.apply_to_role(roles[:viewer]) if viewer_template
  end
  
  def determine_category(resource)
    case resource
    when 'Organization', 'OrganizationMembership'
      'organization_management'
    when 'Service'
      'service_management'
    when 'Task', 'PomodoroSession'
      'task_management'
    when 'Sprint'
      'sprint_management'
    when 'Team'
      'team_management'
    when 'User'
      'user_management'
    when 'Role', 'Permission', 'PermissionAuditLog'
      'permission_management'
    else
      'system_administration'
    end
  end
end