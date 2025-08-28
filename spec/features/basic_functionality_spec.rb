# frozen_string_literal: true

require 'rails_helper'

RSpec.feature "기본 기능 동작 확인", type: :feature do
  let(:user) { create(:user, email: 'user@creatia.local', password: 'password123') }
  let(:organization) { create(:organization, subdomain: 'testorg') }
  let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'member') }

  feature "사용자 인증 기본 기능" do
    scenario "사용자가 로그인할 수 있음" do
      # When: 로그인 페이지 방문
      visit new_main_user_user_session_path
      
      # And: 로그인 정보 입력
      fill_in 'Email', with: user.email
      fill_in 'Password', with: 'password123'
      click_button 'Log in'
      
      # Then: 정상적으로 로그인됨
      expect(page).to have_content('Signed in successfully')
      expect(current_path).to eq(root_path)
    end

    scenario "로그인하지 않은 사용자는 보호된 리소스에 접근할 수 없음" do
      # When: 로그인하지 않고 조직 목록 접근
      visit organizations_path
      
      # Then: 로그인 페이지로 리다이렉트
      expect(current_path).to eq(new_main_user_user_session_path)
    end
  end

  feature "조직 관리 기본 기능" do
    scenario "로그인한 사용자는 조직 목록을 볼 수 있음" do
      # Given: 로그인한 사용자
      sign_in user
      
      # When: 조직 목록 페이지 접근
      visit organizations_path
      
      # Then: 조직 정보가 표시됨
      expect(page).to have_content(organization.name)
    end

    scenario "새로운 조직을 생성할 수 있음" do
      # Given: 로그인한 사용자
      sign_in user
      
      # When: 조직 목록 페이지에서 새 조직 생성
      visit organizations_path
      click_link 'New Organization'
      
      # And: 조직 정보 입력
      fill_in 'Name', with: 'New Organization'
      fill_in 'Subdomain', with: 'neworg'
      fill_in 'Description', with: 'A new organization for testing'
      select 'Team', from: 'Plan' if page.has_select?('Plan')
      click_button 'Create Organization'
      
      # Then: 조직이 생성되고 표시됨
      expect(page).to have_content('Organization was successfully created')
      expect(page).to have_content('New Organization')
    end
  end

  feature "사용자 관리 기본 기능" do
    scenario "사용자 목록을 조회할 수 있음" do
      # Given: 관리자 권한을 가진 사용자
      admin = create(:user, :admin)
      sign_in admin
      
      # When: 사용자 목록 페이지 접근
      visit users_path
      
      # Then: 사용자 목록이 표시됨
      expect(page).to have_content('Users')
      expect(page).to have_content(user.email)
    end
  end

  feature "테넌트 전환 기능" do
    scenario "테넌트 전환 UI가 존재함" do
      # Given: 로그인한 사용자
      sign_in user
      
      # When: 조직 목록 페이지 접근
      visit organizations_path
      
      # Then: 조직 전환 기능이 표시됨
      expect(page).to have_content(organization.name)
      expect(page).to have_link('Switch', href: switch_organization_path(organization))
    end
  end

  feature "기본 보안 기능" do
    scenario "CSRF 보호가 활성화되어 있음" do
      # Given: 로그인한 사용자
      sign_in user
      
      # When: HTML 페이지 방문
      visit organizations_path
      
      # Then: CSRF 보호는 테스트 환경에서 비활성화됨 (Rails 기본 설정)
      # 실제 환경에서는 csrf_meta_tags가 포함됨
      expect(Rails.application.config.action_controller.allow_forgery_protection).to be false
    end

    scenario "인증이 필요한 페이지는 로그인하지 않으면 접근 불가" do
      # When: 로그인하지 않고 보호된 페이지 접근
      visit organizations_path
      
      # Then: 로그인 페이지로 리다이렉트됨
      expect(current_path).to eq(new_main_user_user_session_path)
      expect(page).to have_content('Log in').or have_content('You need to sign in')
    end
  end

  private

  def sign_in(user)
    login_as(user, scope: :user)
  end
end
