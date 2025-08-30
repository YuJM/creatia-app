module Roles
  class RoleCardComponent < ViewComponent::Base
    include Turbo::FramesHelper
    
    def initialize(role:, organization:, current_user:)
      @role = role
      @organization = organization
      @current_user = current_user
    end

    private

    attr_reader :role, :organization, :current_user

    def role_level_badge
      case
      when role.owner_level?
        tag.span('Owner', class: 'px-2 py-1 text-xs font-semibold rounded-full bg-purple-100 text-purple-800')
      when role.admin_level?
        tag.span('Admin', class: 'px-2 py-1 text-xs font-semibold rounded-full bg-blue-100 text-blue-800')
      when role.priority >= 50
        tag.span('Member', class: 'px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800')
      else
        tag.span('Viewer', class: 'px-2 py-1 text-xs font-semibold rounded-full bg-gray-100 text-gray-800')
      end
    end

    def system_badge
      return unless role.system_role
      tag.span('시스템', class: 'px-2 py-1 text-xs font-semibold rounded-full bg-yellow-100 text-yellow-800')
    end

    def members_count
      role.organization_memberships.count
    end

    def permissions_count
      role.permissions.count
    end

    def can_edit?
      role.editable? && can?(:update, role)
    end

    def can_delete?
      role.destroyable? && can?(:destroy, role)
    end

    def can_duplicate?
      can?(:create, Role)
    end
  end
end