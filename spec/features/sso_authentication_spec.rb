# frozen_string_literal: true

require 'rails_helper'

RSpec.feature "SSO Authentication Flow", type: :feature do
  let(:user) { create(:user, email: 'user@creatia.local', password: 'password123') }
  let(:organization) { create(:organization, subdomain: 'demo') }
  let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'member') }

  before do
    # 개발환경에서 hosts 설정 시뮬레이션
    allow(DomainService).to receive(:base_domain).and_return('creatia.local')
    allow(DomainService).to receive(:extract_subdomain).and_return(nil)
  end

  feature "사용자가 중앙 인증 도메인에서 로그인" do
    scenario "이메일/패스워드로 성공적인 로그인" do
      # Given: 사용자가 인증 페이지에 접근
      visit DomainService.auth_url('login')
      
      # When: 올바른 자격증명으로 로그인 시도
      fill_in 'Email', with: user.email
      fill_in 'Password', with: 'password123'
      click_button 'Log in'
      
      # Then: 로그인 성공하고 조직 선택 페이지로 이동
      expect(page).to have_content('조직 선택')
      expect(page).to have_content(organization.name)
    end

    scenario "잘못된 자격증명으로 로그인 실패" do
      # Given: 사용자가 인증 페이지에 접근
      visit DomainService.auth_url('login')
      
      # When: 잘못된 자격증명으로 로그인 시도
      fill_in 'Email', with: user.email
      fill_in 'Password', with: 'wrong_password'
      click_button 'Log in'
      
      # Then: 로그인 실패 메시지 표시
      expect(page).to have_content('Invalid Email or password')
    end

    scenario "조직이 없는 사용자의 로그인" do
      # Given: 조직이 없는 사용자
      user_without_org = create(:user, email: 'noorg@creatia.local')
      visit DomainService.auth_url('login')
      
      # When: 로그인 성공
      fill_in 'Email', with: user_without_org.email
      fill_in 'Password', with: 'password123'
      click_button 'Log in'
      
      # Then: 메인 페이지로 리다이렉트 (조직 생성 안내)
      expect(current_url).to include(DomainService.main_url)
    end
  end

  feature "조직별 서브도메인 접근" do
    scenario "권한이 있는 조직 서브도메인 직접 접근" do
      # Given: 사용자가 특정 조직 도메인에 접근
      allow(DomainService).to receive(:extract_subdomain).and_return('demo')
      allow(DomainService).to receive(:organization_domain?).and_return(true)
      
      # When: 로그인하지 않은 상태에서 조직 도메인 접근
      visit "http://demo.creatia.local:3000/dashboard"
      
      # Then: 인증 페이지로 리다이렉트 (return_to 파라미터 포함)
      expect(current_url).to include('auth.creatia.local')
      expect(current_url).to include('return_to=demo')
    end

    scenario "권한이 없는 조직 서브도메인 접근 차단" do
      # Given: 사용자가 권한이 없는 조직에 접근 시도
      other_org = create(:organization, subdomain: 'forbidden')
      allow(DomainService).to receive(:extract_subdomain).and_return('forbidden')
      
      # When: 로그인 후 권한 없는 조직 접근
      sign_in user
      visit "http://forbidden.creatia.local:3000/dashboard"
      
      # Then: 접근 거부 페이지로 리다이렉트
      expect(page).to have_content('접근할 권한이 없습니다')
    end
  end

  feature "OAuth 인증 플로우" do
    scenario "GitHub OAuth로 로그인" do
      # Given: GitHub OAuth 설정
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new({
        provider: 'github',
        uid: '123456',
        info: {
          email: 'github@creatia.local',
          name: 'GitHub User'
        }
      })
      
      # When: GitHub OAuth 로그인 시도
      visit DomainService.auth_url('login')
      click_link 'Sign in with GitHub'
      
      # Then: 로그인 성공하고 사용자 생성
      expect(page).to have_content('GitHub으로 로그인했습니다')
      expect(User.find_by(email: 'github@creatia.local')).to be_present
    end

    scenario "조직 return_to와 함께 OAuth 로그인" do
      # Given: 특정 조직 return_to 파라미터와 함께 OAuth 설정
      OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new({
        provider: 'github',
        uid: '123456',
        info: {
          email: user.email,
          name: user.name
        }
      })
      
      # When: return_to 파라미터와 함께 OAuth 로그인
      visit DomainService.auth_url('login?return_to=demo')
      click_link 'Sign in with GitHub'
      
      # Then: 해당 조직으로 직접 리다이렉트
      expect(current_url).to include('demo.creatia.local')
    end
  end

  feature "조직 선택 및 전환" do
    let(:another_org) { create(:organization, subdomain: 'acme') }
    let!(:another_membership) { create(:organization_membership, user: user, organization: another_org, role: 'admin') }

    scenario "여러 조직 중 선택하여 접근" do
      # Given: 여러 조직의 멤버인 사용자
      sign_in user
      
      # When: 조직 선택 페이지에서 특정 조직 선택
      visit DomainService.auth_url('organization_selection')
      click_link organization.name
      
      # Then: 선택한 조직으로 이동
      expect(current_url).to include("#{organization.subdomain}.creatia.local")
    end

    scenario "조직 간 빠른 전환" do
      # Given: 현재 demo 조직에 로그인된 상태
      sign_in user
      allow(ActsAsTenant).to receive(:current_tenant).and_return(organization)
      
      # When: 다른 조직으로 전환 요청 (AJAX)
      page.driver.post '/tenant_switcher/switch', { subdomain: 'acme' }
      
      # Then: 전환 성공 응답
      response = JSON.parse(page.body)
      expect(response['success']).to be true
      expect(response['redirect_url']).to include('acme.creatia.local')
    end
  end

  feature "보안 및 감사" do
    scenario "의심스러운 로그인 시도 감지" do
      # Given: 여러 번의 로그인 실패 시도
      allow(SecurityAuditService).to receive(:log_login_failure)
      
      # When: 연속으로 로그인 실패
      5.times do
        visit DomainService.auth_url('login')
        fill_in 'Email', with: user.email
        fill_in 'Password', with: 'wrong_password'
        click_button 'Log in'
      end
      
      # Then: 보안 감사 로그 기록
      expect(SecurityAuditService).to have_received(:log_login_failure).exactly(5).times
    end

    scenario "세션 타임아웃 처리" do
      # Given: 로그인된 사용자
      sign_in user
      
      # When: 세션 만료 시간 설정 및 접근
      allow_any_instance_of(ActionDispatch::Request::Session).to receive(:[]).with(:last_activity_at).and_return(9.hours.ago.iso8601)
      visit DomainService.organization_url('demo', 'dashboard')
      
      # Then: 로그인 페이지로 리다이렉트
      expect(current_url).to include('login')
      expect(page).to have_content('세션이 만료되었습니다')
    end
  end

  private

  def sign_in(user)
    visit DomainService.auth_url('login')
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'password123'
    click_button 'Log in'
  end
end
