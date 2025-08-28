require 'rails_helper'

RSpec.describe 'Authentication Flow', type: :system, js: true do
  let(:user) { create(:user, email: 'test@example.com', password: 'password123') }
  let(:organization) { create(:organization, subdomain: 'testorg', display_name: 'Test Organization') }
  let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'admin') }

  before do
    # Capybara 설정
    Capybara.app_host = 'http://creatia.local:3000'
    Capybara.always_include_port = true
    
    # 테스트 환경에서 cross-origin 허용
    Rails.application.config.action_controller.forgery_protection_origin_check = false
  end

  describe '로그인 플로우' do
    it '조직 서브도메인에서 로그인 페이지로 리다이렉트되고 로그인 후 다시 돌아온다' do
      # 1. 조직 서브도메인 접근 시도
      visit 'http://testorg.creatia.local:3000/dashboard'
      
      # 2. auth 서브도메인의 로그인 페이지로 리다이렉트 확인
      expect(page.current_host).to include('auth.creatia.local')
      expect(page).to have_current_path('/login?return_to=testorg')
      
      # 3. 로그인 페이지 UI 확인
      expect(page).to have_css('h2', text: 'Welcome to Creatia')
      expect(page).to have_field('user[email]')
      expect(page).to have_field('user[password]')
      expect(page).to have_button('로그인')
      
      # 4. 로그인 수행
      fill_in 'user[email]', with: 'test@example.com'
      fill_in 'user[password]', with: 'password123'
      click_button '로그인'
      
      # 5. 원래 요청한 조직의 대시보드로 리다이렉트 확인
      expect(page.current_host).to include('testorg.creatia.local')
      expect(page).to have_current_path('/dashboard')
      
      # 6. 대시보드 콘텐츠 확인
      expect(page).to have_content('Test Organization')
    end

    it '여러 조직에 속한 사용자는 조직 선택 페이지를 본다' do
      # 두 번째 조직 추가
      org2 = create(:organization, subdomain: 'testorg2', display_name: 'Second Organization')
      create(:organization_membership, user: user, organization: org2, role: 'member')
      
      # 1. auth 서브도메인의 로그인 페이지 접근
      visit 'http://auth.creatia.local:3000/login'
      
      # 2. 로그인
      fill_in 'user[email]', with: 'test@example.com'
      fill_in 'user[password]', with: 'password123'
      click_button '로그인'
      
      # 3. 조직 선택 페이지 표시 확인
      expect(page).to have_current_path('/organization_selection')
      expect(page).to have_content('Test Organization')
      expect(page).to have_content('Second Organization')
      
      # 4. 조직 선택
      click_on 'Test Organization'
      
      # 5. 선택한 조직의 대시보드로 이동 확인
      expect(page.current_host).to include('testorg.creatia.local')
      expect(page).to have_current_path('/dashboard')
    end

    it '단일 조직 사용자는 바로 대시보드로 이동한다' do
      # 1. auth 서브도메인의 로그인 페이지 접근
      visit 'http://auth.creatia.local:3000/login'
      
      # 2. 로그인
      fill_in 'user[email]', with: 'test@example.com'
      fill_in 'user[password]', with: 'password123'
      click_button '로그인'
      
      # 3. 바로 조직 대시보드로 이동 확인
      expect(page.current_host).to include('testorg.creatia.local')
      expect(page).to have_current_path('/dashboard')
    end

    it '권한이 없는 조직 접근 시 접근 거부 페이지를 표시한다' do
      # 1. auth 서브도메인의 로그인 페이지에서 권한 없는 조직으로 시도
      visit 'http://auth.creatia.local:3000/login?return_to=unauthorized'
      
      # 2. 로그인
      fill_in 'user[email]', with: 'test@example.com'
      fill_in 'user[password]', with: 'password123'
      click_button '로그인'
      
      # 3. 접근 거부 페이지 확인
      expect(page).to have_current_path('/access_denied?org=unauthorized')
      expect(page).to have_content('접근 권한이 없습니다')
    end

    it '로그아웃 후 메인 페이지로 리다이렉트된다' do
      # 로그인 상태 생성
      sign_in user
      
      # 1. 조직 대시보드 방문
      visit 'http://testorg.creatia.local:3000/dashboard'
      
      # 2. 로그아웃
      click_on '로그아웃'
      
      # 3. 메인 페이지로 리다이렉트 확인
      expect(page.current_host).to include('creatia.local')
      expect(page.current_host).not_to include('testorg')
      expect(page).to have_current_path('/')
    end
  end

  describe '크로스 도메인 보안' do
    it 'allow_other_host 파라미터로 크로스 도메인 리다이렉트가 허용된다' do
      # 1. 로그인
      visit 'http://auth.creatia.local:3000/login'
      fill_in 'user[email]', with: 'test@example.com'
      fill_in 'user[password]', with: 'password123'
      
      # 2. 로그인 버튼 클릭 후 리다이렉트 에러 없이 이동 확인
      expect { click_button '로그인' }.not_to raise_error
      
      # 3. 정상적으로 조직 서브도메인으로 이동
      expect(page.current_host).to include('testorg.creatia.local')
    end

    it '세션 타임아웃 시 auth 도메인으로 리다이렉트된다' do
      # 로그인 상태 생성
      sign_in user
      
      # 1. 조직 대시보드 방문
      visit 'http://testorg.creatia.local:3000/dashboard'
      expect(page).to have_content('Test Organization')
      
      # 2. 세션 만료 시뮬레이션
      page.driver.browser.manage.delete_all_cookies
      
      # 3. 페이지 새로고침
      visit 'http://testorg.creatia.local:3000/dashboard'
      
      # 4. auth 도메인 로그인 페이지로 리다이렉트 확인
      expect(page.current_host).to include('auth.creatia.local')
      expect(page).to have_current_path('/login?return_to=testorg')
    end
  end

  describe '데모 계정' do
    it '데모 계정 정보가 로그인 페이지에 표시된다' do
      visit 'http://auth.creatia.local:3000/login'
      
      # 데모 계정 정보 카드 확인
      within('.bg-blue-50') do
        expect(page).to have_content('데모 계정')
        expect(page).to have_content('Email: admin@creatia.local')
        expect(page).to have_content('Password: password123')
      end
    end
  end
end