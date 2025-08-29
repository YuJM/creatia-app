import { test, expect } from '@playwright/test';
import { AuthHelper } from './helpers/auth.helper';
import { ApiAuthHelper } from './helpers/api-auth.helper';

/**
 * 인증 플로우 상세 테스트
 * 각 인증 단계를 개별적으로 검증
 */
test.describe('인증 플로우 상세 테스트', () => {
  test.describe('1. 로그인 페이지 접근성', () => {
    test('auth 서브도메인 로그인 페이지 접근', async ({ page }) => {
      await page.goto('http://auth.creatia.local:3000/login');
      
      // 페이지 로드 확인
      await expect(page).toHaveURL(/auth\.creatia\.local.*\/login/);
      
      // 로그인 폼 요소 확인
      await expect(page.locator('input[name="user[email]"]')).toBeVisible();
      await expect(page.locator('input[name="user[password]"]')).toBeVisible();
      await expect(page.locator('input[type="submit"][value="로그인"], button[type="submit"]')).toBeVisible();
    });
    
    test('다른 서브도메인에서 로그인 페이지로 리다이렉트', async ({ page }) => {
      // 인증 없이 조직 페이지 접근 시도
      await page.goto('http://demo.creatia.local:3000/dashboard');
      
      // auth 서브도메인의 로그인 페이지로 리다이렉트되는지 확인
      await expect(page).toHaveURL(/auth\.creatia\.local.*\/login/);
      
      // return_to 파라미터 확인
      const url = new URL(page.url());
      expect(url.searchParams.has('return_to')).toBeTruthy();
    });
  });
  
  test.describe('2. 로그인 프로세스', () => {
    test('유효한 자격증명으로 로그인', async ({ page, context }) => {
      await page.goto('http://auth.creatia.local:3000/login');
      
      // 로그인 폼 작성
      await page.fill('input[name="user[email]"]', 'admin@creatia.local');
      await page.fill('input[name="user[password]"]', 'password123');
      
      // 로그인 버튼 클릭
      const submitButton = page.locator('input[type="submit"][value="로그인"], button[type="submit"]');
      await submitButton.first().click();
      
      // 로그인 성공 후 리다이렉트 대기
      await page.waitForURL(url => {
        const urlString = url.toString();
        return !urlString.includes('/login');
      }, { timeout: 10000 });
      
      // JWT 쿠키 확인
      const cookies = await context.cookies();
      const jwtToken = cookies.find(c => c.name === 'jwt_access_token');
      expect(jwtToken).toBeDefined();
      expect(jwtToken?.domain).toBe('.creatia.local');
    });
    
    test('잘못된 자격증명으로 로그인 실패', async ({ page }) => {
      await page.goto('http://auth.creatia.local:3000/login');
      
      // 잘못된 자격증명 입력
      await page.fill('input[type="email"]', 'admin@creatia.local');
      await page.fill('input[type="password"]', 'wrongpassword');
      
      // 로그인 시도
      const submitButton = page.locator('input[type="submit"][value="로그인"], button[type="submit"]');
      await submitButton.first().click();
      
      // 에러 메시지 확인 (로그인 페이지에 남아있음)
      await expect(page).toHaveURL(/login/);
      
      // 에러 메시지 표시 확인
      const errorMessage = page.locator('.alert-danger, .error, [role="alert"]');
      if (await errorMessage.count() > 0) {
        await expect(errorMessage.first()).toBeVisible();
      }
    });
  });
  
  test.describe('3. JWT 토큰 관리', () => {
    test('JWT 토큰이 모든 서브도메인에서 유효', async ({ browser }) => {
      const context = await browser.newContext();
      const page = await context.newPage();
      
      // 로그인
      const cookies = await AuthHelper.loginWithSession(page, context, 'admin@creatia.local');
      
      // JWT 토큰 확인
      const jwtToken = cookies.find(c => c.name === 'jwt_access_token');
      expect(jwtToken).toBeDefined();
      expect(jwtToken?.domain).toBe('.creatia.local');
      
      // 다른 서브도메인에서도 쿠키가 전송되는지 확인
      const demoPage = await context.newPage();
      await demoPage.goto('http://demo.creatia.local:3000');
      const demoCookies = await context.cookies('http://demo.creatia.local:3000');
      const demoJwtToken = demoCookies.find(c => c.name === 'jwt_access_token');
      expect(demoJwtToken).toBeDefined();
      
      await context.close();
    });
    
    test('JWT 토큰 만료 처리', async ({ context, page }) => {
      // 모든 쿠키 삭제 (토큰 만료 시뮬레이션)
      await context.clearCookies();
      
      // 보호된 페이지 접근 시도
      await page.goto('http://demo.creatia.local:3000/dashboard');
      
      // 로그인 페이지로 리다이렉트
      await expect(page).toHaveURL(/login/);
    });
  });
  
  test.describe('4. 조직 접근 권한', () => {
    test('권한이 있는 조직 접근', async ({ browser }) => {
      const context = await browser.newContext();
      const page = await context.newPage();
      
      // admin 계정으로 로그인 (demo 조직 소유자)
      await AuthHelper.loginWithSession(page, context, 'admin@creatia.local');
      await AuthHelper.restoreSession(context, await context.cookies());
      
      // demo 조직 접근
      await page.goto('http://demo.creatia.local:3000/dashboard');
      
      // 성공적으로 접근되는지 확인
      const currentUrl = page.url();
      expect(currentUrl).toContain('demo.creatia.local');
      expect(currentUrl).not.toContain('login');
      
      await context.close();
    });
    
    test('권한이 없는 조직 접근 차단', async ({ browser }) => {
      const context = await browser.newContext();
      const page = await context.newPage();
      
      // jane 계정으로 로그인 (test 조직 권한 없음)
      await AuthHelper.loginWithSession(page, context, 'jane@creatia.local');
      await AuthHelper.restoreSession(context, await context.cookies());
      
      // test 조직 접근 시도
      await page.goto('http://test.creatia.local:3000/dashboard');
      
      // 접근 거부 또는 로그인 페이지로 리다이렉트
      const currentUrl = page.url();
      expect(currentUrl).toMatch(/login|access_denied/);
      
      await context.close();
    });
  });
  
  test.describe('5. API 인증', () => {
    test('API를 통한 직접 로그인', async ({ browser }) => {
      const context = await browser.newContext();
      
      // API 로그인
      const { cookies, token } = await ApiAuthHelper.loginViaAPI(
        context,
        'admin@creatia.local',
        'password123'
      );
      
      // JWT 토큰 확인
      expect(token).toBeDefined();
      expect(cookies.length).toBeGreaterThan(0);
      
      // 쿠키 설정 후 페이지 접근
      await context.addCookies(cookies);
      const page = await context.newPage();
      await page.goto('http://demo.creatia.local:3000/dashboard');
      
      // 인증된 상태로 접근 가능한지 확인
      const currentUrl = page.url();
      expect(currentUrl).not.toContain('login');
      
      await context.close();
    });
    
    test('API를 통한 현재 사용자 정보 확인', async ({ browser }) => {
      const context = await browser.newContext();
      
      // API 로그인
      await ApiAuthHelper.setAuthCookies(context, 'admin@creatia.local');
      
      // 현재 사용자 정보 확인
      const user = await ApiAuthHelper.getCurrentUser(context.request);
      
      expect(user).toBeDefined();
      expect(user?.email).toBe('admin@creatia.local');
      
      await context.close();
    });
  });
  
  test.describe('6. 로그아웃', () => {
    test('로그아웃 후 세션 종료', async ({ browser }) => {
      const context = await browser.newContext();
      const page = await context.newPage();
      
      // 로그인
      await AuthHelper.loginWithSession(page, context, 'admin@creatia.local');
      
      // 로그아웃
      await page.goto('http://demo.creatia.local:3000');
      const logoutLink = page.locator('a[href*="logout"], a[href*="sign_out"]');
      if (await logoutLink.count() > 0) {
        await logoutLink.first().click();
        
        // 로그아웃 후 메인 페이지로 리다이렉트
        await expect(page).toHaveURL(/creatia\.local/);
        
        // 쿠키가 삭제되었는지 확인
        const cookies = await context.cookies();
        const jwtToken = cookies.find(c => c.name === 'jwt_access_token');
        expect(jwtToken).toBeUndefined();
      }
      
      await context.close();
    });
  });
});