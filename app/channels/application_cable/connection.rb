module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user
    identified_by :current_organization

    def connect
      self.current_user = find_verified_user
      self.current_organization = find_organization
      logger.add_tags 'ActionCable', current_user.id, current_organization&.id
    end

    private

    def find_verified_user
      if verified_user = env['warden'].user
        verified_user
      else
        reject_unauthorized_connection
      end
    end

    def find_organization
      # From session, subdomain, or user's default organization
      if session[:organization_id]
        Organization.find_by(id: session[:organization_id])
      elsif current_user
        current_user.organizations.first
      end
    end

    def session
      @session ||= env['rack.session']
    end
  end
end
