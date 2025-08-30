const { test, expect } = require('@playwright/test');

// Test configuration - 기존 seed 데이터 사용
const BASE_URL = 'http://creatia.local:3000';
const AUTH_URL = 'http://auth.creatia.local:3000';
const DEMO_URL = 'http://demo.creatia.local:3000';

// 기존 seed 데이터의 사용자 정보
const testUsers = {
  admin: {
    email: 'admin@creatia.local',
    password: 'password123',
    name: '관리자',
    role: 'admin'
  },
  john: {
    email: 'john@creatia.local', 
    password: 'password123',
    name: 'John Doe',
    role: 'owner' // Acme Corporation의 owner
  },
  jane: {
    email: 'jane@creatia.local',
    password: 'password123', 
    name: 'Jane Smith',
    role: 'owner' // Startup Inc의 owner
  },
  mike: {
    email: 'mike@creatia.local',
    password: 'password123',
    name: 'Mike Johnson',
    role: 'member' // Demo의 member
  },
  sarah: {
    email: 'sarah@creatia.local',
    password: 'password123',
    name: 'Sarah Wilson',
    role: 'member' // Demo의 member
  }
};

test.describe('Multi-Tenant Dynamic RBAC with Seed Data', () => {
  
  test.describe('Authentication Flow', () => {
    test('should login with admin user', async ({ page }) => {
      await page.goto(`${AUTH_URL}/login`);
      
      await page.fill('input[name="user[email]"]', testUsers.admin.email);
      await page.fill('input[name="user[password]"]', testUsers.admin.password);
      
      const submitButton = page.locator('input[type="submit"], button[type="submit"]').first();
      await submitButton.click();
      
      await page.waitForLoadState('networkidle');
      
      // admin은 여러 조직에 속해있을 수 있으므로 조직 선택 페이지나 대시보드로 이동
      const currentUrl = page.url();
      expect(currentUrl).toMatch(/organization_selection|dashboard|pages/);
    });

    test('should login with regular user', async ({ page }) => {
      await page.goto(`${AUTH_URL}/login`);
      
      await page.fill('input[name="user[email]"]', testUsers.mike.email);
      await page.fill('input[name="user[password]"]', testUsers.mike.password);
      
      const submitButton = page.locator('input[type="submit"], button[type="submit"]').first();
      await submitButton.click();
      
      await page.waitForLoadState('networkidle');
      
      const currentUrl = page.url();
      expect(currentUrl).toMatch(/organization_selection|dashboard|pages/);
    });
  });

  test.describe('Organization Access', () => {
    test('admin can access Demo organization', async ({ page }) => {
      // 먼저 로그인
      await page.goto(`${AUTH_URL}/login`);
      await page.fill('input[name="user[email]"]', testUsers.admin.email);
      await page.fill('input[name="user[password]"]', testUsers.admin.password);
      const submitButton = page.locator('input[type="submit"], button[type="submit"]').first();
      await submitButton.click();
      await page.waitForLoadState('networkidle');
      
      // Demo 조직 접근 시도
      await page.goto(`${DEMO_URL}/dashboard`);
      await page.waitForLoadState('networkidle');
      
      // 대시보드 페이지에 접근 가능해야 함
      const pageTitle = await page.title();
      expect(pageTitle).toBeTruthy();
      
      // 권한이 있는 경우 대시보드 콘텐츠가 표시되어야 함
      const bodyText = await page.textContent('body');
      expect(bodyText).toBeTruthy();
    });

    test('member can access assigned tasks in Demo', async ({ page }) => {
      // Mike로 로그인 (Demo의 member)
      await page.goto(`${AUTH_URL}/login`);
      await page.fill('input[name="user[email]"]', testUsers.mike.email);
      await page.fill('input[name="user[password]"]', testUsers.mike.password);
      const submitButton = page.locator('input[type="submit"], button[type="submit"]').first();
      await submitButton.click();
      await page.waitForLoadState('networkidle');
      
      // Demo 조직의 tasks 페이지 접근
      await page.goto(`${DEMO_URL}/tasks`);
      await page.waitForLoadState('networkidle');
      
      // Tasks 페이지에 접근 가능해야 함
      const currentUrl = page.url();
      expect(currentUrl).toContain('/tasks');
    });
  });

  test.describe('RBAC Role Management', () => {
    test('admin can access role management page', async ({ page }) => {
      // Admin으로 로그인
      await page.goto(`${AUTH_URL}/login`);
      await page.fill('input[name="user[email]"]', testUsers.admin.email);
      await page.fill('input[name="user[password]"]', testUsers.admin.password);
      const submitButton = page.locator('input[type="submit"], button[type="submit"]').first();
      await submitButton.click();
      await page.waitForLoadState('networkidle');
      
      // Demo 조직의 역할 관리 페이지 접근
      await page.goto(`${DEMO_URL}/organization/roles`);
      await page.waitForLoadState('networkidle');
      
      // 역할 관리 페이지에 접근 가능해야 함
      const pageContent = await page.textContent('body');
      
      // 역할 관련 콘텐츠가 있는지 확인
      expect(pageContent).toContain('owner');  // Owner 역할
      expect(pageContent).toContain('admin');  // Admin 역할
      expect(pageContent).toContain('member'); // Member 역할
    });

    test('member cannot access role management page', async ({ page }) => {
      // Mike로 로그인 (member)
      await page.goto(`${AUTH_URL}/login`);
      await page.fill('input[name="user[email]"]', testUsers.mike.email);
      await page.fill('input[name="user[password]"]', testUsers.mike.password);
      const submitButton = page.locator('input[type="submit"], button[type="submit"]').first();
      await submitButton.click();
      await page.waitForLoadState('networkidle');
      
      // Demo 조직의 역할 관리 페이지 접근 시도
      await page.goto(`${DEMO_URL}/organization/roles`);
      await page.waitForLoadState('networkidle');
      
      // 접근 거부되거나 리다이렉트되어야 함
      const currentUrl = page.url();
      
      // 역할 페이지가 아닌 다른 페이지(대시보드나 접근 거부)로 리다이렉트
      expect(currentUrl).not.toContain('/organization/roles');
    });
  });

  test.describe('Permission Enforcement', () => {
    test('owner can manage organization members', async ({ page }) => {
      // John으로 로그인 (Acme의 owner)
      await page.goto(`${AUTH_URL}/login`);
      await page.fill('input[name="user[email]"]', testUsers.john.email);
      await page.fill('input[name="user[password]"]', testUsers.john.password);
      const submitButton = page.locator('input[type="submit"], button[type="submit"]').first();
      await submitButton.click();
      await page.waitForLoadState('networkidle');
      
      // Acme 조직의 멤버 관리 페이지 접근
      await page.goto('http://acme.creatia.local:3000/organization/members');
      await page.waitForLoadState('networkidle');
      
      // 멤버 관리 페이지에 접근 가능해야 함
      const pageContent = await page.textContent('body');
      
      // 멤버 관련 콘텐츠 확인
      expect(pageContent).toContain('Jane Smith'); // Acme의 admin
      expect(pageContent).toContain('Mike Johnson'); // Acme의 member
    });

    test('member cannot delete tasks they did not create', async ({ page }) => {
      // Sarah로 로그인 (Demo의 member)
      await page.goto(`${AUTH_URL}/login`);
      await page.fill('input[name="user[email]"]', testUsers.sarah.email);
      await page.fill('input[name="user[password]"]', testUsers.sarah.password);
      const submitButton = page.locator('input[type="submit"], button[type="submit"]').first();
      await submitButton.click();
      await page.waitForLoadState('networkidle');
      
      // Demo 조직의 tasks 페이지 접근
      await page.goto(`${DEMO_URL}/tasks`);
      await page.waitForLoadState('networkidle');
      
      // 삭제 버튼이 없거나 비활성화되어야 함
      const deleteButtons = await page.locator('button:has-text("삭제"), a:has-text("Delete")').all();
      
      // Member는 task 삭제 권한이 제한적이어야 함
      for (const button of deleteButtons) {
        const isDisabled = await button.isDisabled();
        // 버튼이 있다면 비활성화되어야 함
        if (await button.isVisible()) {
          expect(isDisabled).toBeTruthy();
        }
      }
    });
  });

  test.describe('Audit Logs', () => {
    test('admin can view permission audit logs', async ({ page }) => {
      // Admin으로 로그인
      await page.goto(`${AUTH_URL}/login`);
      await page.fill('input[name="user[email]"]', testUsers.admin.email);
      await page.fill('input[name="user[password]"]', testUsers.admin.password);
      const submitButton = page.locator('input[type="submit"], button[type="submit"]').first();
      await submitButton.click();
      await page.waitForLoadState('networkidle');
      
      // Demo 조직의 감사 로그 페이지 접근
      await page.goto(`${DEMO_URL}/organization/permission_audit_logs`);
      await page.waitForLoadState('networkidle');
      
      // 감사 로그 페이지에 접근 가능해야 함
      const pageContent = await page.textContent('body');
      
      // 감사 로그 관련 콘텐츠 확인
      expect(pageContent).toMatch(/권한 감사 로그|Permission Audit|Audit Logs/i);
    });

    test('member cannot view audit logs', async ({ page }) => {
      // Mike로 로그인 (member)
      await page.goto(`${AUTH_URL}/login`);
      await page.fill('input[name="user[email]"]', testUsers.mike.email);
      await page.fill('input[name="user[password]"]', testUsers.mike.password);
      const submitButton = page.locator('input[type="submit"], button[type="submit"]').first();
      await submitButton.click();
      await page.waitForLoadState('networkidle');
      
      // Demo 조직의 감사 로그 페이지 접근 시도
      await page.goto(`${DEMO_URL}/organization/permission_audit_logs`);
      await page.waitForLoadState('networkidle');
      
      // 접근 거부되거나 리다이렉트되어야 함
      const currentUrl = page.url();
      
      // 감사 로그 페이지가 아닌 다른 페이지로 리다이렉트
      expect(currentUrl).not.toContain('/permission_audit_logs');
    });
  });

  test.describe('Cross-Organization Isolation', () => {
    test('user cannot access organization they do not belong to', async ({ page }) => {
      // Jane으로 로그인 (Startup Inc의 owner, Test Organization에는 속하지 않음)
      await page.goto(`${AUTH_URL}/login`);
      await page.fill('input[name="user[email]"]', testUsers.jane.email);
      await page.fill('input[name="user[password]"]', testUsers.jane.password);
      const submitButton = page.locator('input[type="submit"], button[type="submit"]').first();
      await submitButton.click();
      await page.waitForLoadState('networkidle');
      
      // Test Organization 접근 시도 (Jane은 멤버가 아님)
      await page.goto('http://test.creatia.local:3000/dashboard');
      await page.waitForLoadState('networkidle');
      
      // 접근 거부되거나 리다이렉트되어야 함
      const currentUrl = page.url();
      
      // Test 조직의 대시보드가 아닌 다른 페이지로 리다이렉트
      expect(currentUrl).not.toMatch(/test\.creatia\.local.*dashboard/);
    });
  });
});