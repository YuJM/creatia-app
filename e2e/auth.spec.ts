import { test, expect, Page } from '@playwright/test';

// 테스트 데이터
const testUser = {
  email: 'admin@creatia.local',
  password: 'password123'
};

const demoOrg = {
  subdomain: 'demo',
  displayName: 'Demo Organization'
};

test.describe('인증 플로우 테스트', () => {
  test.beforeEach(async ({ page }) => {
    // Rails 서버와 Caddy가 준비될 때까지 대기
    await page.waitForTimeout(2000);
  });

  test.skip('조직 서브도메인에서 로그인 페이지로 리다이렉트되고 로그인 후 다시 돌아온다', async ({ page }) => {
    // 1. 조직 서브도메인 접근 시도 (포트 3000 직접 사용)
    await page.goto(`http://${demoOrg.subdomain}.creatia.local:3000/dashboard`);
    
    // 2. auth 서브도메인의 로그인 페이지로 리다이렉트 확인
    await expect(page).toHaveURL(/auth\.creatia\.local.*\/login/);
    await expect(page).toHaveURL(new RegExp(`return_to=${demoOrg.subdomain}`));
    
    // 3. 로그인 페이지 UI 확인
    await expect(page.locator('h2')).toContainText('Welcome to Creatia');
    await expect(page.locator('input[name="auth_user_user[email]"]')).toBeVisible();
    await expect(page.locator('input[name="auth_user_user[password]"]')).toBeVisible();
    await expect(page.locator('input[type="submit"][value="로그인"]')).toBeVisible();
    
    // 4. 로그인 수행
    await page.fill('input[name="auth_user_user[email]"]', testUser.email);
    await page.fill('input[name="auth_user_user[password]"]', testUser.password);
    await page.locator('input[type="submit"][value="로그인"]').click();
    
    // 5. 원래 요청한 조직의 대시보드로 리다이렉트 확인
    await page.waitForURL(`http://${demoOrg.subdomain}.creatia.local:3000/dashboard`);
    await expect(page).toHaveURL(`http://${demoOrg.subdomain}.creatia.local:3000/dashboard`);
    
    // 6. 대시보드 콘텐츠 확인
    await expect(page.locator('h1, h2')).toContainText(demoOrg.displayName);
  });

  test.skip('auth 서브도메인에서 직접 로그인하면 조직 선택 또는 대시보드로 이동', async ({ page }) => {
    // 1. auth 서브도메인의 로그인 페이지 접근
    await page.goto('http://auth.creatia.local:3000/login');
    
    // 2. 로그인 페이지 확인
    await expect(page.locator('h2')).toContainText('Welcome to Creatia');
    
    // 3. 로그인
    await page.fill('input[name="auth_user_user[email]"]', testUser.email);
    await page.fill('input[name="auth_user_user[password]"]', testUser.password);
    await page.locator('input[type="submit"][value="로그인"]').click();
    
    // 4. 로그인 후 리다이렉트 확인 (조직 선택 페이지 또는 대시보드)
    await page.waitForLoadState('networkidle');
    
    const url = page.url();
    // 조직이 하나면 바로 대시보드로, 여러 개면 선택 페이지로
    const validUrls = [
      'organization_selection',
      `${demoOrg.subdomain}.creatia.local:3000/dashboard`
    ];
    
    expect(validUrls.some(valid => url.includes(valid))).toBeTruthy();
  });

  test('로그인 페이지에 데모 계정 정보가 표시된다', async ({ page }) => {
    // 1. 로그인 페이지 접근
    await page.goto('http://auth.creatia.local:3000/login');
    
    // 2. 데모 계정 정보 카드 확인
    const demoCard = page.locator('.bg-blue-50');
    await expect(demoCard).toBeVisible();
    await expect(demoCard).toContainText('데모 계정');
    await expect(demoCard).toContainText('Email: admin@creatia.local');
    await expect(demoCard).toContainText('Password: password123');
  });

  test('잘못된 자격 증명으로 로그인 시도시 에러 메시지 표시', async ({ page }) => {
    // 1. 로그인 페이지 접근
    await page.goto('http://auth.creatia.local:3000/login');
    
    // 2. 잘못된 자격 증명으로 로그인
    await page.fill('input[name="auth_user_user[email]"]', 'wrong@email.com');
    await page.fill('input[name="auth_user_user[password]"]', 'wrongpassword');
    await page.locator('input[type="submit"][value="로그인"]').click();
    
    // 3. 에러 메시지 확인
    await expect(page.locator('.alert, .flash, [role="alert"]')).toBeVisible();
  });

  test('로그인 폼 UI 요소들이 올바르게 표시된다', async ({ page }) => {
    // 1. 로그인 페이지 접근
    await page.goto('http://auth.creatia.local:3000/login');
    
    // 2. Creatia 로고/브랜딩 확인
    const logo = page.locator('.h-16.w-16');
    await expect(logo).toBeVisible();
    await expect(logo).toHaveClass(/bg-gradient-to-r/);
    
    // 3. 제목과 부제목 확인
    await expect(page.locator('h2')).toContainText('Welcome to Creatia');
    await expect(page.locator('p.text-gray-600').first()).toContainText('멀티테넌트 프로젝트 관리 플랫폼');
    
    // 4. 이메일 입력 필드와 아이콘 확인
    const emailField = page.locator('input[name="auth_user_user[email]"]');
    await expect(emailField).toBeVisible();
    await expect(emailField).toHaveAttribute('placeholder', 'your@email.com');
    await expect(page.locator('svg').first()).toBeVisible(); // 이메일 아이콘
    
    // 5. 비밀번호 입력 필드와 아이콘 확인
    const passwordField = page.locator('input[name="auth_user_user[password]"]');
    await expect(passwordField).toBeVisible();
    await expect(passwordField).toHaveAttribute('placeholder', '••••••••');
    
    // 6. "로그인 상태 유지" 체크박스 확인
    const rememberCheckbox = page.locator('input[type="checkbox"][name="auth_user_user[remember_me]"]');
    await expect(rememberCheckbox).toBeVisible();
    await expect(page.locator('label[for*="remember"]')).toContainText('로그인 상태 유지');
    
    // 7. "비밀번호를 잊으셨나요?" 링크 확인
    const forgotLink = page.locator('a:has-text("비밀번호를 잊으셨나요?")');
    await expect(forgotLink).toBeVisible();
    
    // 8. 로그인 버튼 스타일 확인
    const submitButton = page.locator('input[type="submit"][value="로그인"]');
    await expect(submitButton).toBeVisible();
    await expect(submitButton).toHaveClass(/bg-gradient-to-r/);
    
    // 9. 회원가입 링크 확인
    const signupSection = page.locator('text=아직 계정이 없으신가요?');
    await expect(signupSection).toBeVisible();
    const signupLink = page.locator('a:has-text("회원가입")');
    await expect(signupLink).toBeVisible();
  });

  test.skip('크로스 도메인 리다이렉트가 allow_other_host로 정상 작동한다', async ({ page }) => {
    // 에러 리스너 설정
    const errors: string[] = [];
    page.on('pageerror', error => {
      errors.push(error.message);
    });
    
    // 1. 조직 서브도메인 접근 시도
    await page.goto(`http://${demoOrg.subdomain}.creatia.local/dashboard`);
    
    // 2. auth 도메인으로 리다이렉트
    await expect(page).toHaveURL(/auth\.creatia\.local.*\/login/);
    
    // 3. 로그인
    await page.fill('input[name="auth_user_user[email]"]', testUser.email);
    await page.fill('input[name="auth_user_user[password]"]', testUser.password);
    await page.locator('input[type="submit"][value="로그인"]').click();
    
    // 4. 조직 도메인으로 리다이렉트
    await page.waitForURL(`http://${demoOrg.subdomain}.creatia.local/dashboard`);
    
    // 5. "Unsafe redirect" 에러가 없는지 확인
    expect(errors.filter(e => e.includes('Unsafe redirect'))).toHaveLength(0);
  });
});

