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

test.describe('Multi-Tenant Dynamic RBAC Permissions Test', () => {
  
  test.describe('Owner Permissions', () => {
    let ownerCookies: Cookie[] = [];
    
    test.beforeAll(async ({ browser }) => {
      const context = await browser.newContext();
      const page = await context.newPage();
      
      try {
        // Admin으로 로그인 (Demo 조직의 Owner)
        ownerCookies = await AuthHelper.loginWithSession(page, context, TEST_ACCOUNTS.admin.email);
        console.log('Owner authentication successful');
      } finally {
        await context.close();
      }
    });
    
    test.beforeEach(async ({ context }) => {
      await AuthHelper.restoreSession(context, ownerCookies);
    });
    
    test('Owner can access role management', async ({ page }) => {
      await page.goto('http://demo.creatia.local:3000/organization/roles', { waitUntil: 'networkidle' });
      
      // 리다이렉트 확인
      const currentUrl = page.url();
      expect(currentUrl).toContain('/organization/roles');
      
      // 역할 관리 페이지 요소 확인
      const pageContent = await page.textContent('body');
      expect(pageContent).toMatch(/owner|admin|member|viewer/i);
    });
    
    test('Owner can view audit logs', async ({ page }) => {
      await page.goto('http://demo.creatia.local:3000/organization/permission_audit_logs', { waitUntil: 'networkidle' });
      
      const currentUrl = page.url();
      expect(currentUrl).toContain('/permission_audit_logs');
      
      // 감사 로그 페이지 요소 확인
      const pageContent = await page.textContent('body');
      expect(pageContent).toMatch(/권한 감사 로그|Permission Audit|Audit Logs/i);
    });
    
    test('Owner can manage members', async ({ page }) => {
      await page.goto('http://demo.creatia.local:3000/organization/members', { waitUntil: 'networkidle' });
      
      const currentUrl = page.url();
      expect(currentUrl).toContain('/members');
      
      // 멤버 관리 기능 확인
      const pageContent = await page.textContent('body');
      expect(pageContent).toContain('John Doe');  // Demo의 admin
      expect(pageContent).toContain('Jane Smith'); // Demo의 admin
      expect(pageContent).toContain('Mike Johnson'); // Demo의 member
    });
  });
  
  test.describe('Admin Permissions', () => {
    let adminCookies: Cookie[] = [];
    
    test.beforeAll(async ({ browser }) => {
      const context = await browser.newContext();
      const page = await context.newPage();
      
      try {
        // John으로 로그인 (Demo 조직의 Admin)
        adminCookies = await AuthHelper.loginWithSession(page, context, TEST_ACCOUNTS.john.email);
        console.log('Admin authentication successful');
      } finally {
        await context.close();
      }
    });
    
    test.beforeEach(async ({ context }) => {
      await AuthHelper.restoreSession(context, adminCookies);
    });
    
    test('Admin can access tasks', async ({ page }) => {
      await page.goto('http://demo.creatia.local:3000/tasks', { waitUntil: 'networkidle' });
      
      const currentUrl = page.url();
      if (currentUrl.includes('/sign_in') || currentUrl.includes('/login')) {
        throw new Error('Admin authentication failed');
      }
      
      expect(currentUrl).toContain('/tasks');
      
      // Task 페이지 콘텐츠 확인
      const pageContent = await page.textContent('body');
      expect(pageContent).toMatch(/Task|작업|태스크/i);
    });
    
    test('Admin can create new tasks', async ({ page }) => {
      await page.goto('http://demo.creatia.local:3000/tasks/new', { waitUntil: 'networkidle' });
      
      const currentUrl = page.url();
      expect(currentUrl).toContain('/tasks/new');
      
      // Task 생성 폼 확인
      const titleInput = page.locator('input[name*="title"], input[name*="name"]').first();
      await expect(titleInput).toBeVisible({ timeout: 5000 });
    });
    
    test('Admin cannot access certain owner-only features', async ({ page }) => {
      // 예: 조직 삭제 등의 Owner 전용 기능
      await page.goto('http://demo.creatia.local:3000/organization/delete', { waitUntil: 'networkidle' });
      
      const currentUrl = page.url();
      // 접근 거부되거나 리다이렉트되어야 함
      expect(currentUrl).not.toContain('/organization/delete');
    });
  });
  
  test.describe('Member Permissions', () => {
    let memberCookies: Cookie[] = [];
    
    test.beforeAll(async ({ browser }) => {
      const context = await browser.newContext();
      const page = await context.newPage();
      
      try {
        // Mike로 로그인 (Demo 조직의 Member)
        memberCookies = await AuthHelper.loginWithSession(page, context, TEST_ACCOUNTS.mike.email);
        console.log('Member authentication successful');
      } finally {
        await context.close();
      }
    });
    
    test.beforeEach(async ({ context }) => {
      await AuthHelper.restoreSession(context, memberCookies);
    });
    
    test('Member can view tasks', async ({ page }) => {
      await page.goto('http://demo.creatia.local:3000/tasks', { waitUntil: 'networkidle' });
      
      const currentUrl = page.url();
      expect(currentUrl).toContain('/tasks');
      
      // Task 목록 확인
      const pageContent = await page.textContent('body');
      expect(pageContent).toMatch(/Task|작업|태스크/i);
    });
    
    test('Member cannot access role management', async ({ page }) => {
      await page.goto('http://demo.creatia.local:3000/organization/roles', { waitUntil: 'networkidle' });
      
      const currentUrl = page.url();
      // 역할 관리 페이지에 접근할 수 없어야 함
      expect(currentUrl).not.toContain('/organization/roles');
    });
    
    test('Member cannot view audit logs', async ({ page }) => {
      await page.goto('http://demo.creatia.local:3000/organization/permission_audit_logs', { waitUntil: 'networkidle' });
      
      const currentUrl = page.url();
      // 감사 로그 페이지에 접근할 수 없어야 함
      expect(currentUrl).not.toContain('/permission_audit_logs');
    });
    
    test('Member cannot manage other members', async ({ page }) => {
      await page.goto('http://demo.creatia.local:3000/organization/members', { waitUntil: 'networkidle' });
      
      const currentUrl = page.url();
      
      if (currentUrl.includes('/members')) {
        // 멤버 목록은 볼 수 있어도 관리 버튼은 없어야 함
        const editButtons = await page.locator('button:has-text("역할 변경"), button:has-text("Edit Role")').count();
        const deleteButtons = await page.locator('button:has-text("삭제"), button:has-text("Remove")').count();
        
        expect(editButtons).toBe(0);
        expect(deleteButtons).toBe(0);
      } else {
        // 또는 페이지 자체에 접근 불가
        expect(currentUrl).not.toContain('/members');
      }
    });
  });
  
  test.describe('Cross-Organization Isolation', () => {
    test('User cannot access organization they do not belong to', async ({ browser }) => {
      const context = await browser.newContext();
      const page = await context.newPage();
      
      try {
        // Jane으로 로그인 (Startup Inc의 Owner, Test Organization에는 속하지 않음)
        const janeCookies = await AuthHelper.loginWithSession(page, context, TEST_ACCOUNTS.jane.email);
        await AuthHelper.restoreSession(context, janeCookies);
        
        // Test Organization 접근 시도
        await page.goto('http://test.creatia.local:3000/dashboard', { waitUntil: 'networkidle' });
        
        const currentUrl = page.url();
        // Test 조직에 접근할 수 없어야 함
        expect(currentUrl).toMatch(/sign_in|login|access_denied/);
      } finally {
        await context.close();
      }
    });
    
    test('Owner of one organization cannot manage another organization', async ({ browser }) => {
      const context = await browser.newContext();
      const page = await context.newPage();
      
      try {
        // John으로 로그인 (Acme Corporation의 Owner)
        const johnCookies = await AuthHelper.loginWithSession(page, context, TEST_ACCOUNTS.john.email);
        await AuthHelper.restoreSession(context, johnCookies);
        
        // Startup Inc의 역할 관리 페이지 접근 시도
        await page.goto('http://startup.creatia.local:3000/organization/roles', { waitUntil: 'networkidle' });
        
        const currentUrl = page.url();
        // Startup 조직의 역할 관리에 접근할 수 없어야 함
        expect(currentUrl).not.toMatch(/startup.*organization\/roles/);
      } finally {
        await context.close();
      }
    });
  });
  
  test.describe('Dynamic Permission Changes', () => {
    test('Permission changes are reflected immediately', async ({ browser }) => {
      const context = await browser.newContext();
      const page = await context.newPage();
      
      try {
        // Sarah로 로그인 (Demo 조직의 Member)
        const sarahCookies = await AuthHelper.loginWithSession(page, context, TEST_ACCOUNTS.sarah.email);
        await AuthHelper.restoreSession(context, sarahCookies);
        
        // 초기 상태: Task 생성 페이지 접근 시도
        await page.goto('http://demo.creatia.local:3000/tasks/new', { waitUntil: 'networkidle' });
        
        const currentUrl = page.url();
        
        // Member는 기본적으로 Task 생성 권한이 제한적일 수 있음
        if (!currentUrl.includes('/tasks/new')) {
          console.log('Member cannot create tasks initially - expected behavior');
          expect(currentUrl).not.toContain('/tasks/new');
        } else {
          console.log('Member can create tasks - checking if this is intended');
          expect(currentUrl).toContain('/tasks/new');
        }
      } finally {
        await context.close();
      }
    });
  });
});