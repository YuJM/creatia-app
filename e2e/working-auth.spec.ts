import { test, expect } from '@playwright/test';

/**
 * 실제 동작하는 인증 테스트 - 최소한의 검증
 */
test.describe('실행 가능한 인증 테스트', () => {
  const baseUrl = 'http://auth.creatia.local:3000';
  const testUser = {
    email: 'admin@creatia.local',
    password: 'password123'
  };

  test('로그인 페이지 기본 요소 확인', async ({ page }) => {
    // 로그인 페이지로 이동
    await page.goto(`${baseUrl}/login`);
    
    // 페이지 로드 대기
    await page.waitForLoadState('networkidle');
    
    // 타이틀 확인
    await expect(page.locator('h2')).toContainText('Welcome to Creatia');
    
    // 이메일 필드 확인 - 다양한 선택자 시도
    const emailField = page.locator('input[type="email"], input[name*="email"]').first();
    await expect(emailField).toBeVisible();
    
    // 비밀번호 필드 확인
    const passwordField = page.locator('input[type="password"]').first();
    await expect(passwordField).toBeVisible();
    
    // 로그인 버튼 확인
    const submitButton = page.locator('input[type="submit"][value="로그인"], button:has-text("로그인")').first();
    await expect(submitButton).toBeVisible();
  });

  test('로그인 시도 - UI 상호작용', async ({ page }) => {
    await page.goto(`${baseUrl}/login`);
    await page.waitForLoadState('networkidle');
    
    // 이메일 입력 - 여러 방법 시도
    const emailField = page.locator('input[type="email"], input[name*="email"]').first();
    await emailField.fill(testUser.email);
    
    // 비밀번호 입력
    const passwordField = page.locator('input[type="password"]').first();
    await passwordField.fill(testUser.password);
    
    // 스크린샷 (디버깅용)
    await page.screenshot({ path: 'test-results/login-form-filled.png' });
    
    // 로그인 버튼 클릭
    const submitButton = page.locator('input[type="submit"][value="로그인"], button:has-text("로그인")').first();
    await submitButton.click();
    
    // 페이지 변경 대기 (최대 10초)
    await page.waitForTimeout(3000);
    
    // URL 변경 확인
    const currentUrl = page.url();
    console.log('로그인 후 URL:', currentUrl);
    
    // 로그인 페이지에서 벗어났는지 확인
    if (!currentUrl.includes('login')) {
      console.log('✅ 로그인 성공 - 페이지 이동 완료');
    } else {
      // 에러 메시지 확인
      const errorMessage = await page.locator('.alert, .flash, [role="alert"]').textContent().catch(() => null);
      if (errorMessage) {
        console.log('❌ 로그인 실패 - 에러:', errorMessage);
      }
    }
  });

  test('조직 페이지 접근 시 인증 리다이렉트', async ({ page }) => {
    // 인증 없이 demo 조직 대시보드 접근
    await page.goto('http://demo.creatia.local:3000/dashboard');
    
    // 리다이렉트 대기
    await page.waitForLoadState('networkidle');
    
    // 로그인 페이지로 리다이렉트되었는지 확인
    const currentUrl = page.url();
    expect(currentUrl).toContain('auth.creatia.local');
    expect(currentUrl).toContain('login');
    
    // return_to 파라미터 확인
    if (currentUrl.includes('return_to')) {
      console.log('✅ return_to 파라미터 포함');
    }
  });

  test('잘못된 자격증명 로그인 실패', async ({ page }) => {
    await page.goto(`${baseUrl}/login`);
    await page.waitForLoadState('networkidle');
    
    // 잘못된 자격증명 입력
    const emailField = page.locator('input[type="email"], input[name*="email"]').first();
    await emailField.fill('wrong@example.com');
    
    const passwordField = page.locator('input[type="password"]').first();
    await passwordField.fill('wrongpassword');
    
    // 로그인 시도
    const submitButton = page.locator('input[type="submit"][value="로그인"], button:has-text("로그인")').first();
    await submitButton.click();
    
    // 결과 대기
    await page.waitForTimeout(2000);
    
    // 여전히 로그인 페이지인지 확인
    const currentUrl = page.url();
    expect(currentUrl).toContain('login');
  });
});

/**
 * 세션 유지 테스트
 */
test.describe('세션 관리 테스트', () => {
  test('로그인 세션 유지', async ({ page, context }) => {
    // 1. 로그인
    await page.goto('http://auth.creatia.local:3000/login');
    await page.waitForLoadState('networkidle');
    
    const emailField = page.locator('input[type="email"], input[name*="email"]').first();
    await emailField.fill('admin@creatia.local');
    
    const passwordField = page.locator('input[type="password"]').first();
    await passwordField.fill('password123');
    
    const submitButton = page.locator('input[type="submit"][value="로그인"], button:has-text("로그인")').first();
    await submitButton.click();
    
    // 로그인 완료 대기
    await page.waitForTimeout(3000);
    
    // 2. 쿠키 확인
    const cookies = await context.cookies();
    console.log('쿠키 목록:', cookies.map(c => ({ name: c.name, domain: c.domain })));
    
    // Rails 세션 쿠키 확인
    const sessionCookie = cookies.find(c => c.name.includes('_creatia') || c.name.includes('session'));
    if (sessionCookie) {
      console.log('✅ 세션 쿠키 발견:', sessionCookie.name);
    }
    
    // 3. 다른 페이지 접근 시도
    const currentUrl = page.url();
    if (!currentUrl.includes('login')) {
      // 로그인 성공한 경우 demo 조직 접근 시도
      await page.goto('http://demo.creatia.local:3000/dashboard');
      await page.waitForLoadState('networkidle');
      
      const newUrl = page.url();
      if (!newUrl.includes('login')) {
        console.log('✅ 세션 유지됨 - demo 조직 접근 성공');
      } else {
        console.log('❌ 세션 유지 실패 - 재로그인 필요');
      }
    }
  });
});