class PermissionService
  attr_reader :user, :organization

  def initialize(user, organization = nil)
    @user = user
    @organization = organization || ActsAsTenant.current_tenant
    @ability = Ability.new(user, @organization)
  end

  # 간단한 권한 체크 헬퍼 메서드들

  def can_view_task?(task)
    return false unless task && @organization
    
    # 태스크가 현재 조직에 속하는지 확인
    return false unless task.organization_id == @organization.id
    
    # CanCanCan ability 체크
    @ability.can?(:read, task)
  end

  def can_edit_task?(task)
    return false unless task && @organization
    return false unless task.organization_id == @organization.id
    
    @ability.can?(:update, task)
  end

  def can_delete_task?(task)
    return false unless task && @organization
    return false unless task.organization_id == @organization.id
    
    @ability.can?(:destroy, task)
  end

  def can_manage_organization?
    return false unless @organization
    
    @ability.can?(:manage, @organization)
  end

  def can_manage_members?
    return false unless @organization
    
    @ability.can?(:manage, OrganizationMembership)
  end

  def can_manage_roles?
    return false unless @organization
    
    @ability.can?(:manage, Role)
  end

  def can_view_service?(service)
    return false unless service && @organization
    return false unless service.organization_id == @organization.id
    
    @ability.can?(:read, service)
  end

  def can_edit_service?(service)
    return false unless service && @organization
    return false unless service.organization_id == @organization.id
    
    @ability.can?(:update, service)
  end

  # 역할 기반 체크 메서드들

  def owner?
    membership = current_membership
    return false unless membership
    
    if membership.role_id?
      membership.role_object&.key == 'owner'
    else
      membership.role == 'owner'
    end
  end

  def admin?
    membership = current_membership
    return false unless membership
    
    if membership.role_id?
      role = membership.role_object
      role && (role.key == 'owner' || role.key == 'admin')
    else
      %w[owner admin].include?(membership.role)
    end
  end

  def member?
    membership = current_membership
    return false unless membership
    
    if membership.role_id?
      role = membership.role_object
      role && %w[owner admin member].include?(role.key)
    else
      %w[owner admin member].include?(membership.role)
    end
  end

  def viewer?
    membership = current_membership
    return false unless membership
    
    if membership.role_id?
      membership.role_object&.key == 'viewer'
    else
      membership.role == 'viewer'
    end
  end

  # 권한 캐싱 메서드

  def cached_permissions
    @cached_permissions ||= Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      load_permissions
    end
  end

  def clear_cache!
    Rails.cache.delete(cache_key)
    @cached_permissions = nil
  end

  # 권한 목록 조회

  def available_permissions
    return [] unless @organization
    
    membership = current_membership
    return [] unless membership
    
    if membership.role_id?
      membership.role_object.permissions
    else
      # Legacy 역할의 경우 하드코딩된 권한 반환
      Permission.where(action: legacy_role_actions(membership.role))
    end
  end

  def has_permission?(resource, action)
    @ability.can?(action.to_sym, resource)
  end

  # 권한 위임 체크

  def has_delegated_permission?(resource, action)
    delegations = PermissionDelegation.active
                                     .for_delegatee(@user)
                                     .where(organization: @organization)
    
    delegations.any? do |delegation|
      delegation.has_permission?(resource.class.name, action)
    end
  end

  # 감사 로그 기록

  def log_permission_check(action, resource, permitted)
    return unless @user && @organization
    
    PermissionAuditLog.create!(
      user: @user,
      organization: @organization,
      action: action.to_s,
      resource: resource,
      permitted: permitted,
      context: {
        checked_at: Time.current,
        ability_cache_key: cache_key
      }
    )
  rescue => e
    Rails.logger.error "Failed to log permission check: #{e.message}"
  end

  private

  def current_membership
    return nil unless @user && @organization
    @current_membership ||= @user.organization_memberships
                                 .find_by(organization: @organization, active: true)
  end

  def cache_key
    return nil unless @user && @organization
    
    membership = current_membership
    return nil unless membership
    
    role_id = membership.role_id || membership.role
    "permissions:#{@organization.id}:#{@user.id}:#{role_id}"
  end

  def load_permissions
    membership = current_membership
    return {} unless membership
    
    if membership.role_id?
      # Dynamic permissions
      permissions = {}
      membership.role_object.permissions.each do |permission|
        key = "#{permission.resource}:#{permission.action}"
        permissions[key] = true
      end
      permissions
    else
      # Legacy permissions
      legacy_permissions(membership.role)
    end
  end

  def legacy_permissions(role_string)
    case role_string
    when 'owner'
      { 'all:manage' => true }
    when 'admin'
      {
        'Organization:read' => true,
        'Organization:update' => true,
        'Service:manage' => true,
        'Task:manage' => true,
        'Sprint:manage' => true,
        'Team:manage' => true,
        'OrganizationMembership:manage' => true
      }
    when 'member'
      {
        'Organization:read' => true,
        'Service:read' => true,
        'Task:read' => true,
        'Task:create' => true,
        'Task:update' => true,
        'Sprint:read' => true,
        'Team:read' => true
      }
    when 'viewer'
      {
        'Organization:read' => true,
        'Service:read' => true,
        'Task:read' => true,
        'Sprint:read' => true,
        'Team:read' => true
      }
    else
      {}
    end
  end

  def legacy_role_actions(role_string)
    case role_string
    when 'owner'
      %w[read create update delete manage]
    when 'admin'
      %w[read create update manage]
    when 'member'
      %w[read create update]
    when 'viewer'
      %w[read]
    else
      []
    end
  end
end