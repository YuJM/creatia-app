module Roles
  class PermissionSelectorComponent < ViewComponent::Base
    def initialize(role:, permissions:, selected_ids: [])
      @role = role
      @permissions = permissions
      @selected_ids = selected_ids || []
    end

    private

    attr_reader :role, :permissions, :selected_ids

    def grouped_permissions
      @grouped_permissions ||= permissions.group_by(&:resource)
    end

    def permission_checked?(permission)
      selected_ids.include?(permission.id)
    end

    def resource_icon(resource)
      case resource
      when 'Organization'
        '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"></path>'
      when 'Task'
        '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"></path>'
      when 'Service'
        '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h14a2 2 0 002-2v-4a2 2 0 00-2-2m-2-4h.01M17 16h.01"></path>'
      when 'User', 'OrganizationMembership'
        '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"></path>'
      when 'Role', 'Permission'
        '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z"></path>'
      else
        '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>'
      end
    end

    def action_badge_color(action)
      case action
      when 'read'
        'bg-green-100 text-green-800'
      when 'create'
        'bg-blue-100 text-blue-800'
      when 'update'
        'bg-yellow-100 text-yellow-800'
      when 'delete'
        'bg-red-100 text-red-800'
      when 'manage'
        'bg-purple-100 text-purple-800'
      else
        'bg-gray-100 text-gray-800'
      end
    end
  end
end