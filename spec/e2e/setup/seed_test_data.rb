#!/usr/bin/env ruby
# This script seeds test data for E2E tests

require_relative '../../../config/environment'

puts "Seeding test data for E2E tests..."

ActiveRecord::Base.transaction do
  # Create test organization
  test_org = Organization.find_or_create_by!(subdomain: 'test-org') do |org|
    org.name = 'Test Organization'
    org.plan = 'team'
  end

  # Create test users  
  admin_user = User.find_or_create_by!(email: 'admin@example.com') do |user|
    user.password = 'password123'
    user.password_confirmation = 'password123'
  end

  editor_user = User.find_or_create_by!(email: 'editor@example.com') do |user|
    user.password = 'password123'
    user.password_confirmation = 'password123'
  end

  readonly_user = User.find_or_create_by!(email: 'readonly@example.com') do |user|
    user.password = 'password123'
    user.password_confirmation = 'password123'
  end

  # Set organization context
  ActsAsTenant.with_tenant(test_org) do
    # Create roles
    owner_role = Role.find_or_create_by!(key: 'owner', organization: test_org) do |role|
      role.name = 'Owner'
      role.description = 'Full access to everything'
      role.system_role = true
      role.priority = 100
    end

    editor_role = Role.find_or_create_by!(key: 'editor', organization: test_org) do |role|
      role.name = 'Editor'
      role.description = 'Can create and edit content'
      role.system_role = false
      role.priority = 50
    end

    viewer_role = Role.find_or_create_by!(key: 'viewer', organization: test_org) do |role|
      role.name = 'Viewer'
      role.description = 'Read-only access'
      role.system_role = false
      role.priority = 10
    end

    # Create memberships
    OrganizationMembership.find_or_create_by!(
      user: admin_user,
      organization: test_org
    ) do |membership|
      membership.role_id = owner_role.id
      membership.active = true
    end

    OrganizationMembership.find_or_create_by!(
      user: editor_user,
      organization: test_org
    ) do |membership|
      membership.role_id = editor_role.id
      membership.active = true
    end

    OrganizationMembership.find_or_create_by!(
      user: readonly_user,
      organization: test_org
    ) do |membership|
      membership.role_id = viewer_role.id
      membership.active = true
    end

    # Create some tasks for testing
    3.times do |i|
      task = Task.where(
        title: "Test Task #{i + 1}",
        organization: test_org
      ).first
      
      if task.nil?
        Task.create!(
          title: "Test Task #{i + 1}",
          organization: test_org,
          description: "Description for test task #{i + 1}",
          status: ['todo', 'in_progress', 'done'].sample,
          assignee_id: [admin_user.id, editor_user.id].sample
        )
      end
    end
  end

  puts "Test data seeded successfully!"
  puts "Users created:"
  puts "  - admin@example.com (Owner in test-org)"
  puts "  - editor@example.com (Editor in test-org)"
  puts "  - readonly@example.com (Viewer in test-org)"
  puts "All passwords: password123"
  puts "Organization:"
  puts "  - test-org.creatia.local:3000"
end