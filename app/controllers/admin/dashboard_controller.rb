# frozen_string_literal: true

module Admin
  class DashboardController < ApplicationController
    before_action :authenticate_admin!
    
    def index
      @organizations_count = Organization.count
      @users_count = User.count
      @recent_organizations = Organization.order(created_at: :desc).limit(10)
      @recent_users = User.order(created_at: :desc).limit(10)
    end
    
    private
    
    def authenticate_admin!
      redirect_to root_path unless current_user&.admin?
    end
  end
end