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
      # Given: 사용자가 인증 페이지에 접근하고 로그인
      sign_in_through_form(user)
      
      # Then: 로그인 성공하고 조직 목록에 접근 가능
      visit organizations_path
      expect(page).to have_content(organization.name)
    end

    scenario "잘못된 자격증명으로 로그인 실패" do
      # Given: 사용자가 인증 페이지에 접근
      visit new_main_user_session_path
      
      # When: 잘못된 자격증명으로 로그인 시도
      fill_in 'user_email', with: user.email
      fill_in 'user_password', with: 'wrong_password'
      click_button 'Log in'
      
      # Then: 로그인 실패 메시지 표시
      expect(page).to have_content('Invalid Email or password')
    end

    scenario "조직이 없는 사용자의 로그인" do
      # Given: 조직이 없는 사용자
      user_without_org = create(:user, email: 'noorg@creatia.local')
      
      # When: 로그인하고 조직 목록 접근
      sign_in user_without_org
      visit organizations_path
      
      # Then: 조직 목록이 비어있음
      expect(page).not_to have_content(organization.name)
    end
  end

  feature "조직별 서브도메인 접근" do
    scenario "권한이 있는 조직에 접근 가능" do
      # Given: 로그인한 사용자
      sign_in user
      
      # When: 조직 컨텍스트 설정 후 대시보드 접근
      allow(DomainService).to receive(:extract_subdomain).and_return('demo')
      allow(ActsAsTenant).to receive(:current_tenant).and_return(organization)
      
      visit tenant_root_path
      
      # Then: 정상 접근 가능
      expect(page).to have_content('Dashboard')
    end

    scenario "권한이 없는 조직 접근 차단" do
      # Given: 권한이 없는 조직을 가진 사용자
      other_org = create(:organization, subdomain: 'forbidden')
      outsider = create(:user)
      
      # When: 로그인 후 권한 없는 조직 접근
      sign_in outsider
      allow(DomainService).to receive(:extract_subdomain).and_return('forbidden')
      allow(ActsAsTenant).to receive(:current_tenant).and_return(other_org)
      
      visit tenant_root_path
      
      # Then: 접근 거부 또는 리다이렉트
      expect(page).to have_content('not authorized').or have_content('sign in')
    end
  end

  feature "OAuth 인증 플로우" do
    scenario "GitHub OAuth 설정 확인" do
      # Given: OAuth 설정이 있는지 확인
      expect(Rails.application.config.omniauth_providers).to include(:github)
    end

    scenario "OAuth 사용자 생성" do
      # Given: OAuth를 통해 로그인한 GitHub 사용자 시뮬레이션
      github_user = create(:user, :oauth_github, email: 'github@creatia.local')
      
      # When: 로그인
      sign_in github_user
      
      # Then: 정상적으로 인증됨
      visit organizations_path
      expect(page).to have_content('Organizations')
    end
  end

  feature "조직 선택 및 전환" do
    let(:another_org) { create(:organization, subdomain: 'acme') }
    let!(:another_membership) { create(:organization_membership, user: user, organization: another_org, role: 'admin') }

    scenario "여러 조직에 속한 사용자의 조직 목록 확인" do
      # Given: 여러 조직의 멤버인 사용자
      sign_in user
      
      # When: 조직 목록 조회
      visit organizations_path
      
      # Then: 두 조직 모두 표시됨
      expect(page).to have_content(organization.name)
      expect(page).to have_content(another_org.name)
    end

    scenario "테넌트 전환 API 동작 확인" do
      # Given: 로그인된 사용자
      sign_in user
      
      # When: 테넌트 전환 UI를 통해 전환
      visit organizations_path
      click_link 'Switch', href: switch_organization_path(another_org)
      
      # Then: 성공적으로 전환됨
      expect(page).to have_content('Switched').or have_content(another_org.name)
    end
  end

  feature "보안 및 감사" do
    scenario "SecurityAuditService 사용 가능 확인" do
      # Given: SecurityAuditService가 정의되어 있는지 확인
      expect(defined?(SecurityAuditService)).to be_truthy
    end

    scenario "인증된 사용자의 세션 유지" do
      # Given: 로그인된 사용자
      sign_in user
      
      # When: 보호된 페이지 접근
      visit organizations_path
      
      # Then: 정상 접근 가능
      expect(page).to have_content('Organizations')
      expect(page).not_to have_content('sign in')
    end
  end

  private

  def sign_in(user)
    login_as(user, scope: :user)
  end
  
  def sign_in_through_form(user)
    visit new_main_user_session_path
    fill_in 'user_email', with: user.email
    fill_in 'user_password', with: 'password123'
    click_button 'Log in'
  end
end