test.describe('조직 선택 플로우', () => {
  test('여러 조직에 속한 사용자는 조직 선택 페이지를 본다', async ({ page }) => {
    // 이 테스트는 실제로는 여러 조직을 가진 사용자가 필요함
    // 현재는 데모 데이터로 단일 조직만 있으므로 스킵하거나 시뮬레이션 필요
    test.skip();
  });

  test.skip('권한이 없는 조직 접근 시 접근 거부 페이지를 표시한다', async ({ page }) => {
    // 1. 로그인
    await page.goto('http://auth.creatia.local:3000/login');
    await page.fill('input[name="auth_user_user[email]"]', testUser.email);
    await page.fill('input[name="auth_user_user[password]"]', testUser.password);
    await page.locator('input[type="submit"][value="로그인"]').click();
    
    // 2. 권한 없는 조직으로 접근 시도
    await page.goto('http://unauthorized.creatia.local:3000/dashboard');
    
    // 3. 접근 거부 또는 로그인 페이지로 리다이렉트 확인
    const url = page.url();
    expect(
      url.includes('access_denied') || 
      url.includes('login') ||
      url.includes('auth.creatia.local')
    ).toBeTruthy();
  });
});

test.describe('세션 관리', () => {
  test('로그아웃 후 보호된 페이지 접근 시 로그인 페이지로 리다이렉트', async ({ page, context }) => {
    // 1. 로그인
    await page.goto('http://auth.creatia.local:3000/login');
    await page.fill('input[name="auth_user_user[email]"]', testUser.email);
    await page.fill('input[name="auth_user_user[password]"]', testUser.password);
    await page.locator('input[type="submit"][value="로그인"]').click();
    
    // 2. 대시보드로 이동 확인
    await page.waitForLoadState('networkidle');
    
    // 3. 쿠키 삭제로 로그아웃 시뮬레이션
    await context.clearCookies();
    
    // 4. 보호된 페이지 접근 시도
    await page.goto(`http://${demoOrg.subdomain}.creatia.local/dashboard`);
    
    // 5. 로그인 페이지로 리다이렉트 확인
    await expect(page).toHaveURL(/auth\.creatia\.local.*\/login/);
  });
});