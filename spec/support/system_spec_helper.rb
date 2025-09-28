# frozen_string_literal: true

# System specs configuration and helpers
module SystemSpecHelper
  # Note: Rails URL helpers don't work in Capybara system specs
  # Use TestPathsHelper for hard-coded paths instead
  
  # Helper method to check if page has successfully loaded
  def page_loaded?
    page.has_css?('body')
  end
  
  # Helper method to check for error pages
  def has_error_page?
    page.has_content?('404') || 
    page.has_content?('500') || 
    page.has_content?('Not Found') ||
    page.has_content?('Internal Server Error')
  end
  
  # Helper method to check for unauthorized access
  def has_unauthorized_message?
    page.has_content?('Unauthorized') || 
    page.has_content?('권한이 없습니다') ||
    page.has_content?('Access Denied') ||
    page.has_content?('접근이 거부되었습니다')
  end
  
  # Helper method to check for forbidden access
  def has_forbidden_message?
    page.has_content?('Forbidden') ||
    page.has_content?('권한') ||
    page.has_content?('You are not authorized') ||
    page.has_content?('접근 권한이 없습니다')
  end
  
  # Helper to check if user is on login page
  def on_login_page?
    current_path == '/users/sign_in' ||
    current_path == '/main/users/sign_in' ||
    current_path == '/auth/users/sign_in' ||
    page.has_content?('Log in') ||
    page.has_content?('로그인')
  end
  
  # Helper to perform login
  def perform_login(user, password = 'password123')
    visit '/main/users/sign_in'
    fill_in 'Email', with: user.email
    fill_in 'Password', with: password
    click_button 'Log in'
  end
  
  # Helper to check if response is JSON
  def json_response?
    page.response_headers['Content-Type']&.include?('json') ||
    page.body.include?('{') && page.body.include?('}')
  rescue
    false
  end
end

RSpec.configure do |config|
  config.include SystemSpecHelper, type: :system
end