class PermissionSerializer
  include Alba::Resource

  attributes :id, :resource, :action, :name, :description
  
  attribute :display_name do |permission|
    permission.display_name
  end
  
  attribute :full_key do |permission|
    permission.full_key
  end
  
  attribute :category do |permission|
    permission.category_name
  end
  
  attribute :type do |permission|
    if permission.crud?
      'crud'
    elsif permission.management?
      'management'
    else
      'custom'
    end
  end
end