class Ability
  include CanCan::Ability

  def initialize(user, organization = nil)
    # Guest user (not logged in)
    return guest_abilities unless user

    # Current organization from ActsAsTenant
    @user = user
    @organization = organization || ActsAsTenant.current_tenant
    
    return unless @organization

    # Load user's membership and role
    membership = @user.organization_memberships.find_by(organization: @organization, active: true)
    return guest_abilities unless membership

    # Load permissions from database
    if membership.role_id?
      # New dynamic role system
      load_dynamic_permissions(membership.role_object)
    else
      # Legacy string-based roles (fallback)
      load_legacy_permissions(membership.role)
    end

    # Load delegated permissions
    load_delegated_permissions

    # Load resource-specific permissions
    load_resource_permissions
  end

  private

  def guest_abilities
    # Guest users can only read public resources
    can :read, Organization, active: true
    # Add more guest permissions as needed
  end

  def load_dynamic_permissions(role)
    return unless role
    
    # If role is a string (legacy), skip dynamic loading
    return if role.is_a?(String)

    # Load all permissions for this role
    role.permissions.includes(:role_permissions).each do |permission|
      role_permission = role.role_permissions.find_by(permission: permission)
      
      # Parse resource class
      resource_class = safe_constantize(permission.resource)
      next unless resource_class

      # Convert action to symbol
      action = permission.action.to_sym

      # Apply conditions if any
      if role_permission&.conditions.present?
        apply_conditional_permission(action, resource_class, role_permission)
      else
        # Simple permission without conditions
        can action, resource_class
      end
    end

    # Apply role-based rules
    apply_role_based_rules(role)
  end

  def load_legacy_permissions(role_string)
    case role_string
    when 'owner'
      can :manage, :all
      # Owner 전용 권한
      can :manage_settings, Organization
      can :manage_members, Organization
      can :manage_billing, Organization
    when 'admin'
      # 관리자는 거의 모든 것을 관리할 수 있지만 일부 제한이 있음
      can :manage, :all
      cannot :destroy, Organization
      cannot :manage, Role, system_role: true
      cannot [:update, :destroy], OrganizationMembership do |membership|
        membership.role == 'owner' || (membership.role_id? && membership.role&.key == 'owner')
      end
      # Admin 전용 권한
      can :manage_members, Organization
      can :change_role, OrganizationMembership
      can :toggle_active, OrganizationMembership
      can :assign, Task
      can :plan, Sprint
      can :metrics, Sprint
      cannot :change_role, OrganizationMembership do |membership|
        membership.role == 'owner'
      end
    when 'member'
      # 기본 읽기 권한
      can :read, Organization
      can :read, Service
      can :read, Task
      can :read, Sprint
      can :read, Team
      can :read, OrganizationMembership, active: true
      can :read, User
      
      # Member는 audit log와 role 관리에 접근할 수 없음
      cannot :read, PermissionAuditLog
      cannot :manage, Role
      cannot :read, Role
      
      # Task 관련 권한
      can :create, Task
      can :update, Task, assignee_id: @user.id
      can :update, Task, created_by_id: @user.id
      can [:complete, :start_pomodoro], Task, assignee_id: @user.id
      
      # PomodoroSession 권한
      can :create, PomodoroSession
      can :manage, PomodoroSession, user_id: @user.id
      
      # 자신의 멤버십 관리 (제한적)
      can :update, OrganizationMembership, user_id: @user.id
      can :destroy, OrganizationMembership do |membership|
        membership.user_id == @user.id && membership.role != 'owner'
      end
      
      # 삭제 권한은 없음
      cannot :destroy, [Organization, Service, Task, Sprint, Team]
    when 'viewer'
      # 읽기 전용 권한
      can :read, Organization
      can :read, Service  
      can :read, Task
      can :read, Sprint
      can :read, Team
      can :read, OrganizationMembership, active: true
      can :read, User
      
      # 생성, 수정, 삭제 권한 없음
      cannot [:create, :update, :destroy], :all
    end
    
    # 공통 권한 (모든 역할)
    if role_string.present?
      # 조직 전환
      can :switch, Organization do |org|
        org.member?(@user)
      end
      
      # 자신의 프로필 관리
      can :update, User, id: @user.id
      can :show, User
    end
  end

  def apply_conditional_permission(action, resource_class, role_permission)
    conditions = role_permission.conditions

    # Handle "own_only" condition
    if conditions['own_only']
      case resource_class.name
      when 'Task', 'Mongodb::MongoTask'
        can action, resource_class, assignee_id: @user.id
        can action, resource_class, created_by_id: @user.id
      when 'PomodoroSession', 'Mongodb::MongoPomodoroSession'
        can action, resource_class, user_id: @user.id
      else
        # Generic owner check
        if resource_class.column_names.include?('user_id')
          can action, resource_class, user_id: @user.id
        end
        if resource_class.column_names.include?('created_by_id')
          can action, resource_class, created_by_id: @user.id
        end
      end
    end

    # Handle "team_only" condition
    if conditions['team_only']
      user_team_ids = @user.team_members.pluck(:team_id)
      if resource_class.column_names.include?('team_id')
        can action, resource_class, team_id: user_team_ids
      end
    end

    # Handle scope restrictions (e.g., specific services)
    if role_permission.scope['service_ids'].present?
      allowed_service_ids = role_permission.scope['service_ids']
      if resource_class.column_names.include?('service_id')
        can action, resource_class, service_id: allowed_service_ids
      end
    end
  end

  def apply_role_based_rules(role)
    # Special rules based on role priority
    if role.priority >= 80 # Admin level or higher
      # Admins can manage memberships
      can :manage, OrganizationMembership, organization_id: @organization.id
      
      # Custom actions for memberships
      can :change_role, OrganizationMembership, organization_id: @organization.id
      can :toggle_active, OrganizationMembership, organization_id: @organization.id
      
      # But cannot modify owner memberships
      cannot :update, OrganizationMembership do |membership|
        membership.role&.key == 'owner'
      end
      cannot :destroy, OrganizationMembership do |membership|
        membership.role&.key == 'owner'
      end
      cannot :change_role, OrganizationMembership do |membership|
        membership.role&.key == 'owner'
      end
      
      # Task management
      can :assign, Mongodb::MongoTask
      can :plan, Mongodb::MongoSprint
      can :metrics, Mongodb::MongoSprint
    end

    if role.priority >= 100 # Owner level
      # Owners have ultimate control
      can :manage, :all
      can :manage_settings, Organization
      can :manage_members, Organization
      can :manage_billing, Organization
    end
  end

  def load_delegated_permissions
    # Load active delegations for this user
    delegations = PermissionDelegation.active
                                     .for_delegatee(@user)
                                     .where(organization: @organization)

    delegations.each do |delegation|
      if delegation.role
        # Delegated role
        load_dynamic_permissions(delegation.role)
      elsif delegation.permissions.present?
        # Specific permissions
        delegation.permissions.each do |permission_id|
          permission = Permission.find_by(id: permission_id)
          next unless permission

          resource_class = safe_constantize(permission.resource)
          next unless resource_class

          can permission.action.to_sym, resource_class
        end
      end
    end
  end

  def load_resource_permissions
    # Load resource-specific permissions (overrides)
    resource_permissions = ResourcePermission.active
                                            .granted
                                            .where(user: @user, organization: @organization)

    resource_permissions.each do |rp|
      resource_class = safe_constantize(rp.resource_type)
      next unless resource_class

      action = rp.permission.action.to_sym
      
      # Apply permission to specific resource instance
      can action, resource_class, id: rp.resource_id
    end
  end

  def safe_constantize(class_name)
    return nil unless class_name.present?
    
    # Whitelist of allowed classes for security
    allowed_classes = %w[
      Organization Service Mongodb::MongoTask Mongodb::MongoSprint Team User 
      OrganizationMembership Role Permission
      Mongodb::MongoPomodoroSession PermissionAuditLog
    ]
    
    return nil unless allowed_classes.include?(class_name)
    
    class_name.constantize
  rescue NameError
    nil
  end
end