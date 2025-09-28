require 'test_helper'
require 'playwright'

class LayoutE2ETest < ActionDispatch::IntegrationTest
  def setup
    @playwright = Playwright.create(playwright_cli_executable_path: 'npx playwright')
    @browser = @playwright.chromium.launch(headless: ENV['HEADLESS'] != 'false')
    @context = @browser.new_context
    @page = @context.new_page
    @base_url = "http://localhost:3000"
  end

  def teardown
    @context.close
    @browser.close
    @playwright.stop
  end

  test "landing page uses public layout" do
    # 랜딩 페이지 방문
    @page.goto(@base_url)
    
    # public 레이아웃이 적용되었는지 확인
    assert @page.locator('#layout-public').visible?, "Public layout should be visible"
    assert_equal 'public', @page.locator('body').get_attribute('data-layout'), "Should use public layout"
    
    # public 레이아웃의 특징적인 요소들 확인
    assert @page.locator('nav').visible?, "Navigation should be visible in public layout"
    assert @page.locator('footer').visible?, "Footer should be visible in public layout"
    
    # 회원가입 버튼이 있는지 확인
    assert @page.locator('text=무료로 시작하기').visible?, "Sign up button should be visible"
  end

  test "login page uses auth layout" do
    # 로그인 페이지 방문
    @page.goto("#{@base_url}/users/login")
    
    # auth 레이아웃이 적용되었는지 확인
    assert @page.locator('#layout-auth').visible?, "Auth layout should be visible"
    assert_equal 'auth', @page.locator('body').get_attribute('data-layout'), "Should use auth layout"
    
    # auth 레이아웃의 특징적인 요소들 확인
    assert @page.locator('.bg-white.shadow').visible?, "Login form container should be visible"
    
    # navigation과 footer가 없는지 확인
    assert_not @page.locator('nav').visible?, "Navigation should not be visible in auth layout"
    assert_not @page.locator('footer').visible?, "Footer should not be visible in auth layout"
  end

  test "registration page uses auth layout" do
    # 회원가입 페이지 방문
    @page.goto("#{@base_url}/users/register")
    
    # auth 레이아웃이 적용되었는지 확인
    assert @page.locator('#layout-auth').visible?, "Auth layout should be visible"
    assert_equal 'auth', @page.locator('body').get_attribute('data-layout'), "Should use auth layout"
    
    # auth 레이아웃의 특징적인 요소들 확인
    assert @page.locator('.bg-white.shadow').visible?, "Registration form container should be visible"
    
    # navigation과 footer가 없는지 확인
    assert_not @page.locator('nav').visible?, "Navigation should not be visible in auth layout"
    assert_not @page.locator('footer').visible?, "Footer should not be visible in auth layout"
  end

  test "navigation links work correctly" do
    # 랜딩 페이지 방문
    @page.goto(@base_url)
    
    # 로그인 링크 클릭
    @page.click('text=로그인')
    @page.wait_for_url("**/users/login")
    assert @page.locator('#layout-auth').visible?, "Should navigate to login with auth layout"
    
    # 로고 클릭하여 홈으로 돌아가기
    @page.click('text=Creatia')
    @page.wait_for_url(@base_url)
    assert @page.locator('#layout-public').visible?, "Should navigate back to home with public layout"
    
    # 회원가입 링크 클릭
    @page.click('text=회원가입')
    @page.wait_for_url("**/users/register")
    assert @page.locator('#layout-auth').visible?, "Should navigate to registration with auth layout"
  end

  test "all pages load without errors" do
    pages_to_test = [
      { url: @base_url, layout: 'public', description: 'Landing page' },
      { url: "#{@base_url}/users/login", layout: 'auth', description: 'Login page' },
      { url: "#{@base_url}/users/register", layout: 'auth', description: 'Registration page' },
      { url: "#{@base_url}/users/password/new", layout: 'auth', description: 'Password reset page' }
    ]
    
    pages_to_test.each do |page_info|
      @page.goto(page_info[:url])
      
      # 페이지가 로드되었는지 확인
      assert @page.locator("body[data-layout='#{page_info[:layout]}']").visible?, 
             "#{page_info[:description]} should load with #{page_info[:layout]} layout"
      
      # JavaScript 에러가 없는지 확인
      console_errors = []
      @page.on('console', ->(msg) { console_errors << msg if msg.type == 'error' })
      
      # 약간의 대기 시간을 주어 모든 스크립트가 실행되도록 함
      @page.wait_for_timeout(500)
      
      assert console_errors.empty?, 
             "#{page_info[:description]} should not have console errors: #{console_errors.join(', ')}"
    end
  end

  test "responsive design works on mobile" do
    # 모바일 뷰포트 설정
    @page.set_viewport_size(width: 375, height: 667)
    
    # 랜딩 페이지 테스트
    @page.goto(@base_url)
    assert @page.locator('#layout-public').visible?, "Public layout should be visible on mobile"
    
    # 로그인 페이지 테스트
    @page.goto("#{@base_url}/users/login")
    assert @page.locator('#layout-auth').visible?, "Auth layout should be visible on mobile"
    assert @page.locator('.bg-white.shadow').visible?, "Login form should be visible on mobile"
  end
end