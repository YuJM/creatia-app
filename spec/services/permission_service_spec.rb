require 'rails_helper'

RSpec.describe PermissionService, type: :service do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let(:task) { create(:task, organization: organization) }
  let(:service_obj) { create(:service, organization: organization) }
  
  before do
    ActsAsTenant.current_tenant = organization
  end

  describe '#initialize' do
    it 'initializes with user and organization' do
      service = PermissionService.new(user, organization)
      expect(service.user).to eq(user)
      expect(service.organization).to eq(organization)
    end

    it 'uses current tenant if organization not provided' do
      service = PermissionService.new(user)
      expect(service.organization).to eq(organization)
    end
  end

  describe 'Task permissions' do
    let(:service) { PermissionService.new(user, organization) }

    context 'as owner' do
      let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'owner') }

      it 'can view, edit, and delete tasks' do
        expect(service.can_view_task?(task)).to be true
        expect(service.can_edit_task?(task)).to be true
        expect(service.can_delete_task?(task)).to be true
      end
    end

    context 'as member' do
      let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'member') }

      it 'can view and edit but not delete tasks' do
        own_task = create(:task, organization: organization, assignee_id: user.id)
        
        expect(service.can_view_task?(own_task)).to be true
        expect(service.can_edit_task?(own_task)).to be true
        expect(service.can_delete_task?(own_task)).to be false
      end
    end

    context 'as viewer' do
      let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'viewer') }

      it 'can only view tasks' do
        expect(service.can_view_task?(task)).to be true
        expect(service.can_edit_task?(task)).to be false
        expect(service.can_delete_task?(task)).to be false
      end
    end

    context 'without membership' do
      it 'cannot access tasks' do
        expect(service.can_view_task?(task)).to be false
        expect(service.can_edit_task?(task)).to be false
        expect(service.can_delete_task?(task)).to be false
      end
    end

    context 'with task from another organization' do
      let(:other_org) { create(:organization) }
      let(:other_task) { create(:task, organization: other_org) }
      let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'owner') }

      it 'cannot access tasks from other organizations' do
        expect(service.can_view_task?(other_task)).to be false
        expect(service.can_edit_task?(other_task)).to be false
        expect(service.can_delete_task?(other_task)).to be false
      end
    end
  end

  describe 'Service permissions' do
    let(:service) { PermissionService.new(user, organization) }

    context 'as owner' do
      let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'owner') }

      it 'can view and edit services' do
        expect(service.can_view_service?(service_obj)).to be true
        expect(service.can_edit_service?(service_obj)).to be true
      end
    end

    context 'as member' do
      let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'member') }

      it 'can view but not edit services' do
        expect(service.can_view_service?(service_obj)).to be true
        expect(service.can_edit_service?(service_obj)).to be false
      end
    end
  end

  describe 'Organization management permissions' do
    let(:service) { PermissionService.new(user, organization) }

    context 'as owner' do
      let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'owner') }

      it 'can manage organization, members, and roles' do
        expect(service.can_manage_organization?).to be true
        expect(service.can_manage_members?).to be true
        expect(service.can_manage_roles?).to be true
      end
    end

    context 'as admin' do
      let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'admin') }

      it 'can manage members and roles but not organization' do
        expect(service.can_manage_organization?).to be false
        expect(service.can_manage_members?).to be true
        expect(service.can_manage_roles?).to be true
      end
    end

    context 'as member' do
      let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'member') }

      it 'cannot manage organization, members, or roles' do
        expect(service.can_manage_organization?).to be false
        expect(service.can_manage_members?).to be false
        expect(service.can_manage_roles?).to be false
      end
    end
  end

  describe 'Role-based checks' do
    let(:service) { PermissionService.new(user, organization) }

    context 'with owner role' do
      let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'owner') }

      it 'correctly identifies role' do
        expect(service.owner?).to be true
        expect(service.admin?).to be true # owner is also admin
        expect(service.member?).to be true # owner is also member
        expect(service.viewer?).to be false
      end
    end

    context 'with admin role' do
      let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'admin') }

      it 'correctly identifies role' do
        expect(service.owner?).to be false
        expect(service.admin?).to be true
        expect(service.member?).to be true
        expect(service.viewer?).to be false
      end
    end

    context 'with member role' do
      let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'member') }

      it 'correctly identifies role' do
        expect(service.owner?).to be false
        expect(service.admin?).to be false
        expect(service.member?).to be true
        expect(service.viewer?).to be false
      end
    end

    context 'with viewer role' do
      let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'viewer') }

      it 'correctly identifies role' do
        expect(service.owner?).to be false
        expect(service.admin?).to be false
        expect(service.member?).to be false
        expect(service.viewer?).to be true
      end
    end

    context 'with dynamic role' do
      let(:custom_role) { create(:role, organization: organization, key: 'custom_admin', priority: 85) }
      let!(:membership) { create(:organization_membership, user: user, organization: organization, role_id: custom_role.id) }

      it 'works with dynamic roles' do
        # Custom role with admin-like priority
        expect(service.owner?).to be false
        expect(service.admin?).to be false # Needs key to be 'admin' or 'owner'
        
        # Update role key to admin
        custom_role.update!(key: 'admin')
        new_service = PermissionService.new(user, organization)
        expect(new_service.admin?).to be true
      end
    end
  end

  describe 'Permission caching' do
    let(:service) { PermissionService.new(user, organization) }
    let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'member') }

    it 'caches permissions' do
      expect(Rails.cache).to receive(:fetch).with(
        "permissions:#{organization.id}:#{user.id}:member",
        expires_in: 5.minutes
      ).and_call_original

      service.cached_permissions
    end

    it 'clears cache when requested' do
      cache_key = "permissions:#{organization.id}:#{user.id}:member"
      
      # Prime the cache
      service.cached_permissions
      
      expect(Rails.cache).to receive(:delete).with(cache_key)
      service.clear_cache!
    end

    it 'reloads permissions after cache clear' do
      # Prime the cache
      initial_permissions = service.cached_permissions
      
      # Clear cache
      service.clear_cache!
      
      # Should reload from database
      expect(service).to receive(:load_permissions).and_call_original
      service.cached_permissions
    end
  end

  describe 'Available permissions' do
    let(:service) { PermissionService.new(user, organization) }

    context 'with legacy role' do
      let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'admin') }

      it 'returns appropriate permissions for legacy roles' do
        permissions = service.available_permissions
        expect(permissions).to be_a(ActiveRecord::Relation)
        expect(permissions.pluck(:action)).to include('read', 'create', 'update', 'manage')
      end
    end

    context 'with dynamic role' do
      let(:custom_role) { create(:role, organization: organization) }
      let(:permission1) { create(:permission, resource: 'Task', action: 'read') }
      let(:permission2) { create(:permission, resource: 'Task', action: 'create') }
      let!(:membership) { create(:organization_membership, user: user, organization: organization, role_id: custom_role.id) }

      before do
        custom_role.add_permission(permission1)
        custom_role.add_permission(permission2)
      end

      it 'returns permissions from the dynamic role' do
        permissions = service.available_permissions
        expect(permissions).to include(permission1, permission2)
      end
    end
  end

  describe 'Delegated permissions' do
    let(:service) { PermissionService.new(user, organization) }
    let(:delegator) { create(:user) }
    let(:admin_role) { create(:role, organization: organization, key: 'admin', priority: 80) }
    let!(:delegator_membership) { create(:organization_membership, user: delegator, organization: organization, role: 'owner') }
    let!(:user_membership) { create(:organization_membership, user: user, organization: organization, role: 'member') }

    context 'with active delegation' do
      let!(:delegation) do
        create(:permission_delegation,
          organization: organization,
          delegator: delegator,
          delegatee: user,
          role: admin_role,
          starts_at: 1.day.ago,
          ends_at: 1.day.from_now
        )
      end

      it 'has delegated permissions' do
        expect(service.has_delegated_permission?(Task, 'manage')).to be true
      end
    end

    context 'with expired delegation' do
      let!(:delegation) do
        create(:permission_delegation,
          organization: organization,
          delegator: delegator,
          delegatee: user,
          role: admin_role,
          starts_at: 3.days.ago,
          ends_at: 1.day.ago
        )
      end

      it 'does not have delegated permissions' do
        expect(service.has_delegated_permission?(Task, 'manage')).to be false
      end
    end
  end

  describe 'Audit logging' do
    let(:service) { PermissionService.new(user, organization) }
    let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'member') }

    it 'logs permission checks' do
      expect {
        service.log_permission_check('read', task, true)
      }.to change { PermissionAuditLog.count }.by(1)

      log = PermissionAuditLog.last
      expect(log.user).to eq(user)
      expect(log.organization).to eq(organization)
      expect(log.action).to eq('read')
      expect(log.resource).to eq(task)
      expect(log.permitted).to be true
    end

    it 'handles logging errors gracefully' do
      allow(PermissionAuditLog).to receive(:create!).and_raise(StandardError, 'Database error')
      
      expect(Rails.logger).to receive(:error).with(/Failed to log permission check/)
      expect {
        service.log_permission_check('read', task, true)
      }.not_to raise_error
    end
  end

  describe 'Edge cases' do
    let(:service) { PermissionService.new(user, organization) }

    it 'handles nil task gracefully' do
      expect(service.can_view_task?(nil)).to be false
      expect(service.can_edit_task?(nil)).to be false
      expect(service.can_delete_task?(nil)).to be false
    end

    it 'handles nil organization gracefully' do
      service_without_org = PermissionService.new(user, nil)
      expect(service_without_org.can_manage_organization?).to be false
      expect(service_without_org.can_manage_members?).to be false
    end

    it 'handles inactive membership' do
      create(:organization_membership, user: user, organization: organization, role: 'owner', active: false)
      
      expect(service.owner?).to be false
      expect(service.can_manage_organization?).to be false
    end
  end
end