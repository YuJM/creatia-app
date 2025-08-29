import { test, expect, Page } from '@playwright/test';

// Test users with different roles
const TEST_USERS = {
  owner: {
    email: 'owner@example.com',
    password: 'password123',
    role: 'owner'
  },
  admin: {
    email: 'admin@example.com',
    password: 'password123',
    role: 'admin'
  },
  member: {
    email: 'member@example.com',
    password: 'password123',
    role: 'member'
  },
  viewer: {
    email: 'viewer@example.com',
    password: 'password123',
    role: 'viewer'
  }
};

// Helper function to login
async function login(page: Page, email: string, password: string) {
  await page.goto('/users/sign_in');
  await page.fill('input[name="user[email]"]', email);
  await page.fill('input[name="user[password]"]', password);
  await page.click('button[type="submit"]');
  await page.waitForURL('**/dashboard', { timeout: 10000 });
}

// Helper function to navigate to organization settings
async function navigateToOrgSettings(page: Page) {
  await page.click('[data-testid="org-settings-link"]');
  await page.waitForURL('**/settings');
}

// Helper function to navigate to members page
async function navigateToMembers(page: Page) {
  await page.click('[data-testid="members-link"]');
  await page.waitForURL('**/members');
}

test.describe('Organization Permissions', () => {
  test.describe('Owner Permissions', () => {
    test.beforeEach(async ({ page }) => {
      await login(page, TEST_USERS.owner.email, TEST_USERS.owner.password);
    });

    test('Owner can access organization settings', async ({ page }) => {
      await navigateToOrgSettings(page);
      
      // Check all settings sections are visible
      await expect(page.locator('[data-testid="general-settings"]')).toBeVisible();
      await expect(page.locator('[data-testid="billing-settings"]')).toBeVisible();
      await expect(page.locator('[data-testid="danger-zone"]')).toBeVisible();
    });

    test('Owner can manage members', async ({ page }) => {
      await navigateToMembers(page);
      
      // Check member management controls
      await expect(page.locator('[data-testid="invite-member-btn"]')).toBeVisible();
      await expect(page.locator('[data-testid="member-list"]')).toBeVisible();
      
      // Check role change dropdown for members
      const memberRow = page.locator('[data-testid="member-row"]').first();
      await expect(memberRow.locator('[data-testid="role-select"]')).toBeVisible();
      await expect(memberRow.locator('[data-testid="remove-member-btn"]')).toBeVisible();
    });

    test('Owner can delete organization', async ({ page }) => {
      await navigateToOrgSettings(page);
      
      // Check delete organization button exists
      await expect(page.locator('[data-testid="delete-org-btn"]')).toBeVisible();
    });
  });

  test.describe('Admin Permissions', () => {
    test.beforeEach(async ({ page }) => {
      await login(page, TEST_USERS.admin.email, TEST_USERS.admin.password);
    });

    test('Admin can manage members but not owner', async ({ page }) => {
      await navigateToMembers(page);
      
      // Check can invite members
      await expect(page.locator('[data-testid="invite-member-btn"]')).toBeVisible();
      
      // Check cannot modify owner role
      const ownerRow = page.locator('[data-testid="member-row"][data-role="owner"]');
      await expect(ownerRow.locator('[data-testid="role-select"]')).toBeDisabled();
      await expect(ownerRow.locator('[data-testid="remove-member-btn"]')).not.toBeVisible();
      
      // Check can modify other members
      const memberRow = page.locator('[data-testid="member-row"][data-role="member"]').first();
      await expect(memberRow.locator('[data-testid="role-select"]')).toBeEnabled();
      await expect(memberRow.locator('[data-testid="remove-member-btn"]')).toBeVisible();
    });

    test('Admin cannot access billing settings', async ({ page }) => {
      await navigateToOrgSettings(page);
      
      // Check billing section is not visible
      await expect(page.locator('[data-testid="billing-settings"]')).not.toBeVisible();
      await expect(page.locator('[data-testid="danger-zone"]')).not.toBeVisible();
    });

    test('Admin cannot delete organization', async ({ page }) => {
      await navigateToOrgSettings(page);
      
      // Check delete organization button doesn't exist
      await expect(page.locator('[data-testid="delete-org-btn"]')).not.toBeVisible();
    });
  });

  test.describe('Member Permissions', () => {
    test.beforeEach(async ({ page }) => {
      await login(page, TEST_USERS.member.email, TEST_USERS.member.password);
    });

    test('Member cannot access organization settings', async ({ page }) => {
      // Check settings link is not visible
      await expect(page.locator('[data-testid="org-settings-link"]')).not.toBeVisible();
    });

    test('Member can view but not manage members', async ({ page }) => {
      await navigateToMembers(page);
      
      // Check member list is visible
      await expect(page.locator('[data-testid="member-list"]')).toBeVisible();
      
      // Check cannot invite members
      await expect(page.locator('[data-testid="invite-member-btn"]')).not.toBeVisible();
      
      // Check cannot modify any members
      const memberRows = page.locator('[data-testid="member-row"]');
      const count = await memberRows.count();
      for (let i = 0; i < count; i++) {
        await expect(memberRows.nth(i).locator('[data-testid="role-select"]')).not.toBeVisible();
        await expect(memberRows.nth(i).locator('[data-testid="remove-member-btn"]')).not.toBeVisible();
      }
    });

    test('Member can leave organization', async ({ page }) => {
      await page.click('[data-testid="user-menu"]');
      
      // Check leave organization option exists
      await expect(page.locator('[data-testid="leave-org-btn"]')).toBeVisible();
    });
  });

  test.describe('Viewer Permissions', () => {
    test.beforeEach(async ({ page }) => {
      await login(page, TEST_USERS.viewer.email, TEST_USERS.viewer.password);
    });

    test('Viewer has read-only access', async ({ page }) => {
      // Check no create buttons are visible
      await expect(page.locator('[data-testid="create-task-btn"]')).not.toBeVisible();
      await expect(page.locator('[data-testid="create-project-btn"]')).not.toBeVisible();
    });

    test('Viewer cannot edit tasks', async ({ page }) => {
      // Navigate to a task
      await page.click('[data-testid="task-item"]').first();
      
      // Check edit controls are not visible
      await expect(page.locator('[data-testid="edit-task-btn"]')).not.toBeVisible();
      await expect(page.locator('[data-testid="delete-task-btn"]')).not.toBeVisible();
      await expect(page.locator('[data-testid="assign-task-btn"]')).not.toBeVisible();
    });

    test('Viewer cannot leave organization', async ({ page }) => {
      await page.click('[data-testid="user-menu"]');
      
      // Check leave organization option doesn't exist
      await expect(page.locator('[data-testid="leave-org-btn"]')).not.toBeVisible();
    });
  });
});

