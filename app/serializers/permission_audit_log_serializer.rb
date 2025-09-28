class PermissionAuditLogSerializer
  include Alba::Resource

  attributes :id, :action, :resource_type, :resource_id, :permitted, :context
  
  one :user, resource: UserSerializer
  
  attribute :resource_name do |log|
    log.resource&.to_s
  end
  
  attribute :created_at do |log|
    log.created_at.iso8601
  end
  
  attribute :formatted_time do |log|
    log.created_at.strftime('%Y-%m-%d %H:%M:%S')
  end
  
  attribute :action_type do |log|
    case log.action
    when 'read', 'index', 'show'
      'view'
    when 'create', 'new'
      'create'
    when 'update', 'edit'
      'modify'
    when 'destroy', 'delete'
      'delete'
    when 'manage'
      'admin'
    else
      'other'
    end
  end
end