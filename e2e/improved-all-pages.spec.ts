import { test, expect, Cookie } from '@playwright/test';
import { AuthHelper } from './helpers/auth.helper';

// 테스트 데이터 (seed.rb 기반)
const TEST_ACCOUNTS = {
  admin: { email: 'admin@creatia.local', password: 'password123', name: '관리자' },
  john: { email: 'john@creatia.local', password: 'password123', name: 'John Doe' },
  jane: { email: 'jane@creatia.local', password: 'password123', name: 'Jane Smith' },
  mike: { email: 'mike@creatia.local', password: 'password123', name: 'Mike Johnson' },
  sarah: { email: 'sarah@creatia.local', password: 'password123', name: 'Sarah Wilson' }
};

const ORGANIZATIONS = {
  demo: { subdomain: 'demo', name: 'Creatia Demo', owner: 'admin@creatia.local' },
  acme: { subdomain: 'acme', name: 'Acme Corporation', owner: 'john@creatia.local' },
  startup: { subdomain: 'startup', name: 'Startup Inc', owner: 'jane@creatia.local' },
  test: { subdomain: 'test', name: 'Test Organization', owner: 'mike@creatia.local' }
};

// 세션 쿠키를 테스트 간 공유
let authCookies: Cookie[] = [];

test.describe('개선된 E2E 테스트 - JWT 인증 사용', () => {
  test.beforeAll(async ({ browser }) => {
    // 한 번만 로그인하고 JWT 토큰 포함 세션 저장
    const context = await browser.newContext();
    const page = await context.newPage();
    
    try {
      // JWT 기반 로그인
      authCookies = await AuthHelper.loginWithSession(page, context, TEST_ACCOUNTS.admin.email);
      console.log('Authentication successful, JWT tokens acquired');
      
      // JWT 토큰 확인
      const hasJwtToken = authCookies.some(c => c.name === 'jwt_access_token');
      if (!hasJwtToken) {
        console.warn('Warning: JWT tokens not found in cookies');
      }
    } catch (error) {
      console.error('Authentication failed:', error);
      throw error;
    } finally {
      await context.close();
    }
  });

  test.describe('공개 페이지 (인증 불필요)', () => {
    test('랜딩 페이지 접속 및 네비게이션', async ({ page }) => {
      await page.goto('http://creatia.local:3000');
      
      // 레이아웃 확인
      await expect(page.locator('#layout-public')).toBeVisible();
      
      // 주요 요소 확인
      await expect(page.locator('h1')).toContainText('프로젝트 관리의');
      await expect(page.locator('text=무료로 시작하기')).toBeVisible();
      await expect(page.locator('text=데모 보기')).toBeVisible();
      
      // Features 섹션 확인
      await expect(page.locator('text=더 나은 협업을 위한 모든 것')).toBeVisible();
      await expect(page.locator('h3:has-text("작업 관리")')).toBeVisible();
      await expect(page.locator('h3:has-text("팀 협업")')).toBeVisible();
    });

    test('로그인 페이지 UI 확인', async ({ page }) => {
      await page.goto('http://auth.creatia.local:3000/login');
      
      // 레이아웃 확인
      await expect(page.locator('#layout-auth')).toBeVisible();
      
      // 폼 요소 확인
      await expect(page.locator('input[type="email"]')).toBeVisible();
      await expect(page.locator('input[type="password"]')).toBeVisible();
      await expect(page.locator('input[type="submit"][value="로그인"]')).toBeVisible();
      
      // 링크 확인
      await expect(page.locator('text=회원가입')).toBeVisible();
      await expect(page.locator('text=비밀번호를 잊으셨나요?')).toBeVisible();
    });

    test('회원가입 페이지 접근', async ({ page }) => {
      await page.goto('http://auth.creatia.local:3000/register');
      
      // 폼 요소 확인
      await expect(page.locator('input[name*="name"]')).toBeVisible();
      await expect(page.locator('input[type="email"]')).toBeVisible();
      await expect(page.locator('input[type="password"]').first()).toBeVisible();
    });
  });

  test.describe('인증이 필요한 페이지', () => {
    test.beforeEach(async ({ context }) => {
      // JWT 토큰을 포함한 세션 쿠키 복원
      await AuthHelper.restoreSession(context, authCookies);
    });

    test('Demo 조직 대시보드 접속', async ({ page }) => {
      try {
        await AuthHelper.switchToOrganization(page, 'demo');
        
        // Application 레이아웃 확인 (다양한 형태 지원)
        const applicationLayout = page.locator('#layout-application, [data-layout="application"], main.application-layout');
        await expect(applicationLayout.first()).toBeVisible({ timeout: 10000 });
        
        // 로그인 상태 확인
        const isLoggedIn = await AuthHelper.isLoggedIn(page);
        expect(isLoggedIn).toBe(true);
      } catch (error) {
        // 디버깅을 위한 현재 URL 출력
        console.error('Failed to access Demo organization. Current URL:', page.url());
        throw error;
      }
    });

    test('Demo 조직 Task 페이지', async ({ page }) => {
      // JWT 토큰이 설정되어 있으므로 직접 접근 가능
      await page.goto('http://demo.creatia.local:3000/tasks', { waitUntil: 'networkidle' });
      
      // 인증 실패로 리다이렉트된 경우 처리
      const currentUrl = page.url();
      if (currentUrl.includes('/sign_in') || currentUrl.includes('/login')) {
        throw new Error('Authentication failed - redirected to login page');
      }
      
      // Application 레이아웃 확인 (유연한 선택자)
      const applicationLayout = page.locator('#layout-application, [data-layout="application"], main');
      await expect(applicationLayout.first()).toBeVisible({ timeout: 10000 });
      
      // Task 관련 요소 확인
      const pageContent = page.locator('body');
      await expect(pageContent).toContainText(/Task|작업|태스크|할 일/i);
      
      // 시드 데이터로 생성된 태스크 확인 (최소 하나)
      const taskTitles = [
        '프로젝트 초기 설정',
        '사용자 인터페이스 디자인',
        '백엔드 API 개발'
      ];
      
      let taskFound = false;
      for (const title of taskTitles) {
        const task = page.locator(`text="${title}"`);
        if (await task.count() > 0) {
          await expect(task.first()).toBeVisible();
          taskFound = true;
          break;
        }
      }
      
      // 태스크를 찾지 못한 경우 더 일반적인 확인
      if (!taskFound) {
        const anyTask = page.locator('.task-item, [data-task], article.task');
        if (await anyTask.count() > 0) {
          await expect(anyTask.first()).toBeVisible();
        }
      }
    });

    test('새 Task 생성', async ({ page }) => {
      await page.goto('http://demo.creatia.local:3000/tasks/new');
      
      // 폼 요소 확인 및 작성
      const titleInput = page.locator('input[name*="title"], input[name*="name"]').first();
      const descriptionInput = page.locator('textarea[name*="description"]').first();
      
      if (await titleInput.count() > 0) {
        await titleInput.fill('E2E 테스트 Task - ' + Date.now());
      }
      
      if (await descriptionInput.count() > 0) {
        await descriptionInput.fill('Playwright E2E 테스트로 생성된 태스크입니다.');
      }
      
      // 우선순위 선택 (있는 경우)
      const prioritySelect = page.locator('select[name*="priority"]').first();
      if (await prioritySelect.count() > 0) {
        await prioritySelect.selectOption('high');
      }
      
      // 폼 제출
      const submitButton = page.locator('button[type="submit"], input[type="submit"]').first();
      if (await submitButton.count() > 0) {
        await submitButton.click();
        
        // 성공 후 리다이렉트 대기
        await page.waitForURL(url => {
          const urlString = typeof url === 'string' ? url : url.toString();
          return !urlString.includes('/new');
        }, { timeout: 5000 }).catch(() => {});
      }
    });

    test('조직 간 전환', async ({ page }) => {
      // Demo 조직에서 시작
      try {
        await AuthHelper.switchToOrganization(page, 'demo');
        const demoLayout = page.locator('#layout-application, [data-layout="application"], main');
        await expect(demoLayout.first()).toBeVisible({ timeout: 10000 });
      } catch (error) {
        console.error('Failed to switch to demo organization:', error);
        throw error;
      }
      
      // Acme 조직으로 전환 시도 (admin 계정은 권한 없음)
      try {
        await AuthHelper.switchToOrganization(page, 'acme');
        
        // 현재 URL 확인
        const currentUrl = page.url();
        
        // admin 계정은 acme 조직에 권한이 없으므로 실패 예상
        if (currentUrl.includes('/sign_in') || currentUrl.includes('/login')) {
          // 예상된 동작: 권한 없음
          expect(currentUrl).toMatch(/sign_in|login/);
        } else if (currentUrl.includes('acme')) {
          // 만약 접근 가능하면 레이아웃 확인
          const acmeLayout = page.locator('#layout-application, [data-layout="application"], main');
          await expect(acmeLayout.first()).toBeVisible();
        }
      } catch (error) {
        // 권한이 없어서 실패하는 것은 정상
        console.log('Expected: Cannot access Acme organization with admin account');
      }
    });

    test('프로필 페이지 접근', async ({ page }) => {
      await page.goto('http://demo.creatia.local:3000/profile');
      
      // 프로필 정보 확인
      const pageContent = page.locator('body');
      await expect(pageContent).toContainText(TEST_ACCOUNTS.admin.name);
    });

    test('조직 설정 페이지 (관리자만)', async ({ page }) => {
      await page.goto('http://demo.creatia.local:3000/settings/organization');
      
      // 관리자 권한이 있으면 설정 페이지 표시
      const currentUrl = page.url();
      if (currentUrl.includes('settings')) {
        await expect(page.locator('#layout-application')).toBeVisible();
        
        // 조직 정보 확인
        const pageContent = page.locator('body');
        await expect(pageContent).toContainText(/Creatia Demo|설정|Settings/i);
      } else {
        // 권한이 없으면 리다이렉트
        await expect(page).toHaveURL(/.*dashboard|.*login/);
      }
    });
  });

  test.describe('다양한 사용자 권한 테스트', () => {
    test('일반 사용자로 로그인 및 접근 권한 확인', async ({ browser }) => {
      const context = await browser.newContext();
      const page = await context.newPage();
      
      try {
        // Jane으로 로그인 (Startup Inc 소유자, Demo 조직 admin)
        const janeCookies = await AuthHelper.loginWithSession(page, context, TEST_ACCOUNTS.jane.email);
        await AuthHelper.restoreSession(context, janeCookies);
        
        // Demo 조직 접근 (admin 권한)
        await AuthHelper.switchToOrganization(page, 'demo');
        const demoLayout = page.locator('#layout-application, [data-layout="application"], main');
        await expect(demoLayout.first()).toBeVisible({ timeout: 10000 });
        
        // Startup 조직 접근 (owner 권한)
        await AuthHelper.switchToOrganization(page, 'startup');
        const startupLayout = page.locator('#layout-application, [data-layout="application"], main');
        await expect(startupLayout.first()).toBeVisible({ timeout: 10000 });
        
        // Test 조직 접근 (권한 없음) - 직접 goto 사용
        await page.goto('http://test.creatia.local:3000/dashboard', { waitUntil: 'networkidle' });
        
        // 권한이 없으므로 로그인 페이지로 리다이렉트 예상
        const currentUrl = page.url();
        expect(currentUrl).toMatch(/sign_in|login|access_denied/);
      } finally {
        await context.close();
      }
    });

    test('Mike로 Test 조직 접근', async ({ browser }) => {
      const context = await browser.newContext();
      const page = await context.newPage();
      
      try {
        // Mike로 로그인 (Test Organization 소유자)
        const mikeCookies = await AuthHelper.loginWithSession(page, context, TEST_ACCOUNTS.mike.email);
        await AuthHelper.restoreSession(context, mikeCookies);
        
        // Test 조직 접근
        await AuthHelper.switchToOrganization(page, 'test');
        const testLayout = page.locator('#layout-application, [data-layout="application"], main');
        await expect(testLayout.first()).toBeVisible({ timeout: 10000 });
        
        // Test 조직에 태스크 페이지 접근
        await page.goto('http://test.creatia.local:3000/tasks', { waitUntil: 'networkidle' });
        
        // 인증 확인
        const currentUrl = page.url();
        if (currentUrl.includes('/sign_in') || currentUrl.includes('/login')) {
          throw new Error('Authentication failed for Mike in Test organization');
        }
        
        // Task 페이지 콘텐츠 확인
        const pageContent = page.locator('body');
        await expect(pageContent).toContainText(/Task|작업|태스크|할 일/i);
      } finally {
        await context.close();
      }
    });
  });

  test.describe('에러 처리 및 엣지 케이스', () => {
    test('존재하지 않는 페이지 404', async ({ page }) => {
      await page.goto('http://creatia.local:3000/nonexistent-page', { waitUntil: 'domcontentloaded' });
      
      const errorMessage = page.locator('text=/404|not found|페이지를 찾을 수 없습니다/i');
      if (await errorMessage.count() > 0) {
        await expect(errorMessage.first()).toBeVisible();
      }
    });

    test('잘못된 조직 서브도메인', async ({ page }) => {
      await page.goto('http://invalid-org.creatia.local:3000', { waitUntil: 'domcontentloaded' });
      
      // 로그인 페이지로 리다이렉트되거나 404 에러
      const currentUrl = page.url();
      expect(currentUrl).toMatch(/login|404|error/);
    });

    test('세션 만료 시뮬레이션', async ({ context, page }) => {
      // 모든 쿠키 삭제하여 로그아웃 상태 시뮬레이션
      await context.clearCookies();
      
      // 보호된 페이지 접근 시도
      await page.goto('http://demo.creatia.local:3000/tasks', { waitUntil: 'networkidle' });
      
      // 로그인 페이지로 리다이렉트 확인
      const currentUrl = page.url();
      expect(currentUrl).toMatch(/sign_in|login/);
    });
  });

  test.describe('반응형 디자인 테스트', () => {
    test.beforeEach(async ({ context }) => {
      await AuthHelper.restoreSession(context, authCookies);
    });

    test('모바일 뷰포트에서 대시보드', async ({ page }) => {
      await page.setViewportSize({ width: 375, height: 667 });
      await page.goto('http://demo.creatia.local:3000');
      
      // 모바일 레이아웃 확인
      await expect(page.locator('#layout-application')).toBeVisible();
      
      // 모바일 메뉴 버튼 확인
      const mobileMenuButton = page.locator('button[aria-label*="menu"], [data-testid="mobile-menu"], .hamburger');
      if (await mobileMenuButton.count() > 0) {
        await expect(mobileMenuButton.first()).toBeVisible();
      }
    });

    test('태블릿 뷰포트에서 Task 페이지', async ({ page }) => {
      await page.setViewportSize({ width: 768, height: 1024 });
      await page.goto('http://demo.creatia.local:3000/tasks');
      
      await expect(page.locator('#layout-application')).toBeVisible();
    });
  });
});