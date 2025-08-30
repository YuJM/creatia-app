class PermissionAuditLog < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :organization
  belongs_to :resource, polymorphic: true, optional: true
  
  # Validations
  validates :action, presence: true
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :permitted, -> { where(permitted: true) }
  scope :denied, -> { where(permitted: false) }
  scope :for_resource, ->(resource) { where(resource: resource) }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_organization, ->(org) { where(organization: org) }
  scope :by_action, ->(action) { where(action: action) }
  scope :today, -> { where('created_at >= ?', Time.current.beginning_of_day) }
  scope :this_week, -> { where('created_at >= ?', Time.current.beginning_of_week) }
  scope :this_month, -> { where('created_at >= ?', Time.current.beginning_of_month) }
  
  # Class methods
  def self.log_action(user:, organization:, action:, resource: nil, permitted:, context: {}, request: nil)
    create!(
      user: user,
      organization: organization,
      action: action,
      resource: resource,
      permitted: permitted,
      context: context.merge(
        timestamp: Time.current.iso8601,
        user_email: user.email,
        organization_name: organization.name
      ),
      ip_address: request&.remote_ip,
      user_agent: request&.user_agent
    )
  end
  
  def self.log_success(user:, organization:, action:, resource: nil, context: {}, request: nil)
    log_action(
      user: user,
      organization: organization,
      action: action,
      resource: resource,
      permitted: true,
      context: context,
      request: request
    )
  end
  
  def self.log_denial(user:, organization:, action:, resource: nil, context: {}, request: nil)
    log_action(
      user: user,
      organization: organization,
      action: action,
      resource: resource,
      permitted: false,
      context: context.merge(denial_reason: context[:reason] || 'Permission denied'),
      request: request
    )
  end
  
  def self.summary_for_period(start_date, end_date, organization: nil)
    scope = where(created_at: start_date..end_date)
    scope = scope.where(organization: organization) if organization
    
    {
      total_actions: scope.count,
      permitted_actions: scope.permitted.count,
      denied_actions: scope.denied.count,
      unique_users: scope.distinct.count(:user_id),
      actions_by_type: scope.group(:action).count,
      actions_by_resource: scope.group(:resource_type).count,
      denial_rate: calculate_denial_rate(scope)
    }
  end
  
  def self.calculate_denial_rate(scope)
    total = scope.count
    return 0 if total.zero?
    
    (scope.denied.count.to_f / total * 100).round(2)
  end
  
  # Instance methods
  def success?
    permitted == true
  end
  
  def denied?
    permitted == false
  end
  
  def resource_display_name
    return 'N/A' unless resource
    
    if resource.respond_to?(:name)
      resource.name
    elsif resource.respond_to?(:title)
      resource.title
    else
      "#{resource_type} ##{resource_id}"
    end
  end
  
  def denial_reason
    context['denial_reason'] if denied?
  end
  
  def location_info
    return {} unless ip_address.present?
    
    {
      ip_address: ip_address,
      user_agent: user_agent,
      browser: parse_browser_from_user_agent,
      os: parse_os_from_user_agent
    }
  end
  
  private
  
  def parse_browser_from_user_agent
    return nil unless user_agent
    
    case user_agent
    when /Chrome/
      'Chrome'
    when /Safari/
      'Safari'
    when /Firefox/
      'Firefox'
    when /Edge/
      'Edge'
    else
      'Unknown'
    end
  end
  
  def parse_os_from_user_agent
    return nil unless user_agent
    
    case user_agent
    when /Windows/
      'Windows'
    when /Mac OS/
      'macOS'
    when /Linux/
      'Linux'
    when /Android/
      'Android'
    when /iOS|iPhone|iPad/
      'iOS'
    else
      'Unknown'
    end
  end
end