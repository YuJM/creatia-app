# frozen_string_literal: true

# Path helpers for system specs - hard-coded paths since Rails URL helpers don't work in Capybara
module TestPathsHelper
  # When using Caddy proxy, use these methods
  def test_base_url
    'http://localhost.test'
  end
  
  def auth_base_url
    'http://auth.localhost.test'
  end
  
  def api_base_url
    'http://api.localhost.test'
  end
  
  def admin_base_url
    'http://admin.localhost.test'
  end
  
  def org_base_url(subdomain)
    "http://#{subdomain}.localhost.test"
  end
  
  # Main domain paths
  def root_path
    '/'
  end
  
  def users_path
    '/users'
  end
  
  def organizations_path
    '/organizations'
  end
  
  def new_organization_path
    '/organizations/new'
  end
  
  def organization_path(org = nil)
    org ? "/organizations/#{org.id}" : '/organization'
  end
  
  def edit_organization_path(org = nil)
    org ? "/organizations/#{org.id}/edit" : '/organization/edit'
  end
  
  # Auth domain paths
  def new_main_user_session_path
    '/main/users/sign_in'
  end
  
  def new_auth_user_session_path
    '/auth/users/sign_in'
  end
  
  def organization_selection_path
    '/organization_selection'
  end
  
  # Tenant paths
  def tenant_root_path
    '/tenant'
  end
  
  def tenant_dashboard_path
    '/tenant/dashboard'
  end
  
  def tasks_path
    '/tasks'
  end
  
  def organization_organization_memberships_path
    '/organization/organization_memberships'
  end
  
  # Admin paths
  def admin_root_path
    '/admin'
  end
  
  def admin_organizations_path
    '/admin/organizations'
  end
  
  # API paths
  def api_v1_organizations_path
    '/api/v1/organizations'
  end
  
  def rails_health_check_path
    '/up'
  end
  
  # Tenant switcher paths
  def tenant_switcher_path
    '/tenant/switcher'
  end
  
  def available_tenant_switcher_index_path
    '/tenant/switcher/available'
  end
  
  def history_tenant_switcher_index_path
    '/tenant/switcher/history'
  end
  
  # Helper to visit with full URL (for subdomain testing)
  def visit_subdomain(subdomain, path = '/')
    if subdomain == 'main' || subdomain.nil?
      visit "#{test_base_url}#{path}"
    elsif subdomain == 'auth'
      visit "#{auth_base_url}#{path}"
    elsif subdomain == 'api'
      visit "#{api_base_url}#{path}"
    elsif subdomain == 'admin'
      visit "#{admin_base_url}#{path}"
    else
      visit "#{org_base_url(subdomain)}#{path}"
    end
  end
end

RSpec.configure do |config|
  config.include TestPathsHelper, type: :system
end