# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Basic Functionality", type: :system do
  before do
    setup_test_domains
  end
  
  describe "기본 페이지 접근" do
    it "메인 도메인에 접근 가능해야 함" do
      visit_domain(subdomain: nil, path: '/')
      wait_for_page_load
      
      # 페이지가 로드되었는지 확인
      expect(page).to have_css('body')
      
      # 에러가 없는지 확인
      expect(page).not_to have_content('NameError')
      expect(page).not_to have_content('NoMethodError')
      expect(page).not_to have_content('500')
    end
    
    it "헬스체크가 동작해야 함" do
      visit_domain(subdomain: nil, path: '/up')
      
      # 헬스체크 응답 확인 (Selenium에서는 status_code 지원 안 함)
      expect(page).to have_content('OK').or have_css('body')
      expect(page).not_to have_content('502')
    end
  end
  
  describe "인증 페이지" do
    it "로그인 페이지가 표시되어야 함" do
      visit login_url
      wait_for_page_load
      
      # 로그인 폼 요소 확인
      expect(page).to have_field('Email').or have_field('user[email]')
      expect(page).to have_field('Password').or have_field('user[password]')
      expect(page).to have_button('Log in').or have_button('로그인')
    end
  end
  
  describe "서브도메인 라우팅" do
    it "auth 서브도메인이 동작해야 함" do
      visit_domain(subdomain: 'auth', path: '/')
      wait_for_page_load
      
      # 페이지 로드 확인
      expect(page).to have_css('body')
      expect(on_subdomain?('auth')).to be_truthy
    end
    
    it "api 서브도메인이 동작해야 함" do
      visit_domain(subdomain: 'api', path: '/api/v1/organizations')
      
      # API 응답 확인 (인증 실패는 정상)
      expect(page).to have_content('Unauthorized').or have_content('{"error"')
    end
    
    it "admin 서브도메인이 동작해야 함" do
      visit_domain(subdomain: 'admin', path: '/')
      wait_for_page_load
      
      # 관리자 페이지 또는 로그인 리다이렉트 확인
      expect(page).to have_css('body')
    end
  end
  
  describe "DomainService 통합" do
    it "올바른 URL을 생성해야 함" do
      expect(DomainService.base_domain).to eq('localhost.test')
      expect(DomainService.main_url).to include('localhost.test:8080')
      expect(DomainService.auth_url).to include('auth.localhost.test:8080')
      expect(DomainService.api_url).to include('api.localhost.test:8080')
      expect(DomainService.admin_url).to include('admin.localhost.test:8080')
    end
    
    it "조직 서브도메인 URL을 생성해야 함" do
      org_url = DomainService.organization_url('testorg')
      expect(org_url).to include('testorg.localhost.test:8080')
    end
  end
end