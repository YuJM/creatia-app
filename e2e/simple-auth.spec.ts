import { test, expect } from '@playwright/test';

test.describe('기본 인증 테스트', () => {
  test('auth 서브도메인 로그인 페이지가 로드된다', async ({ page }) => {
    // auth 서브도메인 로그인 페이지 접근
    await page.goto('http://auth.creatia.local:3000/login');
    
    // 페이지가 로드되었는지 확인
    await expect(page.locator('h2')).toContainText('Welcome to Creatia');
    
    // 로그인 폼 요소들이 있는지 확인 (auth_user_user 프리픽스 포함)
    await expect(page.locator('input[name="auth_user_user[email]"]')).toBeVisible();
    await expect(page.locator('input[name="auth_user_user[password]"]')).toBeVisible();
    await expect(page.locator('input[type="submit"][value="로그인"]')).toBeVisible();
    
    // 데모 계정 정보 표시 확인
    await expect(page.locator('.bg-blue-50')).toBeVisible();
    await expect(page.locator('text=admin@creatia.local')).toBeVisible();
  });

  test('데모 조직 대시보드 접근시 로그인 페이지로 리다이렉트', async ({ page }) => {
    // 로그인하지 않은 상태에서 대시보드 접근
    await page.goto('http://demo.creatia.local:3000/dashboard');
    
    // auth 도메인으로 리다이렉트되는지 확인
    await page.waitForURL(/auth\.creatia\.local.*\/login/, { timeout: 10000 });
    
    // return_to 파라미터가 있는지 확인
    expect(page.url()).toContain('return_to=demo');
  });

  test('정상적인 로그인 시도 - SSO 토큰 기반 인증', async ({ page }) => {
    // SSO 토큰 기반 인증으로 크로스 도메인 문제 해결
    await page.goto('http://auth.creatia.local:3000/login');
    
    // 데모 계정으로 로그인
    await page.fill('input[name="auth_user_user[email]"]', 'admin@creatia.local');
    await page.fill('input[name="auth_user_user[password]"]', 'password123');
    
    // 로그인 버튼 클릭
    await page.locator('input[type="submit"][value="로그인"]').click();
    
    // 로그인 처리 대기
    await page.waitForLoadState('networkidle');
    
    // 성공적인 로그인 확인 - 조직 선택 페이지나 대시보드로 이동
    await page.waitForURL(url => {
      const urlString = url.toString();
      return urlString.includes('organization_selection') || 
             urlString.includes('dashboard') ||
             urlString === 'http://auth.creatia.local:3000/';
    }, { timeout: 10000 });
    
    const finalUrl = page.url();
    console.log('로그인 후 URL:', finalUrl);
    
    // SSO 토큰이 생성되었는지 확인 (쿠키 확인)
    const cookies = await page.context().cookies();
    const ssoToken = cookies.find(c => c.name === 'sso_token');
    
    // SSO 토큰이 있거나 로그인이 성공했는지 확인
    const isLoggedIn = finalUrl.includes('organization_selection') || 
                       finalUrl.includes('dashboard') ||
                       ssoToken !== undefined;
    
    expect(isLoggedIn).toBeTruthy();
  });

  test('잘못된 로그인 시도', async ({ page }) => {
    await page.goto('http://auth.creatia.local:3000/login');
    
    // 잘못된 자격 증명 입력 (auth_user_user 프리픽스 포함)
    await page.fill('input[name="auth_user_user[email]"]', 'wrong@email.com');
    await page.fill('input[name="auth_user_user[password]"]', 'wrongpassword');
    
    // 로그인 시도
    await page.locator('input[type="submit"][value="로그인"]').click();
    
    // 에러 메시지 또는 같은 페이지에 남아있는지 확인
    await page.waitForTimeout(2000);
    const url = page.url();
    expect(url).toContain('auth.creatia.local');
    expect(url).toContain('login');
  });
});