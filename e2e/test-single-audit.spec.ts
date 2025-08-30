import { test, expect } from '@playwright/test';
import { AuthHelper } from './helpers/auth.helper';

test('Debug: Owner can view audit logs', async ({ page, context }) => {
  // Admin으로 로그인 (Demo 조직의 Owner)
  const cookies = await AuthHelper.loginWithSession(page, context, 'admin@creatia.local');
  console.log('Owner authentication successful');
  
  // 감사 로그 페이지로 이동
  console.log('Navigating to audit logs page...');
  const response = await page.goto('http://demo.creatia.local:3000/organization/permission_audit_logs', { 
    waitUntil: 'networkidle',
    timeout: 30000 
  });
  
  // 응답 상태 확인
  console.log('Response status:', response?.status());
  
  // 현재 URL 확인
  const currentUrl = page.url();
  console.log('Current URL:', currentUrl);
  
  // 페이지 제목 확인
  const title = await page.title();
  console.log('Page title:', title);
  
  // 페이지 내용 일부 출력
  const pageContent = await page.textContent('body');
  console.log('Page content length:', pageContent?.length);
  console.log('First 500 chars:', pageContent?.substring(0, 500));
  
  // 특정 요소 찾기
  const h1 = await page.textContent('h1');
  console.log('H1 content:', h1);
  
  // 테스트 assertions
  expect(currentUrl).toContain('/permission_audit_logs');
  expect(pageContent).toMatch(/권한 감사 로그|Permission Audit|Audit Logs/i);
});