# frozen_string_literal: true

require 'capybara/rspec'
require 'selenium-webdriver'

# Capybara configuration for system tests
Capybara.configure do |config|
  # Use headless Chrome by default
  config.default_driver = :selenium_chrome_headless
  config.javascript_driver = :selenium_chrome_headless
  
  # Wait times
  config.default_max_wait_time = 5
  
  # Match strategy
  config.match = :prefer_exact
  config.exact = true
  
  # Ignore hidden elements by default
  config.ignore_hidden_elements = true
  
  # Server settings
  config.server = :puma
  config.server_host = 'localhost'
  config.server_port = 3000
  
  # Start server automatically for tests (Puma on port 3000)
  config.run_server = true
  
  # Use localhost directly for development/test without Caddy
  # For Caddy proxy tests, use bin/test_simple or bin/run_system_tests
  config.app_host = nil  # Let Capybara determine the host
end

# Configure Chrome options
Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless=new')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-gpu')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--window-size=1400,1400')
  
  # Accept all SSL certificates (for test environment)
  options.add_argument('--ignore-certificate-errors')
  
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

# Configure Chrome with GUI for debugging
Capybara.register_driver :selenium_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-gpu')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--window-size=1400,1400')
  options.add_argument('--ignore-certificate-errors')
  
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

# JavaScript driver
Capybara.javascript_driver = :selenium_chrome_headless

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :selenium_chrome_headless
  end
  
  config.before(:each, type: :system, js: true) do
    driven_by :selenium_chrome_headless
  end
  
  # For debugging - use visible browser
  config.before(:each, type: :system, debug: true) do
    driven_by :selenium_chrome
  end
end