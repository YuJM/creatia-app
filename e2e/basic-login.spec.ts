import { test, expect, Page, BrowserContext } from '@playwright/test';
import { testConfig } from './test-config';

/**
 * 기본 로그인 테스트 - 가장 단순한 형태로 동작 확인
 */
test.describe('기본 로그인 테스트', () => {
  test('로그인 페이지 접근 가능', async ({ page }) => {
    // auth 서브도메인의 로그인 페이지로 이동
    await page.goto(testConfig.urls.auth('login'));
    
    // 페이지 타이틀 확인
    await expect(page.locator('h2')).toContainText('Welcome to Creatia');
    
    // 로그인 폼 필드 확인
    await expect(page.locator(`input[name="${testConfig.formFields.email}"]`)).toBeVisible();
    await expect(page.locator(`input[name="${testConfig.formFields.password}"]`)).toBeVisible();
    
    // 데모 계정 정보 표시 확인
    await expect(page.locator('.bg-blue-50')).toBeVisible();
    await expect(page.locator(`text=${testConfig.testUsers.admin.email}`)).toBeVisible();
  });
  
  test('정상 로그인 수행', async ({ page, context }) => {
    // 로그인 페이지로 이동
    await page.goto(testConfig.urls.auth('login'));
    
    // 로그인 폼 작성
    await page.fill(`input[name="${testConfig.formFields.email}"]`, testConfig.testUsers.admin.email);
    await page.fill(`input[name="${testConfig.formFields.password}"]`, testConfig.testUsers.admin.password);
    
    // Remember Me 체크
    const rememberCheckbox = page.locator(`input[name="${testConfig.formFields.rememberMe}"]`);
    if (await rememberCheckbox.isVisible()) {
      await rememberCheckbox.check();
    }
    
    // 로그인 버튼 클릭
    await page.locator('input[type="submit"][value="로그인"]').click();
    
    // 로그인 성공 후 리다이렉트 대기
    await page.waitForURL(url => {
      const urlString = url.toString();
      // 조직 선택 페이지나 대시보드로 이동했는지 확인
      return urlString.includes('organization_selection') || 
             urlString.includes('dashboard') ||
             (!urlString.includes('login') && !urlString.includes('sign_in'));
    }, { timeout: testConfig.timeouts.waitForUrl });
    
    // 로그인 성공 확인
    const currentUrl = page.url();
    console.log('로그인 후 URL:', currentUrl);
    expect(currentUrl).not.toContain('login');
  });
  
  test('잘못된 자격증명으로 로그인 실패', async ({ page }) => {
    // 로그인 페이지로 이동
    await page.goto(testConfig.urls.auth('login'));
    
    // 잘못된 자격증명 입력
    await page.fill(`input[name="${testConfig.formFields.email}"]`, 'wrong@email.com');
    await page.fill(`input[name="${testConfig.formFields.password}"]`, 'wrongpassword');
    
    // 로그인 시도
    await page.locator('input[type="submit"][value="로그인"]').click();
    
    // 페이지가 로그인 페이지에 남아있는지 확인
    await page.waitForTimeout(2000);
    const currentUrl = page.url();
    expect(currentUrl).toContain('login');
    
    // 에러 메시지 확인 (Devise 기본 에러 메시지)
    const errorMessage = page.locator('.alert, .flash, [role="alert"]').first();
    if (await errorMessage.isVisible()) {
      expect(await errorMessage.textContent()).toBeTruthy();
    }
  });
  
  test('조직 페이지 접근 시 로그인으로 리다이렉트', async ({ page }) => {
    // 로그인하지 않은 상태에서 조직 대시보드 접근
    await page.goto(testConfig.urls.organization('demo', 'dashboard'));
    
    // auth 서브도메인의 로그인 페이지로 리다이렉트되는지 확인
    await page.waitForURL(/auth.*login/);
    
    // return_to 파라미터 확인
    const currentUrl = page.url();
    expect(currentUrl).toContain('return_to');
  });
});

/**
 * 로그인 후 조직 접근 테스트
 */
test.describe('조직 접근 테스트', () => {
  // 각 테스트 전에 로그인 수행
  async function loginAsAdmin(page: Page, context: BrowserContext) {
    await page.goto(testConfig.urls.auth('login'));
    await page.fill(`input[name="${testConfig.formFields.email}"]`, testConfig.testUsers.admin.email);
    await page.fill(`input[name="${testConfig.formFields.password}"]`, testConfig.testUsers.admin.password);
    await page.locator('input[type="submit"][value="로그인"]').click();
    
    // 로그인 완료 대기
    await page.waitForURL(url => !url.toString().includes('login'), { 
      timeout: testConfig.timeouts.waitForUrl 
    });
  }
  
  test('로그인 후 demo 조직 접근', async ({ page, context }) => {
    // 먼저 로그인
    await loginAsAdmin(page, context);
    
    // demo 조직으로 이동
    await page.goto(testConfig.urls.organization('demo', 'dashboard'));
    
    // 대시보드 페이지인지 확인
    const currentUrl = page.url();
    
    // 로그인 페이지로 리다이렉트되지 않았는지 확인
    if (currentUrl.includes('login')) {
      console.error('로그인 후에도 인증이 유지되지 않음');
      
      // 쿠키 확인
      const cookies = await context.cookies();
      console.log('현재 쿠키:', cookies.map(c => ({ name: c.name, domain: c.domain })));
    }
    
    // 대시보드 접근 성공 확인
    expect(currentUrl).not.toContain('login');
  });
});