test.describe('Task Permissions', () => {
  test.describe('Task Creation', () => {
    test('Owner can create tasks', async ({ page }) => {
      await login(page, TEST_USERS.owner.email, TEST_USERS.owner.password);
      
      await expect(page.locator('[data-testid="create-task-btn"]')).toBeVisible();
      await page.click('[data-testid="create-task-btn"]');
      
      // Fill task form
      await page.fill('[data-testid="task-title"]', 'Test Task');
      await page.fill('[data-testid="task-description"]', 'Test Description');
      await page.click('[data-testid="submit-task-btn"]');
      
      // Check task created
      await expect(page.locator('text=Task created successfully')).toBeVisible();
    });

    test('Viewer cannot create tasks', async ({ page }) => {
      await login(page, TEST_USERS.viewer.email, TEST_USERS.viewer.password);
      
      await expect(page.locator('[data-testid="create-task-btn"]')).not.toBeVisible();
    });
  });

  test.describe('Task Assignment', () => {
    test('Admin can assign tasks to anyone', async ({ page }) => {
      await login(page, TEST_USERS.admin.email, TEST_USERS.admin.password);
      
      // Open task details
      await page.click('[data-testid="task-item"]').first();
      
      // Check assignee dropdown is enabled
      await expect(page.locator('[data-testid="assignee-select"]')).toBeEnabled();
      
      // Change assignee
      await page.selectOption('[data-testid="assignee-select"]', { label: 'Member User' });
      await expect(page.locator('text=Task assigned successfully')).toBeVisible();
    });

    test('Member can only self-assign', async ({ page }) => {
      await login(page, TEST_USERS.member.email, TEST_USERS.member.password);
      
      // Open unassigned task
      await page.click('[data-testid="unassigned-task"]').first();
      
      // Check can self-assign
      await expect(page.locator('[data-testid="self-assign-btn"]')).toBeVisible();
      
      // But cannot assign to others
      await expect(page.locator('[data-testid="assignee-select"]')).not.toBeVisible();
    });
  });

  test.describe('Task Completion', () => {
    test('Assigned user can complete task', async ({ page }) => {
      await login(page, TEST_USERS.member.email, TEST_USERS.member.password);
      
      // Open assigned task
      await page.click('[data-testid="my-task"]').first();
      
      // Check complete button is visible
      await expect(page.locator('[data-testid="complete-task-btn"]')).toBeVisible();
      
      // Complete task
      await page.click('[data-testid="complete-task-btn"]');
      await expect(page.locator('text=Task completed')).toBeVisible();
    });

    test('Non-assigned user cannot complete task', async ({ page }) => {
      await login(page, TEST_USERS.member.email, TEST_USERS.member.password);
      
      // Open task assigned to someone else
      await page.click('[data-testid="other-task"]').first();
      
      // Check complete button is not visible
      await expect(page.locator('[data-testid="complete-task-btn"]')).not.toBeVisible();
    });
  });
});

