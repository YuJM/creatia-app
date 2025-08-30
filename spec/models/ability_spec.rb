require 'rails_helper'

RSpec.describe Ability, type: :model do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let(:task) { create(:task, organization: organization) }
  let(:service) { create(:service, organization: organization) }
  
  before do
    ActsAsTenant.current_tenant = organization
  end

  describe 'Guest user abilities' do
    subject(:ability) { Ability.new(nil, organization) }

    it 'can read active organizations' do
      expect(ability).to be_able_to(:read, organization)
    end

    it 'cannot create tasks' do
      expect(ability).not_to be_able_to(:create, Task)
    end

    it 'cannot manage organizations' do
      expect(ability).not_to be_able_to(:manage, organization)
    end
  end

  describe 'Owner abilities' do
    let(:owner_role) { create(:role, organization: organization, key: 'owner', priority: 100) }
    let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'owner', role_id: owner_role.id) }
    
    subject(:ability) { Ability.new(user, organization) }

    it 'can manage everything' do
      expect(ability).to be_able_to(:manage, :all)
    end

    it 'can manage organization' do
      expect(ability).to be_able_to(:manage, organization)
      expect(ability).to be_able_to(:manage_settings, organization)
      expect(ability).to be_able_to(:manage_members, organization)
      expect(ability).to be_able_to(:manage_billing, organization)
    end

    it 'can manage tasks' do
      expect(ability).to be_able_to(:create, Task)
      expect(ability).to be_able_to(:read, task)
      expect(ability).to be_able_to(:update, task)
      expect(ability).to be_able_to(:destroy, task)
      expect(ability).to be_able_to(:assign, task)
    end
  end

  describe 'Admin abilities' do
    let(:admin_role) { create(:role, organization: organization, key: 'admin', priority: 80) }
    let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'admin', role_id: admin_role.id) }
    
    subject(:ability) { Ability.new(user, organization) }

    it 'can manage most things but not destroy organization' do
      expect(ability).to be_able_to(:manage, task)
      expect(ability).to be_able_to(:update, organization)
      expect(ability).not_to be_able_to(:destroy, organization)
    end

    it 'can manage members but not owner memberships' do
      owner_membership = create(:organization_membership, organization: organization, role: 'owner')
      regular_membership = create(:organization_membership, organization: organization, role: 'member')
      
      expect(ability).to be_able_to(:manage, regular_membership)
      expect(ability).not_to be_able_to(:update, owner_membership)
      expect(ability).not_to be_able_to(:destroy, owner_membership)
      expect(ability).not_to be_able_to(:change_role, owner_membership)
    end

    it 'can assign tasks and manage sprints' do
      expect(ability).to be_able_to(:assign, task)
      expect(ability).to be_able_to(:plan, Sprint)
      expect(ability).to be_able_to(:metrics, Sprint)
    end
  end

  describe 'Member abilities' do
    let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'member') }
    
    subject(:ability) { Ability.new(user, organization) }

    it 'can read and create tasks' do
      expect(ability).to be_able_to(:read, task)
      expect(ability).to be_able_to(:create, Task)
    end

    it 'can update their own tasks' do
      own_task = create(:task, organization: organization, assignee_id: user.id)
      created_task = create(:task, organization: organization, created_by_id: user.id)
      other_task = create(:task, organization: organization)
      
      expect(ability).to be_able_to(:update, own_task)
      expect(ability).to be_able_to(:update, created_task)
      expect(ability).not_to be_able_to(:update, other_task)
    end

    it 'cannot destroy anything' do
      expect(ability).not_to be_able_to(:destroy, organization)
      expect(ability).not_to be_able_to(:destroy, task)
      expect(ability).not_to be_able_to(:destroy, service)
    end

    it 'can manage their own membership with limitations' do
      own_membership = membership
      other_membership = create(:organization_membership, organization: organization)
      
      expect(ability).to be_able_to(:update, own_membership)
      expect(ability).to be_able_to(:destroy, own_membership)
      expect(ability).not_to be_able_to(:update, other_membership)
    end
  end

  describe 'Viewer abilities' do
    let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'viewer') }
    
    subject(:ability) { Ability.new(user, organization) }

    it 'can only read' do
      expect(ability).to be_able_to(:read, organization)
      expect(ability).to be_able_to(:read, task)
      expect(ability).to be_able_to(:read, service)
    end

    it 'cannot create, update, or destroy' do
      expect(ability).not_to be_able_to(:create, Task)
      expect(ability).not_to be_able_to(:update, task)
      expect(ability).not_to be_able_to(:destroy, task)
    end
  end

  describe 'Dynamic role permissions' do
    let(:custom_role) { create(:role, organization: organization, key: 'custom', priority: 50) }
    let(:read_permission) { create(:permission, resource: 'Task', action: 'read') }
    let(:create_permission) { create(:permission, resource: 'Task', action: 'create') }
    let!(:membership) { create(:organization_membership, user: user, organization: organization, role_id: custom_role.id) }
    
    before do
      custom_role.add_permission(read_permission)
      custom_role.add_permission(create_permission)
    end
    
    subject(:ability) { Ability.new(user, organization) }

    it 'loads permissions from database' do
      expect(ability).to be_able_to(:read, Task)
      expect(ability).to be_able_to(:create, Task)
      expect(ability).not_to be_able_to(:update, Task)
      expect(ability).not_to be_able_to(:destroy, Task)
    end
  end

  describe 'Permission delegation' do
    let(:delegator) { create(:user) }
    let(:delegatee) { user }
    let(:admin_role) { create(:role, organization: organization, key: 'admin', priority: 80) }
    let!(:delegator_membership) { create(:organization_membership, user: delegator, organization: organization, role: 'owner') }
    let!(:delegatee_membership) { create(:organization_membership, user: delegatee, organization: organization, role: 'member') }
    
    let!(:delegation) do
      create(:permission_delegation,
        organization: organization,
        delegator: delegator,
        delegatee: delegatee,
        role: admin_role,
        starts_at: 1.day.ago,
        ends_at: 1.day.from_now
      )
    end
    
    subject(:ability) { Ability.new(delegatee, organization) }

    it 'inherits delegated role permissions' do
      # Member normally cannot destroy tasks
      expect(ability).not_to be_able_to(:destroy, task)
      
      # But with admin delegation, they should be able to manage tasks
      delegation.update!(role_id: admin_role.id)
      new_ability = Ability.new(delegatee, organization)
      expect(new_ability).to be_able_to(:manage, task)
    end
  end

  describe 'Multi-tenant isolation' do
    let(:other_organization) { create(:organization) }
    let(:other_task) { create(:task, organization: other_organization) }
    let!(:membership) { create(:organization_membership, user: user, organization: organization, role: 'owner') }
    
    subject(:ability) { Ability.new(user, organization) }

    it 'cannot access resources from other organizations' do
      # Owner can manage tasks in their organization
      expect(ability).to be_able_to(:manage, task)
      
      # But not tasks from other organizations
      expect(ability).not_to be_able_to(:read, other_task)
      expect(ability).not_to be_able_to(:update, other_task)
    end
  end

  describe 'Organization switching' do
    let(:other_organization) { create(:organization) }
    let!(:membership1) { create(:organization_membership, user: user, organization: organization, role: 'owner') }
    let!(:membership2) { create(:organization_membership, user: user, organization: other_organization, role: 'member') }
    
    it 'can switch to organizations where user is a member' do
      ability = Ability.new(user, organization)
      expect(ability).to be_able_to(:switch, organization)
      expect(ability).to be_able_to(:switch, other_organization)
    end

    it 'cannot switch to organizations where user is not a member' do
      third_organization = create(:organization)
      ability = Ability.new(user, organization)
      expect(ability).not_to be_able_to(:switch, third_organization)
    end
  end

  describe 'Caching' do
    it 'caches permissions for performance' do
      # This is more of an integration test
      # We can verify that the PermissionService cache methods are called
      service = PermissionService.new(user, organization)
      expect(Rails.cache).to receive(:fetch).at_least(:once)
      service.cached_permissions
    end
  end
end