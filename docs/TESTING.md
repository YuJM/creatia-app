# CreatiaApp Testing Guide

## Overview

CreatiaApp uses RSpec for testing with support for multi-tenant subdomain routing through Caddy reverse proxy.

## Test Setup

### Prerequisites

1. **Install Caddy** (if not already installed):
   ```bash
   brew install caddy
   ```

2. **Setup test domains** in `/etc/hosts`:
   ```bash
   sudo bin/setup_test_hosts
   ```

   This adds the following test domains:
   - `localhost.test` - Main domain
   - `www.localhost.test` - WWW subdomain
   - `auth.localhost.test` - Authentication subdomain
   - `api.localhost.test` - API subdomain
   - `admin.localhost.test` - Admin subdomain
   - `org1.localhost.test`, `org2.localhost.test` - Test organization subdomains
   - `testorg.localhost.test` - Another test organization
   - `unauthorized.localhost.test` - For testing unauthorized access

## Running Tests

### Standard Test Execution

For regular unit and integration tests:
```bash
bundle exec rspec
```

### System Tests with Caddy

For system/feature tests that require subdomain routing:
```bash
bin/test_with_caddy
```

This script will:
1. Prepare the test database
2. Start Rails server on port 3000
3. Start Caddy reverse proxy on port 8080
4. Run the system tests
5. Clean up all processes when done

To run specific test files:
```bash
bin/test_with_caddy spec/system/authentication_flow_spec.rb
```

To run a specific test example:
```bash
bin/test_with_caddy spec/system/authentication_flow_spec.rb:20
```

### Manual Testing with Caddy

If you want to manually test the application with Caddy:

1. Start Rails server:
   ```bash
   bin/rails server
   ```

2. In another terminal, start Caddy:
   ```bash
   caddy run --config Caddyfile.test --adapter caddyfile
   ```

3. Access the application at:
   - Main: http://localhost.test:8080
   - Auth: http://auth.localhost.test:8080
   - Admin: http://admin.localhost.test:8080
   - Organizations: http://{org-subdomain}.localhost.test:8080

## Test Structure

### Unit Tests
- `spec/models/` - Model specs
- `spec/services/` - Service object specs
- `spec/helpers/` - Helper specs

### Integration Tests
- `spec/controllers/` - Controller specs (deprecated, use request specs)
- `spec/requests/` - Request specs (API and controller testing)
- `spec/features/` - Feature specs (user workflows)

### System Tests
- `spec/system/` - Full browser-based tests with JavaScript support

Key system test files:
- `authentication_flow_spec.rb` - Complete authentication workflows
- `subdomain_functionality_spec.rb` - Multi-tenant subdomain routing
- `http_request_flow_spec.rb` - HTTP request handling
- `organization_management_spec.rb` - Organization CRUD operations
- `sso_authentication_spec.rb` - Single Sign-On flows

## Test Helpers

### System Test Helpers

Located in `spec/support/system_spec_helper.rb`:

```ruby
# Check if page loaded successfully
page_loaded?

# Check for error pages
has_error_page?

# Check for authorization errors
has_unauthorized_message?
has_forbidden_message?

# Check if on login page
on_login_page?

# Perform login
perform_login(user, password = 'password123')

# Check if response is JSON
json_response?
```

### Authentication Helpers

For controller and request specs:
```ruby
# Devise helpers
sign_in(user)
sign_out(user)

# Warden helpers for system specs
login_as(user, scope: :user)
logout(:user)
```

## Troubleshooting

### Common Issues

1. **"Caddy is not installed"**
   - Install Caddy: `brew install caddy`

2. **"Connection refused" errors**
   - Ensure Rails server is running on port 3000
   - Check that Caddy is running on port 8080
   - Verify /etc/hosts entries are correct

3. **"undefined method" for path helpers in system specs**
   - System specs use hard-coded paths instead of Rails path helpers
   - Use paths like `/users/sign_in` instead of `new_user_session_path`

4. **Tests failing with subdomain issues**
   - Ensure test domains are in /etc/hosts
   - Check that DomainService is configured for test environment
   - Verify Caddy is routing correctly

### Debug Mode

To see what's happening during tests:

1. Add `save_and_open_page` in your test:
   ```ruby
   it "shows the login page" do
     visit new_user_session_path
     save_and_open_page  # Opens browser with current page
     expect(page).to have_content("Log in")
   end
   ```

2. Use `binding.pry` for debugging:
   ```ruby
   it "logs in the user" do
     visit new_user_session_path
     binding.pry  # Stops execution here
     fill_in 'Email', with: user.email
   end
   ```

3. Run tests with documentation format:
   ```bash
   bin/test_with_caddy --format documentation
   ```

## Continuous Integration

For CI environments, you'll need to:

1. Install Caddy in the CI environment
2. Add test domains to /etc/hosts or use a DNS solution
3. Use the test database configuration
4. Run tests with `bin/test_with_caddy`

Example GitHub Actions workflow:
```yaml
- name: Setup test hosts
  run: |
    echo "127.0.0.1 localhost.test www.localhost.test" | sudo tee -a /etc/hosts
    echo "127.0.0.1 auth.localhost.test api.localhost.test" | sudo tee -a /etc/hosts
    # Add more test domains as needed

- name: Install Caddy
  run: |
    sudo apt-get update
    sudo apt-get install -y caddy

- name: Run tests
  run: bin/test_with_caddy
```