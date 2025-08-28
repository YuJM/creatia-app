# frozen_string_literal: true

# Domain helper for system tests using DomainService
module TestDomainHelper
  # 테스트 환경에서 Caddy proxy 사용 설정
  def setup_test_domains
    ENV['BASE_DOMAIN'] = 'localhost.test'
    ENV['USE_CADDY_PROXY'] = 'true'
  end
  
  # DomainService 기반 URL 생성
  def test_url(subdomain: nil, path: '/')
    if subdomain.nil? || subdomain == 'www'
      DomainService.main_url(path.sub(/^\//, ''))
    else
      case subdomain
      when 'auth'
        DomainService.auth_url(path.sub(/^\//, ''))
      when 'api'
        DomainService.api_url(path.sub(/^\//, ''))
      when 'admin'
        DomainService.admin_url(path.sub(/^\//, ''))
      else
        DomainService.organization_url(subdomain, path.sub(/^\//, ''))
      end
    end
  end
  
  # Capybara visit with domain service
  def visit_domain(subdomain: nil, path: '/')
    url = test_url(subdomain: subdomain, path: path)
    visit url
  end
  
  # 로그인 URL
  def login_url(subdomain: nil)
    if subdomain == 'auth'
      test_url(subdomain: 'auth', path: '/users/sign_in')
    else
      test_url(subdomain: subdomain, path: '/users/sign_in')
    end
  end
  
  # 하드코딩된 경로들 (fallback)
  def hardcoded_paths
    {
      root: '/',
      login: '/users/sign_in',
      logout: '/users/sign_out',
      organizations: '/organizations',
      new_organization: '/organizations/new',
      users: '/users',
      api_organizations: '/api/v1/organizations',
      health_check: '/up',
      tenant_root: '/tenant',
      tenant_dashboard: '/tenant/dashboard',
      tasks: '/tasks',
      admin_root: '/admin',
      admin_organizations: '/admin/organizations'
    }
  end
  
  # Get path by name
  def path_for(name)
    hardcoded_paths[name] || '/'
  end
  
  # Helper to check current subdomain
  def current_subdomain
    uri = URI.parse(current_url)
    host_parts = uri.host.split('.')
    
    # localhost.test 형식에서 subdomain 추출
    if host_parts.size > 2 && host_parts[-2] == 'localhost' && host_parts[-1] == 'test'
      host_parts[0] == 'www' ? nil : host_parts[0]
    else
      nil
    end
  end
  
  # Check if on specific subdomain
  def on_subdomain?(subdomain)
    current = current_subdomain
    if subdomain.nil? || subdomain == 'www'
      current.nil? || current == 'www'
    else
      current == subdomain
    end
  end
end

RSpec.configure do |config|
  config.include TestDomainHelper, type: :system
  
  # 테스트 시작 전 도메인 설정
  config.before(:suite) do
    ENV['BASE_DOMAIN'] = 'localhost.test'
    ENV['USE_CADDY_PROXY'] = 'true'
  end
  
  config.before(:each, type: :system) do
    setup_test_domains
    # DomainService 메모이제이션 리셋
    DomainService.reset_memo_wise if DomainService.respond_to?(:reset_memo_wise)
  end
end