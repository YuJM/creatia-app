import { test, expect } from '@playwright/test';

test('로그인 페이지 로드 확인', async ({ page }) => {
  // auth 서브도메인의 로그인 페이지로 이동
  await page.goto('http://auth.creatia.local:3000/login');
  
  // 페이지 로드 대기
  await page.waitForLoadState('networkidle');
  
  // 타이틀 확인
  const title = await page.title();
  console.log('페이지 타이틀:', title);
  
  // h2 요소 텍스트 확인
  const h2Text = await page.locator('h2').first().textContent();
  console.log('H2 텍스트:', h2Text);
  
  // Welcome to Creatia 텍스트가 있는지 확인
  expect(h2Text).toContain('Welcome to Creatia');
});