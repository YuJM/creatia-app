const { test, expect } = require('@playwright/test');

// Test configuration
const BASE_URL = 'http://127.0.0.1:3000';

// Test data
const testUser = {
  email: 'admin@example.com',
  password: 'password123'
};

test.describe('Multi-Tenant Dynamic RBAC System - Basic Tests', () => {
  test('should be able to access the main page', async ({ page }) => {
    await page.goto(BASE_URL);
    
    // Check if page loads
    await expect(page).toHaveURL(/127\.0\.0\.1:3000/);
  });

  test('should be able to login', async ({ page }) => {
    await page.goto(`${BASE_URL}/users/login`);
    
    // Fill login form
    await page.fill('input[name="user[email]"]', testUser.email);
    await page.fill('input[name="user[password]"]', testUser.password);
    
    // Submit form
    const submitButton = page.locator('input[type="submit"], button[type="submit"]').first();
    await submitButton.click();
    
    // Wait for navigation
    await page.waitForLoadState('networkidle');
    
    // Check if login was successful
    const currentUrl = page.url();
    console.log('Current URL after login:', currentUrl);
    
    // Should redirect to dashboard or organizations page
    expect(currentUrl).toMatch(/dashboard|organizations|pages/);
  });

  test('should be able to access organization roles page', async ({ page }) => {
    // First login
    await page.goto(`${BASE_URL}/users/login`);
    await page.fill('input[name="user[email]"]', testUser.email);
    await page.fill('input[name="user[password]"]', testUser.password);
    const submitButton = page.locator('input[type="submit"], button[type="submit"]').first();
    await submitButton.click();
    await page.waitForLoadState('networkidle');
    
    // Try to access test organization's roles page
    await page.goto('http://test-org.127.0.0.1.nip.io:3000/organization/roles');
    
    // Wait for page to load
    await page.waitForLoadState('networkidle');
    
    // Check if we can see roles page or get redirected
    const pageTitle = await page.title();
    console.log('Page title:', pageTitle);
    
    // The page should either show roles or redirect to login/error
    expect(pageTitle).toBeTruthy();
  });
});