module Organization
  class MemberRowComponent < ViewComponent::Base
    include Turbo::FramesHelper
    
    def initialize(membership:, current_user:, organization:)
      @membership = membership
      @current_user = current_user
      @organization = organization
      @available_roles = organization.roles.by_priority
    end

    private

    attr_reader :membership, :current_user, :organization, :available_roles

    def member
      membership.user
    end

    def current_role
      if membership.role_id?
        membership.role_object
      else
        # Legacy role - find or create corresponding dynamic role
        organization.roles.find_by(key: membership.role)
      end
    end

    def role_display_name
      if membership.role_id? && membership.role_object
        membership.role_object.name
      else
        membership.display_role
      end
    end

    def role_badge_color
      return 'bg-purple-100 text-purple-800' if membership.owner?
      return 'bg-blue-100 text-blue-800' if membership.admin?
      return 'bg-green-100 text-green-800' if membership.role == 'member'
      'bg-gray-100 text-gray-800'
    end

    def can_manage?
      can?(:manage, membership)
    end

    def can_change_role?
      can?(:change_role, membership) && !membership.owner?
    end

    def can_remove?
      can?(:destroy, membership) && membership.user != current_user
    end

    def is_current_user?
      membership.user == current_user
    end
  end
end