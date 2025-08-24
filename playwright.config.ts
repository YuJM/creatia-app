import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright E2E 테스트 설정
 * @see https://playwright.dev/docs/test-configuration
 */
export default defineConfig({
  testDir: './e2e',
  /* 병렬 실행 설정 */
  fullyParallel: true,
  /* CI에서 실패한 테스트 재시도 금지 */
  forbidOnly: !!process.env.CI,
  /* 재시도 횟수 */
  retries: process.env.CI ? 2 : 0,
  /* 병렬 워커 수 */
  workers: process.env.CI ? 1 : undefined,
  /* 리포터 설정 */
  reporter: 'html',
  /* 모든 테스트에 공통 설정 */
  use: {
    /* Base URL 설정 */
    baseURL: 'http://localhost:3000',
    /* 액션 트레이스 수집 */
    trace: 'on-first-retry',
    /* 스크린샷 설정 */
    screenshot: 'only-on-failure',
    /* 비디오 녹화 설정 */
    video: 'retain-on-failure',
  },

  /* 프로젝트별 브라우저 설정 */
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },

    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },

    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },

    /* 모바일 뷰포트 테스트 */
    {
      name: 'Mobile Chrome',
      use: { ...devices['Pixel 5'] },
    },
    {
      name: 'Mobile Safari',
      use: { ...devices['iPhone 12'] },
    },
  ],

  /* 로컬 개발 서버 실행 */
  webServer: {
    command: 'bin/rails server',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000,
  },
});