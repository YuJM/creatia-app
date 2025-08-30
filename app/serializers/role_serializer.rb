class RoleSerializer
  include Alba::Resource

  attributes :id, :name, :key, :description, :priority, :system_role, :editable
  
  attribute :permissions_count do |role|
    role.permissions.count
  end
  
  attribute :members_count do |role|
    role.organization_memberships.count
  end
  
  has_many :permissions, resource: PermissionSerializer
  
  attribute :created_at do |role|
    role.created_at.iso8601
  end
  
  attribute :updated_at do |role|
    role.updated_at.iso8601
  end
  
  attribute :can_delete do |role|
    role.destroyable?
  end
  
  attribute :level do |role|
    if role.owner_level?
      'owner'
    elsif role.admin_level?
      'admin'
    elsif role.priority >= 50
      'member'
    else
      'viewer'
    end
  end
end