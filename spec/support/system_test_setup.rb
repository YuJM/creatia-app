# frozen_string_literal: true

# System test setup and configuration
module SystemTestSetup
  extend ActiveSupport::Concern
  
  included do
    # Warden test helpers for authentication
    include Warden::Test::Helpers
    
    # Setup before all system tests
    before(:each) do
      # Reset Warden
      Warden.test_reset!
      
      # Clear any existing tenant
      ActsAsTenant.current_tenant = nil
      
      # Reset DomainService memoization if needed
      if DomainService.respond_to?(:reset_memo_wise)
        DomainService.reset_memo_wise
      end
    end
    
    # Cleanup after tests
    after(:each) do
      Warden.test_reset!
      ActsAsTenant.current_tenant = nil
    end
  end
  
  # Helper to visit a path with proper subdomain
  def visit_with_subdomain(subdomain, path = '/')
    if subdomain.nil? || subdomain == 'www'
      url = "http://localhost.test:8080#{path}"
    else
      url = "http://#{subdomain}.localhost.test:8080#{path}"
    end
    visit url
  end
  
  # Helper to login a user
  def login_user(user, subdomain = nil)
    if subdomain
      visit_with_subdomain(subdomain, '/users/sign_in')
    else
      visit 'http://localhost.test:8080/users/sign_in'
    end
    
    fill_in 'Email', with: user.email
    fill_in 'Password', with: user.password || 'password123'
    click_button 'Log in'
    
    # Wait for login to complete
    expect(page).not_to have_content('Invalid')
  end
  
  # Helper to set tenant context
  def with_tenant(organization)
    ActsAsTenant.with_tenant(organization) do
      yield
    end
  end
  
  # Check if on the expected subdomain
  def on_subdomain?(subdomain)
    current_host = URI.parse(current_url).host
    if subdomain.nil? || subdomain == 'www'
      current_host == 'localhost.test'
    else
      current_host == "#{subdomain}.localhost.test"
    end
  end
  
  # Wait for page load
  def wait_for_page_load
    expect(page).to have_css('body')
    sleep 0.1 # Small delay for JavaScript
  end
  
  # Check for common error messages
  def has_error_message?
    page.has_content?('error') ||
    page.has_content?('Error') ||
    page.has_content?('오류')
  end
  
  # Check for success messages
  def has_success_message?
    page.has_content?('success') ||
    page.has_content?('Success') ||
    page.has_content?('성공')
  end
end

RSpec.configure do |config|
  config.include SystemTestSetup, type: :system
end