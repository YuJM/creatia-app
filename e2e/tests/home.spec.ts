import { test, expect } from '@playwright/test';

test.describe('홈페이지 E2E 테스트', () => {
  test.beforeEach(async ({ page }) => {
    // 각 테스트 전에 홈페이지로 이동
    await page.goto('/pages/home');
  });

  test('홈페이지가 정상적으로 로드된다', async ({ page }) => {
    // 페이지 타이틀 확인
    await expect(page).toHaveTitle(/Creatia App/);
    
    // 메인 콘텐츠가 보이는지 확인
    const mainContent = page.locator('main.container');
    await expect(mainContent).toBeVisible();
  });

  test('홈페이지에 제목이 표시된다', async ({ page }) => {
    // h1 태그의 텍스트 확인
    const heading = page.locator('h1');
    await expect(heading).toBeVisible();
    await expect(heading).toHaveClass(/text-red-500/);
  });

  test('Tailwind CSS 클래스가 적용된다', async ({ page }) => {
    // Tailwind 클래스가 적용되었는지 확인
    const heading = page.locator('h1');
    const classes = await heading.getAttribute('class');
    expect(classes).toContain('font-bold');
    expect(classes).toContain('text-4xl');
    expect(classes).toContain('text-red-500');
  });

  test('반응형 디자인이 작동한다', async ({ page, viewport }) => {
    // 모바일 뷰포트로 변경
    await page.setViewportSize({ width: 375, height: 667 });
    
    // 콘텐츠가 여전히 보이는지 확인
    const mainContent = page.locator('main.container');
    await expect(mainContent).toBeVisible();
    
    // 데스크톱 뷰포트로 변경
    await page.setViewportSize({ width: 1920, height: 1080 });
    await expect(mainContent).toBeVisible();
  });

  test('페이지 로딩 성능 측정', async ({ page }) => {
    // 성능 측정 시작
    const startTime = Date.now();
    
    // 페이지 로드
    await page.goto('/pages/home', { waitUntil: 'networkidle' });
    
    const loadTime = Date.now() - startTime;
    
    // 3초 이내에 로드되어야 함
    expect(loadTime).toBeLessThan(3000);
  });
});

test.describe('네비게이션 테스트', () => {
  test('브라우저 뒤로가기가 작동한다', async ({ page }) => {
    // 첫 페이지로 이동
    await page.goto('/');
    
    // 홈페이지로 이동
    await page.goto('/pages/home');
    
    // 뒤로가기
    await page.goBack();
    
    // URL 확인
    expect(page.url()).toContain('localhost:3000');
  });
});