test.describe('Membership Management', () => {
  test.describe('Role Changes', () => {
    test('Owner can promote member to admin', async ({ page }) => {
      await login(page, TEST_USERS.owner.email, TEST_USERS.owner.password);
      await navigateToMembers(page);
      
      // Find member row
      const memberRow = page.locator('[data-testid="member-row"][data-role="member"]').first();
      
      // Change role to admin
      await memberRow.locator('[data-testid="role-select"]').selectOption('admin');
      await expect(page.locator('text=Role updated successfully')).toBeVisible();
      
      // Verify role changed
      await expect(memberRow.locator('[data-role="admin"]')).toBeVisible();
    });

    test('Admin cannot promote to owner', async ({ page }) => {
      await login(page, TEST_USERS.admin.email, TEST_USERS.admin.password);
      await navigateToMembers(page);
      
      // Find member row
      const memberRow = page.locator('[data-testid="member-row"][data-role="member"]').first();
      const roleSelect = memberRow.locator('[data-testid="role-select"]');
      
      // Check owner option is not available
      const options = await roleSelect.locator('option').allTextContents();
      expect(options).not.toContain('Owner');
    });
  });

  test.describe('Member Removal', () => {
    test('Owner can remove members', async ({ page }) => {
      await login(page, TEST_USERS.owner.email, TEST_USERS.owner.password);
      await navigateToMembers(page);
      
      // Find member to remove
      const memberRow = page.locator('[data-testid="member-row"][data-role="member"]').first();
      const memberName = await memberRow.locator('[data-testid="member-name"]').textContent();
      
      // Remove member
      await memberRow.locator('[data-testid="remove-member-btn"]').click();
      await page.locator('[data-testid="confirm-remove-btn"]').click();
      
      // Verify member removed
      await expect(page.locator('text=Member removed successfully')).toBeVisible();
      await expect(page.locator(`text=${memberName}`)).not.toBeVisible();
    });

    test('Admin cannot remove owner', async ({ page }) => {
      await login(page, TEST_USERS.admin.email, TEST_USERS.admin.password);
      await navigateToMembers(page);
      
      // Find owner row
      const ownerRow = page.locator('[data-testid="member-row"][data-role="owner"]');
      
      // Check remove button is not visible
      await expect(ownerRow.locator('[data-testid="remove-member-btn"]')).not.toBeVisible();
    });

    test('Member can leave organization', async ({ page }) => {
      await login(page, TEST_USERS.member.email, TEST_USERS.member.password);
      
      // Open user menu
      await page.click('[data-testid="user-menu"]');
      await page.click('[data-testid="leave-org-btn"]');
      
      // Confirm leaving
      await page.click('[data-testid="confirm-leave-btn"]');
      
      // Verify redirected to organizations list
      await expect(page).toHaveURL('**/organizations');
      await expect(page.locator('text=You have left the organization')).toBeVisible();
    });

    test('Owner cannot leave organization', async ({ page }) => {
      await login(page, TEST_USERS.owner.email, TEST_USERS.owner.password);
      
      // Open user menu
      await page.click('[data-testid="user-menu"]');
      
      // Check leave button is not available
      await expect(page.locator('[data-testid="leave-org-btn"]')).not.toBeVisible();
    });
  });
});

test.describe('Cross-Organization Isolation', () => {
  const ORG1_DOMAIN = 'org1.creatia.local';
  const ORG2_DOMAIN = 'org2.creatia.local';

  test('User cannot access resources from another organization', async ({ page }) => {
    // Login to org1
    await page.goto(`http://${ORG1_DOMAIN}:3000/users/sign_in`);
    await page.fill('input[name="user[email]"]', TEST_USERS.member.email);
    await page.fill('input[name="user[password]"]', TEST_USERS.member.password);
    await page.click('button[type="submit"]');
    
    // Get a task ID from org1
    await page.waitForURL(`http://${ORG1_DOMAIN}:3000/dashboard`);
    const taskUrl = await page.locator('[data-testid="task-item"]').first().getAttribute('href');
    const taskId = taskUrl?.split('/').pop();
    
    // Try to access the same task ID on org2
    await page.goto(`http://${ORG2_DOMAIN}:3000/tasks/${taskId}`);
    
    // Should get unauthorized or not found
    await expect(page.locator('text=Unauthorized')).toBeVisible();
  });

  test('Admin of one org cannot access another org', async ({ page }) => {
    // Login as admin of org1
    await page.goto(`http://${ORG1_DOMAIN}:3000/users/sign_in`);
    await page.fill('input[name="user[email]"]', TEST_USERS.admin.email);
    await page.fill('input[name="user[password]"]', TEST_USERS.admin.password);
    await page.click('button[type="submit"]');
    
    // Try to access org2 directly
    await page.goto(`http://${ORG2_DOMAIN}:3000/dashboard`);
    
    // Should be redirected to login or get unauthorized
    const url = page.url();
    expect(url).toContain('sign_in');
  });
});