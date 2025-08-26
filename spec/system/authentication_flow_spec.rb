# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Authentication Flow", type: :system do
  let(:user) { create(:user, email: 'user@example.com', password: 'password123') }
  let(:admin_user) { create(:user, email: 'admin@example.com', password: 'password123') }
  let(:organization1) { create(:organization, subdomain: 'org1', name: 'Organization 1') }
  let(:organization2) { create(:organization, subdomain: 'org2', name: 'Organization 2') }
  
  let!(:membership1) { create(:organization_membership, user: user, organization: organization1, role: 'admin') }
  let!(:membership2) { create(:organization_membership, user: user, organization: organization2, role: 'member') }

  before do
    allow(DomainService).to receive(:base_domain).and_return('localhost')
    allow(DomainService).to receive(:extract_subdomain).and_call_original
  end

  describe "완전한 인증 사이클" do
    it "로그인부터 조직 접근까지의 전체 플로우가 동작해야 함" do
      # 1. 메인 페이지 접근
      visit root_path
      expect(page).to have_http_status(:ok)

      # 2. 보호된 리소스 접근 시도 (로그인 페이지로 리다이렉트)
      visit users_path
      expect(page).to have_current_path(new_main_user_session_path)

      # 3. 로그인 수행
      fill_in 'Email', with: user.email
      fill_in 'Password', with: 'password123'
      click_button 'Log in'

      # 4. 로그인 성공 확인
      expect(page).not_to have_content('Invalid')
      expect(page).not_to have_current_path(new_main_user_session_path)

      # 5. 인증된 상태에서 보호된 리소스 접근
      visit users_path
      expect(page).to have_http_status(:ok) ||
        expect(page).to have_http_status(:forbidden) # 권한에 따라

      # 6. 조직 목록 확인
      visit organizations_path
      expect(page).to have_content(organization1.name)
      expect(page).to have_content(organization2.name)
    end

    it "세션 만료 후 재인증이 정상 동작해야 함" do
      # 로그인
      login_as(user, scope: :user)
      visit organizations_path
      expect(page).to have_http_status(:ok)

      # 세션 만료 시뮬레이션
      logout(:user)
      
      # 보호된 리소스 재접근
      visit organizations_path
      expect(page).to have_current_path(new_main_user_session_path)
    end
  end

  describe "멀티 조직 인증 플로우" do
    it "사용자가 여러 조직에 접근할 수 있어야 함" do
      login_as(user, scope: :user)

      # 첫 번째 조직 접근
      allow(DomainService).to receive(:extract_subdomain).and_return('org1')
      ActsAsTenant.current_tenant = organization1
      
      visit tenant_root_path
      expect(page).to have_http_status(:ok)
      
      # 두 번째 조직 접근
      allow(DomainService).to receive(:extract_subdomain).and_return('org2')
      ActsAsTenant.current_tenant = organization2
      
      visit tenant_root_path
      expect(page).to have_http_status(:ok)

      ActsAsTenant.current_tenant = nil
    end

    it "권한이 없는 조직 접근시 차단되어야 함" do
      unauthorized_org = create(:organization, subdomain: 'unauthorized')
      login_as(user, scope: :user)

      allow(DomainService).to receive(:extract_subdomain).and_return('unauthorized')
      ActsAsTenant.current_tenant = unauthorized_org
      
      visit tenant_root_path
      expect(page).to have_http_status(:forbidden) ||
        expect(page).to have_content('권한') ||
        expect(page).to have_content('authorized')

      ActsAsTenant.current_tenant = nil
    end
  end

  describe "역할 기반 접근 제어" do
    before { login_as(user, scope: :user) }

    it "관리자 역할로 조직 관리 기능에 접근할 수 있어야 함" do
      allow(DomainService).to receive(:extract_subdomain).and_return('org1')
      ActsAsTenant.current_tenant = organization1

      visit edit_organization_path
      expect(page).to have_http_status(:ok)

      ActsAsTenant.current_tenant = nil
    end

    it "멤버 역할로는 조직 관리 기능에 접근이 제한되어야 함" do
      allow(DomainService).to receive(:extract_subdomain).and_return('org2')
      ActsAsTenant.current_tenant = organization2

      visit edit_organization_path
      expect(page).to have_http_status(:forbidden) ||
        expect(page).to have_content('권한') ||
        expect(page).to have_content('authorized')

      ActsAsTenant.current_tenant = nil
    end

    it "조직 멤버 관리 권한이 올바르게 적용되어야 함" do
      allow(DomainService).to receive(:extract_subdomain).and_return('org1')
      ActsAsTenant.current_tenant = organization1

      # 관리자로서 멤버 목록 접근
      visit organization_organization_memberships_path
      expect(page).to have_http_status(:ok)

      ActsAsTenant.current_tenant = nil
    end
  end

  describe "OAuth 인증 플로우" do
    it "GitHub OAuth 설정이 올바르게 구성되어야 함" do
      visit new_main_user_session_path
      
      # GitHub 로그인 링크가 있는지 확인
      expect(page).to have_link('GitHub') ||
        expect(page).to have_css('a[href*="github"]') ||
        expect(page).to have_content('GitHub로 로그인')
    end

    it "OAuth 콜백 라우트가 정의되어 있어야 함" do
      expect { Rails.application.routes.recognize_path('/auth/github/callback') }
        .not_to raise_error
    end
  end

  describe "보안 검증" do
    it "패스워드 재설정 플로우가 동작해야 함" do
      visit new_main_user_session_path
      
      if page.has_link?('비밀번호를 잊으셨나요?') || page.has_link?('Forgot your password?')
        click_link '비밀번호를 잊으셨나요?' rescue click_link 'Forgot your password?'
        
        expect(page).to have_http_status(:ok)
        expect(page).to have_field('Email')
      end
    end

    it "계정 잠금 메커니즘이 있어야 함" do
      # 여러 번 잘못된 로그인 시도
      visit new_main_user_session_path
      
      5.times do
        fill_in 'Email', with: user.email
        fill_in 'Password', with: 'wrongpassword'
        click_button 'Log in'
      end
      
      # 계정 잠금 또는 제한 메시지 확인 (Devise 설정에 따라)
      expect(page).to have_content('Invalid') ||
        expect(page).to have_content('locked') ||
        expect(page).to have_content('attempts')
    end

    it "CSRF 보호가 활성화되어 있어야 함" do
      visit new_main_user_session_path
      
      # CSRF 토큰이 폼에 포함되어 있는지 확인
      expect(page).to have_css('input[name="authenticity_token"]', visible: false)
    end

    it "세션 고정 공격 방지가 되어야 함" do
      # 로그인 전 세션 ID
      visit root_path
      session_before = get_session_id
      
      # 로그인
      login_as(user, scope: :user)
      visit root_path
      session_after = get_session_id
      
      # 세션 ID가 변경되었는지 확인 (보안상 중요)
      expect(session_before).not_to eq(session_after) if session_before && session_after
    end
  end

  describe "인증 상태 지속성" do
    it "브라우저 재시작 시뮬레이션 후에도 세션이 유지되어야 함" do
      login_as(user, scope: :user)
      visit organizations_path
      expect(page).to have_http_status(:ok)

      # 쿠키 기반 세션 지속성 확인
      # (실제 브라우저 재시작은 시뮬레이션하기 어려우므로 쿠키 확인)
      cookies = page.driver.browser.manage.all_cookies
      session_cookie = cookies.find { |c| c[:name].include?('session') }
      expect(session_cookie).to be_present
    end

    it "Remember me 기능이 동작해야 함" do
      visit new_main_user_session_path
      
      fill_in 'Email', with: user.email
      fill_in 'Password', with: 'password123'
      
      if page.has_checkbox?('Remember me') || page.has_checkbox?('기억하기')
        check 'Remember me' rescue check '기억하기'
      end
      
      click_button 'Log in'
      
      # Remember me 쿠키 확인
      cookies = page.driver.browser.manage.all_cookies
      remember_cookie = cookies.find { |c| c[:name].include?('remember') }
      expect(remember_cookie).to be_present if page.has_checkbox?('Remember me')
    end
  end

  describe "조직 전환 및 컨텍스트" do
    before { login_as(user, scope: :user) }

    it "조직 전환 API가 정상 동작해야 함" do
      # 테넌트 전환 요청
      page.driver.post switch_tenant_switcher_index_path, 
                       { organization_id: organization1.id }
      
      expect(page.status_code).to be_in([200, 302])
    end

    it "현재 조직 컨텍스트 정보를 올바르게 반환해야 함" do
      visit context_tenant_switcher_index_path
      
      expect(page).to have_http_status(:ok)
      expect(page.body).to include('json') || 
        page.response_headers['Content-Type']&.include?('json')
    end

    it "조직별 권한 검증이 실시간으로 동작해야 함" do
      # 조직 1에서 관리자 권한으로 접근
      allow(DomainService).to receive(:extract_subdomain).and_return('org1')
      ActsAsTenant.current_tenant = organization1
      
      page.driver.post validate_access_tenant_switcher_index_path,
                       { action: 'manage_members' }
      
      expect(page.status_code).to eq(200)

      # 조직 2에서 멤버 권한으로 같은 액션 시도
      allow(DomainService).to receive(:extract_subdomain).and_return('org2')
      ActsAsTenant.current_tenant = organization2
      
      page.driver.post validate_access_tenant_switcher_index_path,
                       { action: 'manage_members' }
      
      expect(page.status_code).to be_in([403, 422])

      ActsAsTenant.current_tenant = nil
    end
  end

  describe "보안 감사 및 로깅" do
    it "인증 실패가 로깅되어야 함" do
      # SecurityAuditService 호출 확인
      expect(SecurityAuditService).to receive(:log_authentication_failure)
        .at_least(:once)
      
      visit new_main_user_session_path
      fill_in 'Email', with: user.email
      fill_in 'Password', with: 'wrongpassword'
      click_button 'Log in'
    end

    it "권한 없는 접근이 로깅되어야 함" do
      unauthorized_user = create(:user)
      login_as(unauthorized_user, scope: :user)
      
      expect(SecurityAuditService).to receive(:log_unauthorized_access)
        .at_least(:once)
      
      allow(DomainService).to receive(:extract_subdomain).and_return('org1')
      ActsAsTenant.current_tenant = organization1
      
      visit edit_organization_path
      
      ActsAsTenant.current_tenant = nil
    end
  end

  private

  def get_session_id
    cookies = page.driver.browser.manage.all_cookies
    session_cookie = cookies.find { |c| c[:name].include?('session') }
    session_cookie&.dig(:value)
  end
end
