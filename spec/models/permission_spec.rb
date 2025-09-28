require 'rails_helper'

RSpec.describe Permission, type: :model do
  let(:permission) { create(:permission) }

  describe 'validations' do
    it { should validate_presence_of(:resource) }
    it { should validate_presence_of(:action) }
    
    it 'validates uniqueness of resource and action combination' do
      existing = create(:permission, resource: 'Task', action: 'read')
      duplicate = build(:permission, resource: 'Task', action: 'read')
      
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:action]).to include('has already been taken')
    end
    
    it 'allows same action for different resources' do
      perm1 = create(:permission, resource: 'Task', action: 'read')
      perm2 = build(:permission, resource: 'Service', action: 'read')
      
      expect(perm2).to be_valid
    end
    
    it 'allows same resource with different actions' do
      perm1 = create(:permission, resource: 'Task', action: 'read')
      perm2 = build(:permission, resource: 'Task', action: 'write')
      
      expect(perm2).to be_valid
    end
  end

  describe 'associations' do
    it { should have_many(:role_permissions).dependent(:destroy) }
    it { should have_many(:roles).through(:role_permissions) }
    it { should have_many(:resource_permissions).dependent(:destroy) }
  end

  describe 'scopes' do
    let!(:task_permissions) do
      [
        create(:permission, resource: 'Task', action: 'read'),
        create(:permission, resource: 'Task', action: 'write'),
        create(:permission, resource: 'Task', action: 'delete')
      ]
    end
    
    let!(:service_permissions) do
      [
        create(:permission, resource: 'Service', action: 'read'),
        create(:permission, resource: 'Service', action: 'manage')
      ]
    end
    
    describe '.for_resource' do
      it 'returns permissions for specific resource' do
        task_perms = Permission.for_resource('Task')
        expect(task_perms.count).to eq(3)
        expect(task_perms.pluck(:resource).uniq).to eq(['Task'])
      end
      
      it 'is case-insensitive' do
        task_perms = Permission.for_resource('task')
        expect(task_perms.count).to eq(3)
      end
    end
    
    describe '.for_action' do
      it 'returns permissions for specific action' do
        read_perms = Permission.for_action('read')
        expect(read_perms.count).to eq(2)
        expect(read_perms.pluck(:action).uniq).to eq(['read'])
      end
      
      it 'is case-insensitive' do
        read_perms = Permission.for_action('READ')
        expect(read_perms.count).to eq(2)
      end
    end
    
    describe '.crud' do
      let!(:crud_permissions) do
        %w[create read update delete].map do |action|
          create(:permission, resource: 'Post', action: action)
        end
      end
      
      it 'returns only CRUD permissions' do
        crud = Permission.crud
        expect(crud.pluck(:action)).to include('create', 'read', 'update', 'delete')
        expect(crud.pluck(:action)).not_to include('manage', 'write')
      end
    end
  end

  describe '#display_name' do
    it 'returns formatted permission name' do
      perm = create(:permission, resource: 'Task', action: 'read')
      expect(perm.display_name).to eq('Task - Read')
    end
    
    it 'capitalizes resource and action' do
      perm = create(:permission, resource: 'task', action: 'read')
      expect(perm.display_name).to eq('Task - Read')
    end
  end

  describe '#full_key' do
    it 'returns resource:action format' do
      perm = create(:permission, resource: 'Task', action: 'read')
      expect(perm.full_key).to eq('Task:read')
    end
  end

  describe '#crud?' do
    it 'returns true for CRUD actions' do
      %w[create read update delete].each do |action|
        perm = build(:permission, action: action)
        expect(perm.crud?).to be true
      end
    end
    
    it 'returns false for non-CRUD actions' do
      %w[manage execute approve publish].each do |action|
        perm = build(:permission, action: action)
        expect(perm.crud?).to be false
      end
    end
  end

  describe '#management?' do
    it 'returns true for management actions' do
      %w[manage administer control].each do |action|
        perm = build(:permission, action: action)
        expect(perm.management?).to be true
      end
    end
    
    it 'returns false for non-management actions' do
      %w[read write delete].each do |action|
        perm = build(:permission, action: action)
        expect(perm.management?).to be false
      end
    end
  end

  describe '#custom?' do
    it 'returns true for custom actions' do
      %w[approve publish execute review].each do |action|
        perm = build(:permission, action: action)
        expect(perm.custom?).to be true
      end
    end
    
    it 'returns false for standard actions' do
      %w[create read update delete manage].each do |action|
        perm = build(:permission, action: action)
        expect(perm.custom?).to be false
      end
    end
  end

  describe 'class methods' do
    describe '.create_crud_for' do
      it 'creates all CRUD permissions for a resource' do
        expect {
          Permission.create_crud_for('Article')
        }.to change { Permission.count }.by(4)
        
        perms = Permission.for_resource('Article')
        expect(perms.pluck(:action)).to match_array(%w[create read update delete])
      end
      
      it 'skips existing permissions' do
        create(:permission, resource: 'Article', action: 'read')
        
        expect {
          Permission.create_crud_for('Article')
        }.to change { Permission.count }.by(3)
      end
      
      it 'returns created permissions' do
        perms = Permission.create_crud_for('Article')
        expect(perms.count).to eq(4)
        expect(perms.all? { |p| p.resource == 'Article' }).to be true
      end
    end
    
    describe '.seed_defaults' do
      it 'creates default permissions for standard resources' do
        expect {
          Permission.seed_defaults
        }.to change { Permission.count }
        
        # Check that permissions are created for standard resources
        expect(Permission.for_resource('Organization').count).to be > 0
        expect(Permission.for_resource('Task').count).to be > 0
        expect(Permission.for_resource('Service').count).to be > 0
      end
      
      it 'is idempotent' do
        Permission.seed_defaults
        count = Permission.count
        
        Permission.seed_defaults
        expect(Permission.count).to eq(count)
      end
    end
  end

  describe 'callbacks' do
    describe 'before_destroy' do
      it 'prevents deletion if permission is in use by roles' do
        role = create(:role, organization: create(:organization))
        role.add_permission(permission)
        
        expect {
          permission.destroy
        }.not_to change { Permission.count }
        
        expect(permission.errors[:base]).to include('Cannot delete permission that is in use')
      end
      
      it 'allows deletion if permission is not in use' do
        unused = create(:permission, resource: 'Unused', action: 'test')
        
        expect {
          unused.destroy
        }.to change { Permission.count }.by(-1)
      end
    end
    
    describe 'after_create' do
      it 'normalizes resource and action to consistent case' do
        perm = Permission.create!(resource: 'task', action: 'READ')
        perm.reload
        
        # Assuming normalization to PascalCase for resource, lowercase for action
        expect(perm.resource).to eq('Task')
        expect(perm.action).to eq('read')
      end
    end
  end

  describe 'factory' do
    it 'creates a valid permission' do
      expect(permission).to be_valid
    end
    
    it 'generates unique resource-action combinations' do
      perm1 = create(:permission)
      perm2 = create(:permission)
      
      expect([perm1.resource, perm1.action]).not_to eq([perm2.resource, perm2.action])
    end
  end
end