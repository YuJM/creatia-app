require 'rails_helper'

RSpec.describe Role, type: :model do
  let(:organization) { create(:organization) }
  let(:role) { create(:role, organization: organization) }
  
  before do
    ActsAsTenant.current_tenant = organization
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:key) }
    
    it 'validates uniqueness of key within organization' do
      existing_role = create(:role, organization: organization, key: 'admin')
      new_role = build(:role, organization: organization, key: 'admin')
      
      expect(new_role).not_to be_valid
      expect(new_role.errors[:key]).to include('has already been taken')
    end
    
    it 'allows same key in different organizations' do
      other_org = create(:organization)
      role1 = create(:role, organization: organization, key: 'manager')
      role2 = build(:role, organization: other_org, key: 'manager')
      
      expect(role2).to be_valid
    end
  end

  describe 'associations' do
    it { should belong_to(:organization) }
    it { should have_many(:role_permissions).dependent(:destroy) }
    it { should have_many(:permissions).through(:role_permissions) }
    it { should have_many(:organization_memberships).dependent(:nullify) }
    it { should have_many(:permission_delegations).dependent(:destroy) }
  end

  describe 'scopes' do
    let!(:system_role) { create(:role, organization: organization, system_role: true) }
    let!(:editable_role) { create(:role, organization: organization, editable: true) }
    let!(:non_editable_role) { create(:role, organization: organization, editable: false) }
    let!(:high_priority_role) { create(:role, organization: organization, priority: 100) }
    
    describe '.system' do
      it 'returns only system roles' do
        expect(Role.system).to include(system_role)
        expect(Role.system).not_to include(editable_role)
      end
    end
    
    describe '.custom' do
      it 'returns only non-system roles' do
        expect(Role.custom).to include(editable_role)
        expect(Role.custom).not_to include(system_role)
      end
    end
    
    describe '.editable' do
      it 'returns only editable roles' do
        expect(Role.editable).to include(editable_role)
        expect(Role.editable).not_to include(non_editable_role)
      end
    end
    
    describe '.by_priority' do
      it 'orders roles by priority descending' do
        roles = Role.by_priority
        expect(roles.first.priority).to be >= roles.last.priority
      end
    end
  end

  describe '#add_permission' do
    let(:permission) { create(:permission, resource: 'Task', action: 'read') }
    
    it 'adds a permission to the role' do
      expect {
        role.add_permission(permission)
      }.to change { role.permissions.count }.by(1)
      
      expect(role.permissions).to include(permission)
    end
    
    it 'does not add duplicate permissions' do
      role.add_permission(permission)
      
      expect {
        role.add_permission(permission)
      }.not_to change { role.permissions.count }
    end
    
    it 'allows adding conditions and scope' do
      conditions = { 'own_only' => true }
      scope = { 'service_ids' => [1, 2, 3] }
      
      role_permission = role.add_permission(permission, conditions: conditions, scope: scope)
      
      expect(role_permission.conditions).to eq(conditions)
      expect(role_permission.scope).to eq(scope)
    end
  end

  describe '#remove_permission' do
    let(:permission) { create(:permission, resource: 'Task', action: 'read') }
    
    before do
      role.add_permission(permission)
    end
    
    it 'removes a permission from the role' do
      expect {
        role.remove_permission(permission)
      }.to change { role.permissions.count }.by(-1)
      
      expect(role.permissions).not_to include(permission)
    end
    
    it 'handles removing non-existent permissions gracefully' do
      other_permission = create(:permission, resource: 'Service', action: 'read')
      
      expect {
        role.remove_permission(other_permission)
      }.not_to change { role.permissions.count }
    end
  end

  describe '#has_permission?' do
    let(:read_permission) { create(:permission, resource: 'Task', action: 'read') }
    let(:write_permission) { create(:permission, resource: 'Task', action: 'write') }
    
    before do
      role.add_permission(read_permission)
    end
    
    it 'returns true for permissions the role has' do
      expect(role.has_permission?('Task', 'read')).to be true
    end
    
    it 'returns false for permissions the role does not have' do
      expect(role.has_permission?('Task', 'write')).to be false
    end
    
    it 'is case-insensitive for resource and action' do
      expect(role.has_permission?('task', 'READ')).to be true
    end
  end

  describe '#duplicate' do
    let(:permission1) { create(:permission, resource: 'Task', action: 'read') }
    let(:permission2) { create(:permission, resource: 'Task', action: 'write') }
    
    before do
      role.add_permission(permission1, conditions: { 'own_only' => true })
      role.add_permission(permission2)
    end
    
    it 'creates a new role with the same permissions' do
      new_role = role.duplicate('New Role')
      
      expect(new_role.name).to eq('New Role')
      expect(new_role.key).to match(/new_role_\d+/)
      expect(new_role.permissions).to match_array(role.permissions)
    end
    
    it 'preserves permission conditions and scope' do
      new_role = role.duplicate('New Role')
      
      original_rp = role.role_permissions.find_by(permission: permission1)
      new_rp = new_role.role_permissions.find_by(permission: permission1)
      
      expect(new_rp.conditions).to eq(original_rp.conditions)
      expect(new_rp.scope).to eq(original_rp.scope)
    end
    
    it 'marks the new role as editable and non-system' do
      new_role = role.duplicate('New Role')
      
      expect(new_role.editable).to be true
      expect(new_role.system_role).to be false
    end
  end

  describe '#editable?' do
    it 'returns true for editable roles' do
      role.editable = true
      expect(role.editable?).to be true
    end
    
    it 'returns false for non-editable roles' do
      role.editable = false
      expect(role.editable?).to be false
    end
    
    it 'returns false for system roles regardless of editable flag' do
      role.editable = true
      role.system_role = true
      expect(role.editable?).to be false
    end
  end

  describe '#admin_level?' do
    it 'returns true for high priority roles (>= 80)' do
      role.priority = 80
      expect(role.admin_level?).to be true
      
      role.priority = 100
      expect(role.admin_level?).to be true
    end
    
    it 'returns false for low priority roles (< 80)' do
      role.priority = 79
      expect(role.admin_level?).to be false
      
      role.priority = 50
      expect(role.admin_level?).to be false
    end
  end

  describe '#owner_level?' do
    it 'returns true for highest priority roles (>= 100)' do
      role.priority = 100
      expect(role.owner_level?).to be true
      
      role.priority = 150
      expect(role.owner_level?).to be true
    end
    
    it 'returns false for lower priority roles (< 100)' do
      role.priority = 99
      expect(role.owner_level?).to be false
      
      role.priority = 80
      expect(role.owner_level?).to be false
    end
  end

  describe 'callbacks' do
    describe 'before_destroy' do
      it 'prevents deletion of system roles' do
        system_role = create(:role, organization: organization, system_role: true)
        
        expect {
          system_role.destroy
        }.not_to change { Role.count }
        
        expect(system_role.errors[:base]).to include('System roles cannot be deleted')
      end
      
      it 'prevents deletion of roles with active memberships' do
        user = create(:user)
        membership = create(:organization_membership, 
          user: user, 
          organization: organization, 
          role_id: role.id
        )
        
        expect {
          role.destroy
        }.not_to change { Role.count }
        
        expect(role.errors[:base]).to include('Cannot delete role with active memberships')
      end
      
      it 'allows deletion of custom roles without memberships' do
        custom_role = create(:role, organization: organization, system_role: false)
        
        expect {
          custom_role.destroy
        }.to change { Role.count }.by(-1)
      end
    end
  end

  describe 'factory' do
    it 'creates a valid role' do
      expect(role).to be_valid
    end
    
    it 'generates unique keys' do
      role1 = create(:role, organization: organization)
      role2 = create(:role, organization: organization)
      
      expect(role1.key).not_to eq(role2.key)
    end
  end
end