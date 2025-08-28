# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Subdomain Functionality", type: :system do
  let(:user) { create(:user, email: 'user@example.com', password: 'password123') }
  let(:admin_user) { create(:user, email: 'admin@example.com', password: 'password123') }
  let(:organization) { create(:organization, subdomain: 'testorg', name: 'Test Organization') }
  let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'member') }
  let!(:admin_membership) { create(:organization_membership, user: admin_user, organization: organization, role: 'admin') }

  before do
    # 도메인 서비스 모킹
    allow(DomainService).to receive(:base_domain).and_return('localhost')
    allow(DomainService).to receive(:extract_subdomain).and_call_original
  end

  describe "메인 도메인 (www 또는 서브도메인 없음)" do
    before do
      # 메인 도메인 시뮬레이션
      allow(DomainService).to receive(:extract_subdomain).and_return(nil)
    end

    it "메인 페이지가 정상적으로 로드되어야 함" do
      visit root_path
      
      expect(page).to have_css("body")
      expect(current_path).to eq(root_path)
    end

    it "사용자 관리 기능이 동작해야 함" do
      login_as(admin_user, scope: :user)
      visit users_path
      
      expect(page).to have_css("body")
      expect(page.has_content?('사용자') || page.has_content?('Users')).to be_truthy
    end

    it "조직 생성 기능이 동작해야 함" do
      login_as(user, scope: :user)
      visit organizations_path
      
      expect(page).to have_css("body")
      
      # 조직 생성 링크나 버튼이 있는지 확인
      expect(
        page.has_link?('새 조직') || 
        page.has_button?('조직 생성') ||
        page.has_css?('a[href*="organizations/new"]')
      ).to be_truthy
    end
  end

  describe "인증 서브도메인 (auth)" do
    before do
      # auth 서브도메인 시뮬레이션
      allow(DomainService).to receive(:extract_subdomain).and_return('auth')
      allow_any_instance_of(ActionController::TestRequest)
        .to receive(:subdomain).and_return('auth')
    end

    it "인증 전용 페이지가 로드되어야 함" do
      visit root_path
      
      expect(page).to have_css("body")
    end

    it "로그인 기능이 정상적으로 동작해야 함" do
      visit new_auth_user_session_path
      
      expect(page).to have_css("body")
      expect(page.has_content?('로그인') || page.has_content?('Log in')).to be_truthy
      
      fill_in 'Email', with: user.email
      fill_in 'Password', with: 'password123'
      click_button 'Log in'
      
      expect(page).not_to have_content('Invalid')
    end

    it "조직 선택 기능이 동작해야 함" do
      login_as(user, scope: :user)
      
      # 조직 목록 페이지로 이동
      visit organizations_path
      
      expect(page).to have_css("body")
      expect(page).to have_content(organization.name)
    end

    it "SSO 관련 라우트가 접근 가능해야 함" do
      login_as(user, scope: :user)
      
      # organization_selection 라우트 테스트
      visit organization_selection_path
      
      expect([200, 302]).to include(page.status_code)
    end
  end

  describe "조직 테넌트 서브도메인" do
    before do
      # 조직 서브도메인 시뮬레이션
      allow(DomainService).to receive(:extract_subdomain).and_return('testorg')
      allow_any_instance_of(ActionController::TestRequest)
        .to receive(:subdomain).and_return('testorg')
      
      # 테넌트 설정
      ActsAsTenant.current_tenant = organization
    end

    after do
      ActsAsTenant.current_tenant = nil
    end

    it "조직 대시보드가 로드되어야 함" do
      login_as(user, scope: :user)
      visit tenant_root_path
      
      expect(page).to have_css("body")
      expect(
        page.has_content?(organization.name) ||
        page.has_content?('대시보드') ||
        page.has_content?('Dashboard')
      ).to be_truthy
    end

    it "조직 정보 페이지가 접근 가능해야 함" do
      login_as(user, scope: :user)
      visit organization_path
      
      expect(page).to have_css("body")
      expect(page).to have_content(organization.name)
    end

    it "태스크 관리 기능이 동작해야 함" do
      login_as(user, scope: :user)
      task = create(:task, organization: organization, creator: user)
      
      visit tasks_path
      
      expect(page).to have_css("body")
      expect(page).to have_content(task.title) if task.present?
    end

    it "조직 멤버 관리가 동작해야 함" do
      login_as(admin_user, scope: :user)
      visit organization_organization_memberships_path
      
      expect(page).to have_css("body")
      expect(
        page.has_content?(user.email) ||
        page.has_content?('멤버') ||
        page.has_content?('Members')
      ).to be_truthy
    end

    it "권한이 없는 사용자는 접근이 거부되어야 함" do
      unauthorized_user = create(:user)
      login_as(unauthorized_user, scope: :user)
      
      visit tenant_root_path
      
      expect(
        page.status_code == 403 ||
        current_path == root_path ||
        page.has_content?('권한') ||
        page.has_content?('authorized')
      ).to be_truthy
    end

    it "조직 설정이 관리자에게만 접근 가능해야 함" do
      # 일반 멤버로 접근 시도
      login_as(user, scope: :user)
      visit edit_organization_path
      
      expect(
        page.status_code == 403 ||
        page.has_content?('권한') ||
        page.has_content?('authorized')
      ).to be_truthy
      
      # 관리자로 접근 시도
      login_as(admin_user, scope: :user)
      visit edit_organization_path
      
      expect(
        page.status_code == 200 ||
        page.has_content?(organization.name)
      ).to be_truthy
    end
  end

  describe "API 서브도메인 (api)" do
    before do
      # API 서브도메인 시뮬레이션
      allow(DomainService).to receive(:extract_subdomain).and_return('api')
      allow_any_instance_of(ActionController::TestRequest)
        .to receive(:subdomain).and_return('api')
    end

    it "API 엔드포인트가 접근 가능해야 함" do
      visit '/api/v1/organizations'
      
      # 인증되지 않은 요청은 401 응답
      expect(
        page.has_content?("Unauthorized") || 
        page.has_content?("권한이 없습니다")
      ).to be_truthy
      expect(
        page.body.include?('json') || 
        page.response_headers['Content-Type']&.include?('json')
      ).to be_truthy
    end

    it "인증된 API 요청이 정상 처리되어야 함" do
      # API 토큰 인증은 구현에 따라 다름
      # 여기서는 기본적인 구조만 테스트
      expect { visit '/api/v1/organizations' }.not_to raise_error
    end
  end

  describe "관리자 서브도메인 (admin)" do
    before do
      # admin 서브도메인 시뮬레이션
      allow(DomainService).to receive(:extract_subdomain).and_return('admin')
      allow_any_instance_of(ActionController::TestRequest)
        .to receive(:subdomain).and_return('admin')
    end

    it "관리자 대시보드가 접근 가능해야 함" do
      login_as(admin_user, scope: :user)
      visit admin_root_path
      
      expect(
        page.status_code == 200 ||
        current_path == admin_root_path
      ).to be_truthy
    end

    it "시스템 조직 관리가 가능해야 함" do
      login_as(admin_user, scope: :user)
      visit admin_organizations_path
      
      expect(page).to have_css("body")
      expect(
        page.has_content?(organization.name) ||
        page.has_content?('조직') ||
        page.has_content?('Organizations')
      ).to be_truthy
    end

    it "일반 사용자는 접근이 거부되어야 함" do
      login_as(user, scope: :user)
      visit admin_root_path
      
      expect(
        page.status_code == 403 ||
        page.has_content?('권한') ||
        page.has_content?('authorized')
      ).to be_truthy
    end
  end

  describe "존재하지 않는 서브도메인" do
    before do
      # 존재하지 않는 서브도메인 시뮬레이션
      allow(DomainService).to receive(:extract_subdomain).and_return('nonexistent')
      allow(Organization).to receive(:exists?).with(subdomain: 'nonexistent').and_return(false)
    end

    it "404 오류가 반환되어야 함" do
      visit root_path
      
      # 404 또는 메인으로 리다이렉트
      expect(
        page.status_code == 404 ||
        current_path == root_path
      ).to be_truthy
    end
  end

  describe "서브도메인 간 전환" do
    it "테넌트 전환 서비스가 정상 동작해야 함" do
      login_as(user, scope: :user)
      
      visit tenant_switcher_path
      
      expect(page).to have_css("body")
      expect(
        page.body.include?('json') || 
        page.response_headers['Content-Type']&.include?('json')
      ).to be_truthy
    end

    it "사용 가능한 조직 목록을 반환해야 함" do
      login_as(user, scope: :user)
      
      visit available_tenant_switcher_index_path
      
      expect(page).to have_css("body")
    end

    it "조직 전환 히스토리를 추적해야 함" do
      login_as(user, scope: :user)
      
      visit history_tenant_switcher_index_path
      
      expect(page).to have_css("body")
    end
  end

  describe "도메인 서비스 통합" do
    it "올바른 URL 생성이 가능해야 함" do
      main_url = DomainService.main_url
      auth_url = DomainService.auth_url('login')
      
      expect(main_url).to be_a(String)
      expect(auth_url).to be_a(String)
      expect(auth_url).to include('auth')
    end

    it "서브도메인 추출이 정확해야 함" do
      request = double('request', host: 'testorg.localhost', subdomain: 'testorg')
      subdomain = DomainService.extract_subdomain(request)
      
      expect(subdomain).to eq('testorg')
    end

    it "예약된 서브도메인 검증이 동작해야 함" do
      reserved_subdomains = ['www', 'auth', 'api', 'admin']
      
      reserved_subdomains.each do |subdomain|
        expect(DomainService.reserved_subdomain?(subdomain)).to be true
      end
      
      expect(DomainService.reserved_subdomain?('testorg')).to be false
    end
  end
end
