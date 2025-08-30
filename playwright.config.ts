import { defineConfig, devices } from '@playwright/test';

// BASE_DOMAIN 환경변수 설정 (기본값: creatia.local)
const BASE_DOMAIN = process.env.BASE_DOMAIN || 'creatia.local';
const PORT = process.env.PORT || '3000';

/**
 * Playwright E2E 테스트 설정
 */
export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 1, // 로컬에서도 1회 재시도
  workers: process.env.CI ? 1 : 3, // 로컬에서 워커 수 제한
  
  // 향상된 리포터 설정
  reporter: [
    ['html', { 
      outputFolder: 'playwright-report',
      open: 'never' // 자동으로 브라우저 열지 않음
    }],
    ['json', { 
      outputFile: 'test-results/e2e-results.json' // E2E 테스트 결과를 명확하게 표시
    }],
    ['junit', { 
      outputFile: 'test-results/e2e-junit.xml' // JUnit 형식 (CI/CD 연동용)
    }],
    ['list'], // 콘솔에 진행 상황 표시
  ],
  
  // 테스트 타임아웃 설정
  timeout: 30000, // 각 테스트 30초
  expect: {
    timeout: 10000, // expect 타임아웃 10초
  },
  
  use: {
    baseURL: `http://${BASE_DOMAIN}:${PORT}`, // 포트 포함
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    
    // 크로스 도메인 테스트를 위한 설정
    ignoreHTTPSErrors: true,
    extraHTTPHeaders: {
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    },
    
    // 네트워크 재시도 설정
    navigationTimeout: 30000,
    actionTimeout: 10000,
  },

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
  ],

  webServer: {
    command: 'bin/rails server -p 3000',
    port: 3000,
    reuseExistingServer: true,  // 이미 실행 중인 서버 사용
    timeout: 120000,
  },
});