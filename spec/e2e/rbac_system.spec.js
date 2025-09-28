const { test, expect } = require('@playwright/test');

// Test configuration
const BASE_URL = 'http://127.0.0.1:3000';
const TENANT_URL = 'http://test-org.localhost:3000';

// Test data
const testUser = {
  email: 'admin@example.com',
  password: 'password123'
};

const testOrganization = {
  name: 'Test Organization',
  subdomain: 'test-org'
};

test.describe('Multi-Tenant Dynamic RBAC System', () => {
  test.beforeEach(async ({ page }) => {
    // Login before each test
    await page.goto(`${BASE_URL}/users/login`);
    await page.fill('input[name="user[email]"]', testUser.email);
    await page.fill('input[name="user[password]"]', testUser.password);
    await page.click('button[type="submit"]');
    
    // Wait for login to complete
    await page.waitForURL(/dashboard|organizations/);
  });

  test.describe('Role Management', () => {
    test('should create a new role', async ({ page }) => {
      // Navigate to organization context
      await page.goto(`${TENANT_URL}/organization/roles`);
      
      // Click new role button
      await page.click('a:has-text("새 역할 추가")');
      
      // Fill role form
      await page.fill('input[name="role[name]"]', 'Test Manager');
      await page.fill('textarea[name="role[description]"]', 'A test manager role');
      
      // Select permissions
      await page.click('input[value="tasks:read"]');
      await page.click('input[value="tasks:create"]');
      await page.click('input[value="tasks:update"]');
      
      // Submit form
      await page.click('button:has-text("역할 생성")');
      
      // Verify role was created
      await expect(page.locator('text=Test Manager')).toBeVisible();
      await expect(page.locator('text=A test manager role')).toBeVisible();
    });

    test('should edit an existing role', async ({ page }) => {
      await page.goto(`${TENANT_URL}/organization/roles`);
      
      // Find and click edit on first non-system role
      const roleCard = page.locator('.role-card').filter({ hasText: 'Test Manager' }).first();
      await roleCard.locator('a:has-text("수정")').click();
      
      // Update role
      await page.fill('input[name="role[name]"]', 'Updated Manager');
      await page.fill('textarea[name="role[description]"]', 'Updated description');
      
      // Add more permissions
      await page.click('input[value="members:read"]');
      
      // Save changes
      await page.click('button:has-text("변경사항 저장")');
      
      // Verify update
      await expect(page.locator('text=Updated Manager')).toBeVisible();
      await expect(page.locator('text=Updated description')).toBeVisible();
    });

    test('should duplicate a role', async ({ page }) => {
      await page.goto(`${TENANT_URL}/organization/roles`);
      
      // Find and duplicate a role
      const roleCard = page.locator('.role-card').filter({ hasText: 'Updated Manager' }).first();
      await roleCard.locator('button:has-text("복제")').click();
      
      // Confirm duplication
      await page.click('button:has-text("확인")');
      
      // Verify duplicated role exists
      await expect(page.locator('text=Updated Manager (복사본)')).toBeVisible();
    });

    test('should delete a role', async ({ page }) => {
      await page.goto(`${TENANT_URL}/organization/roles`);
      
      // Find and delete the duplicated role
      const roleCard = page.locator('.role-card').filter({ hasText: '복사본' }).first();
      await roleCard.locator('button:has-text("삭제")').click();
      
      // Confirm deletion
      await page.click('button:has-text("삭제 확인")');
      
      // Verify role was deleted
      await expect(page.locator('text=복사본')).not.toBeVisible();
    });

    test('should not allow deletion of system roles', async ({ page }) => {
      await page.goto(`${TENANT_URL}/organization/roles`);
      
      // Find system role (owner)
      const ownerCard = page.locator('.role-card').filter({ hasText: 'Owner' });
      
      // Verify delete button is disabled or not present
      const deleteButton = ownerCard.locator('button:has-text("삭제")');
      await expect(deleteButton).toBeDisabled();
    });
  });

  test.describe('Permission Assignment', () => {
    test('should show permission selector with presets', async ({ page }) => {
      await page.goto(`${TENANT_URL}/organization/roles/new`);
      
      // Click on preset buttons
      await page.click('button:has-text("읽기 전용")');
      
      // Verify read permissions are selected
      await expect(page.locator('input[value="tasks:read"]')).toBeChecked();
      await expect(page.locator('input[value="projects:read"]')).toBeChecked();
      
      // Click editor preset
      await page.click('button:has-text("편집자")');
      
      // Verify editor permissions
      await expect(page.locator('input[value="tasks:create"]')).toBeChecked();
      await expect(page.locator('input[value="tasks:update"]')).toBeChecked();
      
      // Click admin preset
      await page.click('button:has-text("관리자")');
      
      // Verify all permissions are selected
      const allCheckboxes = await page.locator('input[type="checkbox"][name^="role[permission_ids]"]').all();
      for (const checkbox of allCheckboxes) {
        await expect(checkbox).toBeChecked();
      }
    });

    test('should filter permissions by resource', async ({ page }) => {
      await page.goto(`${TENANT_URL}/organization/roles/new`);
      
      // Filter by tasks
      await page.selectOption('select#resource-filter', 'tasks');
      
      // Verify only task permissions are visible
      await expect(page.locator('label:has-text("tasks:")')).toBeVisible();
      await expect(page.locator('label:has-text("projects:")')).not.toBeVisible();
      
      // Filter by members
      await page.selectOption('select#resource-filter', 'members');
      
      // Verify only member permissions are visible
      await expect(page.locator('label:has-text("members:")')).toBeVisible();
      await expect(page.locator('label:has-text("tasks:")')).not.toBeVisible();
    });
  });

  test.describe('Member Role Management', () => {
    test('should assign role to member', async ({ page }) => {
      await page.goto(`${TENANT_URL}/organization/members`);
      
      // Find a member and click edit
      const memberRow = page.locator('tr').filter({ hasText: 'member@example.com' }).first();
      await memberRow.locator('button:has-text("역할 변경")').click();
      
      // Select new role
      await page.selectOption('select[name="membership[role_id]"]', { label: 'Updated Manager' });
      
      // Save changes
      await page.click('button:has-text("저장")');
      
      // Verify role was assigned
      await expect(memberRow.locator('text=Updated Manager')).toBeVisible();
    });

    test('should toggle member active status', async ({ page }) => {
      await page.goto(`${TENANT_URL}/organization/members`);
      
      // Find a member and toggle status
      const memberRow = page.locator('tr').filter({ hasText: 'member@example.com' }).first();
      const toggleButton = memberRow.locator('button[data-action="toggle-active"]');
      
      // Check initial state and toggle
      const initialState = await toggleButton.textContent();
      await toggleButton.click();
      
      // Verify status changed
      const newState = await toggleButton.textContent();
      expect(newState).not.toBe(initialState);
    });

    test('should invite new member with role', async ({ page }) => {
      await page.goto(`${TENANT_URL}/organization/members`);
      
      // Click invite button
      await page.click('button:has-text("멤버 초대")');
      
      // Fill invite form
      await page.fill('input[name="email"]', 'newmember@example.com');
      await page.selectOption('select[name="role_id"]', { label: 'Updated Manager' });
      
      // Send invitation
      await page.click('button:has-text("초대 보내기")');
      
      // Verify invitation was sent
      await expect(page.locator('text=초대가 발송되었습니다')).toBeVisible();
    });
  });

  test.describe('Permission Audit Logs', () => {
    test('should display audit logs', async ({ page }) => {
      await page.goto(`${TENANT_URL}/organization/permission_audit_logs`);
      
      // Verify audit log page loads
      await expect(page.locator('h1:has-text("권한 감사 로그")')).toBeVisible();
      
      // Verify statistics cards are visible
      await expect(page.locator('text=총 권한 체크')).toBeVisible();
      await expect(page.locator('text=허용됨')).toBeVisible();
      await expect(page.locator('text=거부됨')).toBeVisible();
      
      // Verify audit log table exists
      await expect(page.locator('table')).toBeVisible();
    });

    test('should filter audit logs', async ({ page }) => {
      await page.goto(`${TENANT_URL}/organization/permission_audit_logs`);
      
      // Filter by action
      await page.selectOption('select[name="action"]', 'create');
      await page.click('button:has-text("필터 적용")');
      
      // Verify filtered results
      await page.waitForLoadState('networkidle');
      const actionCells = await page.locator('td:has-text("create")').all();
      expect(actionCells.length).toBeGreaterThan(0);
      
      // Filter by result
      await page.selectOption('select[name="permitted"]', 'true');
      await page.click('button:has-text("필터 적용")');
      
      // Verify only permitted actions shown
      await page.waitForLoadState('networkidle');
      await expect(page.locator('span:has-text("허용")')).toBeVisible();
    });

    test('should export audit logs', async ({ page }) => {
      await page.goto(`${TENANT_URL}/organization/permission_audit_logs`);
      
      // Start download promise before clicking
      const downloadPromise = page.waitForEvent('download');
      
      // Click export button
      await page.click('a:has-text("CSV 내보내기")');
      
      // Wait for download
      const download = await downloadPromise;
      
      // Verify download
      expect(download.suggestedFilename()).toContain('.csv');
    });

    test('should view audit log details', async ({ page }) => {
      await page.goto(`${TENANT_URL}/organization/permission_audit_logs`);
      
      // Click on first log detail link
      await page.click('a:has-text("상세")').first();
      
      // Verify detail page loads
      await expect(page.locator('h1:has-text("감사 로그 상세")')).toBeVisible();
      await expect(page.locator('text=Context')).toBeVisible();
    });
  });

  test.describe('Multi-Tenant Isolation', () => {
    test('should enforce organization isolation', async ({ page, context }) => {
      // Create another organization context
      const anotherOrgUrl = 'http://another-org.localhost:3000';
      
      // Try to access another organization's data
      const response = await page.goto(`${anotherOrgUrl}/organization/roles`);
      
      // Should redirect to login or show access denied
      expect(response.status()).toBe(404); // or 403 depending on implementation
    });

    test('should switch between organizations', async ({ page }) => {
      await page.goto(`${BASE_URL}/organizations`);
      
      // Verify multiple organizations if user has access
      const orgCards = await page.locator('.organization-card').all();
      
      if (orgCards.length > 1) {
        // Click switch on another organization
        await orgCards[1].locator('button:has-text("전환")').click();
        
        // Verify switched to new organization
        await page.waitForURL(/\/dashboard/);
        const currentOrg = await page.locator('[data-current-organization]').textContent();
        expect(currentOrg).toBeTruthy();
      }
    });
  });

  test.describe('Permission Enforcement', () => {
    test('should enforce read permissions', async ({ page }) => {
      // Login as user with limited permissions
      await page.goto(`${BASE_URL}/users/logout`);
      await page.goto(`${BASE_URL}/users/login`);
      await page.fill('input[name="user[email]"]', 'readonly@example.com');
      await page.fill('input[name="user[password]"]', 'password123');
      await page.click('button[type="submit"]');
      
      // Try to access tasks (should work if has read permission)
      await page.goto(`${TENANT_URL}/tasks`);
      await expect(page.locator('h1:has-text("Tasks")')).toBeVisible();
      
      // Try to create task (should fail)
      const createButton = page.locator('a:has-text("New Task")');
      await expect(createButton).not.toBeVisible();
    });

    test('should enforce write permissions', async ({ page }) => {
      // Login as editor
      await page.goto(`${BASE_URL}/users/logout`);
      await page.goto(`${BASE_URL}/users/login`);
      await page.fill('input[name="user[email]"]', 'editor@example.com');
      await page.fill('input[name="user[password]"]', 'password123');
      await page.click('button[type="submit"]');
      
      // Should be able to create tasks
      await page.goto(`${TENANT_URL}/tasks`);
      await expect(page.locator('a:has-text("New Task")')).toBeVisible();
      
      // Should not be able to manage roles
      await page.goto(`${TENANT_URL}/organization/roles`);
      expect(page.url()).not.toContain('/roles');
    });
  });
});

// Helper function tests
test.describe('RBAC Helper Functions', () => {
  test('should check permissions correctly', async ({ page }) => {
    await page.goto(`${TENANT_URL}/dashboard`);
    
    // Execute permission check via console
    const canManageRoles = await page.evaluate(() => {
      // This would need to be exposed via window object in the app
      return window.checkPermission && window.checkPermission('roles', 'manage');
    });
    
    // Admin should be able to manage roles
    expect(canManageRoles).toBe(true);
  });
});