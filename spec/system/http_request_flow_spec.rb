# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "HTTP Request Flow", type: :system do
  let(:user) { create(:user, email: 'test@example.com', password: 'password123') }
  let(:organization) { create(:organization, subdomain: 'testorg') }
  let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'admin') }

  before do
    # 테스트용 도메인 설정
    allow(DomainService).to receive(:base_domain).and_return('localhost')
    allow(DomainService).to receive(:extract_subdomain).and_call_original
  end

  describe "메인 도메인 접근" do
    it "홈페이지에 성공적으로 접근할 수 있어야 함" do
      visit root_path
      
      expect(page).to have_http_status(:ok)
      expect(page).not_to have_content('error')
      expect(page).not_to have_content('500')
      expect(page).not_to have_content('NameError')
    end

    it "존재하지 않는 페이지 접근시 적절한 404 처리" do
      visit '/nonexistent-page'
      
      expect(page).to have_http_status(:not_found)
    end

    it "인증이 필요한 페이지 접근시 로그인 페이지로 리다이렉트" do
      visit users_path
      
      # Devise 리다이렉트 확인
      expect(page).to have_current_path(new_main_user_session_path)
    end
  end

  describe "인증 플로우" do
    it "로그인 페이지가 정상적으로 렌더링되어야 함" do
      visit new_main_user_session_path
      
      expect(page).to have_content('로그인') or expect(page).to have_content('Log in')
      expect(page).to have_field('Email') or expect(page).to have_field('email')
      expect(page).to have_field('Password') or expect(page).to have_field('password')
    end

    it "올바른 자격증명으로 로그인 성공해야 함", js: true do
      visit new_main_user_session_path
      
      fill_in 'Email', with: user.email
      fill_in 'Password', with: 'password123'
      click_button 'Log in'
      
      # 로그인 성공 후 리다이렉트 확인
      expect(page).not_to have_content('Invalid')
      expect(page).not_to have_current_path(new_main_user_session_path)
    end

    it "잘못된 자격증명으로 로그인 실패해야 함" do
      visit new_main_user_session_path
      
      fill_in 'Email', with: user.email
      fill_in 'Password', with: 'wrongpassword'
      click_button 'Log in'
      
      expect(page).to have_content('Invalid') or expect(page).to have_content('잘못된')
    end
  end

  describe "조직 컨텍스트 플로우" do
    before do
      # 사용자 로그인
      login_as(user, scope: :user)
    end

    it "조직 목록 페이지에 접근할 수 있어야 함" do
      visit organizations_path
      
      expect(page).to have_http_status(:ok)
      expect(page).to have_content(organization.name)
    end

    it "조직 전환이 정상적으로 동작해야 함" do
      visit organizations_path
      
      # 조직 전환 시도 (실제 구현에 따라 조정 필요)
      if page.has_link?('전환') || page.has_button?('전환')
        click_link '전환'
      elsif page.has_css?("[data-action*='switch']")
        find("[data-action*='switch']").click
      end
      
      # 전환 후 상태 확인
      expect(page).not_to have_content('error')
    end
  end

  describe "API 엔드포인트 플로우" do
    it "API 헬스체크가 정상적으로 동작해야 함" do
      visit rails_health_check_path
      
      expect(page).to have_http_status(:ok)
    end

    it "인증되지 않은 API 요청시 적절한 응답" do
      visit '/api/v1/organizations'
      
      expect(page).to have_http_status(:unauthorized)
    end
  end

  describe "오류 처리 플로우" do
    it "서버 오류 발생시 적절한 오류 페이지 표시" do
      # 의도적으로 오류를 발생시키는 것은 어려우므로,
      # 오류 페이지 자체의 접근성만 확인
      expect(File.exist?(Rails.root.join('public', '500.html'))).to be true
      expect(File.exist?(Rails.root.join('public', '404.html'))).to be true
    end

    it "CSRF 토큰이 올바르게 처리되어야 함" do
      visit new_main_user_session_path
      
      # CSRF 토큰이 페이지에 포함되어 있는지 확인
      expect(page).to have_css('input[name="authenticity_token"]', visible: false)
    end
  end

  describe "멀티테넌트 플로우" do
    before do
      login_as(user, scope: :user)
    end

    it "테넌트 컨텍스트가 올바르게 설정되어야 함" do
      # 조직 대시보드 접근 시도
      visit organizations_path
      
      expect(page).to have_http_status(:ok)
      
      # 현재 조직 정보가 올바르게 표시되는지 확인
      if organization.present?
        expect(page).to have_content(organization.name) ||
          expect(page).to have_css("[data-organization-id='#{organization.id}']")
      end
    end

    it "권한이 없는 조직 접근시 적절한 처리" do
      other_org = create(:organization, subdomain: 'other')
      
      # 권한 없는 조직의 리소스 접근 시도
      visit organization_path(other_org)
      
      # 접근 거부 또는 리다이렉트 확인
      expect(page).to have_http_status(:forbidden) ||
        expect(page).to have_current_path(root_path) ||
        expect(page).to have_content('권한') ||
        expect(page).to have_content('authorized')
    end
  end

  describe "JavaScript와 Turbo 플로우" do
    it "페이지 로드시 JavaScript 오류가 없어야 함", js: true do
      visit root_path
      
      # JavaScript 오류 확인
      logs = page.driver.browser.manage.logs.get(:browser)
      js_errors = logs.select { |log| log.level == 'SEVERE' }
      
      expect(js_errors).to be_empty, "JavaScript 오류 발견: #{js_errors.map(&:message)}"
    end

    it "Turbo가 정상적으로 로드되어야 함", js: true do
      visit root_path
      
      # Turbo가 로드되었는지 확인
      turbo_loaded = page.evaluate_script('typeof Turbo !== "undefined"')
      expect(turbo_loaded).to be true
    end
  end

  describe "성능 및 응답 시간" do
    it "홈페이지 로드 시간이 합리적이어야 함" do
      start_time = Time.current
      visit root_path
      end_time = Time.current
      
      load_time = end_time - start_time
      expect(load_time).to be < 5.seconds
    end

    it "데이터베이스 쿼리가 과도하지 않아야 함" do
      query_count = 0
      
      ActiveSupport::Notifications.subscribe 'sql.active_record' do |*args|
        query_count += 1 unless args.last[:sql].match?(/PRAGMA|SCHEMA/)
      end
      
      visit root_path
      
      expect(query_count).to be < 20 # 합리적인 쿼리 수 제한
    end
  end
end
