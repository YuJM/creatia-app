require 'rails_helper'

RSpec.describe Mongodb::MongoTasksController, type: :controller do
  let(:organization) { create(:organization) }
  let(:service) { create(:service, organization: organization) }
  let(:owner) { create(:user) }
  let(:admin) { create(:user) }
  let(:member) { create(:user) }
  let(:viewer) { create(:user) }
  let(:non_member) { create(:user) }
  
  let!(:owner_membership) { create(:organization_membership, user: owner, organization: organization, role: 'owner') }
  let!(:admin_membership) { create(:organization_membership, user: admin, organization: organization, role: 'admin') }
  let!(:member_membership) { create(:organization_membership, user: member, organization: organization, role: 'member') }
  let!(:viewer_membership) { create(:organization_membership, user: viewer, organization: organization, role: 'viewer') }
  
  let(:task) { create(:mongo_task, organization: organization, service: service) }
  let(:member_task) { create(:mongo_task, organization: organization, service: service, assignee_id: member.id) }
  
  before do
    ActsAsTenant.current_tenant = organization
  end

  describe 'GET #index' do
    context 'as owner' do
      before { sign_in owner }
      
      it 'allows access' do
        get :index
        expect(response).to be_successful
      end
      
      it 'returns all tasks' do
        task1 = create(:mongo_task, organization: organization)
        task2 = create(:mongo_task, organization: organization)
        
        get :index
        expect(assigns(:tasks)).to include(task1, task2)
      end
    end
    
    context 'as admin' do
      before { sign_in admin }
      
      it 'allows access' do
        get :index
        expect(response).to be_successful
      end
    end
    
    context 'as member' do
      before { sign_in member }
      
      it 'allows access' do
        get :index
        expect(response).to be_successful
      end
    end
    
    context 'as viewer' do
      before { sign_in viewer }
      
      it 'allows access' do
        get :index
        expect(response).to be_successful
      end
    end
    
    context 'as non-member' do
      before { sign_in non_member }
      
      it 'denies access' do
        expect {
          get :index
        }.to raise_error(CanCan::AccessDenied)
      end
    end
    
    context 'without authentication' do
      it 'redirects to login' do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET #show' do
    context 'as owner' do
      before { sign_in owner }
      
      it 'allows access' do
        get :show, params: { id: task.id }
        expect(response).to be_successful
      end
    end
    
    context 'as viewer' do
      before { sign_in viewer }
      
      it 'allows access' do
        get :show, params: { id: task.id }
        expect(response).to be_successful
      end
    end
    
    context 'as non-member' do
      before { sign_in non_member }
      
      it 'denies access' do
        expect {
          get :show, params: { id: task.id }
        }.to raise_error(CanCan::AccessDenied)
      end
    end
  end

  describe 'GET #new' do
    context 'as owner' do
      before { sign_in owner }
      
      it 'allows access' do
        get :new
        expect(response).to be_successful
      end
    end
    
    context 'as member' do
      before { sign_in member }
      
      it 'allows access' do
        get :new
        expect(response).to be_successful
      end
    end
    
    context 'as viewer' do
      before { sign_in viewer }
      
      it 'denies access' do
        expect {
          get :new
        }.to raise_error(CanCan::AccessDenied)
      end
    end
  end

  describe 'POST #create' do
    let(:task_params) do
      {
        task: {
          title: 'New Mongodb::MongoTask',
          description: 'Mongodb::MongoTask description',
          service_id: service.id
        }
      }
    end
    
    context 'as owner' do
      before { sign_in owner }
      
      it 'allows creation' do
        expect {
          post :create, params: task_params
        }.to change { Mongodb::MongoTask.count }.by(1)
        
        expect(response).to redirect_to(task_path(Mongodb::MongoTask.last))
      end
    end
    
    context 'as member' do
      before { sign_in member }
      
      it 'allows creation' do
        expect {
          post :create, params: task_params
        }.to change { Mongodb::MongoTask.count }.by(1)
      end
    end
    
    context 'as viewer' do
      before { sign_in viewer }
      
      it 'denies creation' do
        expect {
          expect {
            post :create, params: task_params
          }.to raise_error(CanCan::AccessDenied)
        }.not_to change { Mongodb::MongoTask.count }
      end
    end
  end

  describe 'GET #edit' do
    context 'as owner' do
      before { sign_in owner }
      
      it 'allows access' do
        get :edit, params: { id: task.id }
        expect(response).to be_successful
      end
    end
    
    context 'as member (assigned task)' do
      before { sign_in member }
      
      it 'allows access to assigned task' do
        get :edit, params: { id: member_task.id }
        expect(response).to be_successful
      end
      
      it 'denies access to unassigned task' do
        expect {
          get :edit, params: { id: task.id }
        }.to raise_error(CanCan::AccessDenied)
      end
    end
    
    context 'as viewer' do
      before { sign_in viewer }
      
      it 'denies access' do
        expect {
          get :edit, params: { id: task.id }
        }.to raise_error(CanCan::AccessDenied)
      end
    end
  end

  describe 'PATCH #update' do
    let(:update_params) do
      {
        id: task.id,
        task: { title: 'Updated Title' }
      }
    end
    
    context 'as owner' do
      before { sign_in owner }
      
      it 'allows update' do
        patch :update, params: update_params
        expect(task.reload.title).to eq('Updated Title')
        expect(response).to redirect_to(task_path(task))
      end
    end
    
    context 'as admin' do
      before { sign_in admin }
      
      it 'allows update' do
        patch :update, params: update_params
        expect(task.reload.title).to eq('Updated Title')
      end
    end
    
    context 'as member (assigned task)' do
      before { sign_in member }
      
      it 'allows update of assigned task' do
        patch :update, params: { id: member_task.id, task: { title: 'Updated' } }
        expect(member_task.reload.title).to eq('Updated')
      end
      
      it 'denies update of unassigned task' do
        expect {
          patch :update, params: update_params
        }.to raise_error(CanCan::AccessDenied)
        
        expect(task.reload.title).not_to eq('Updated Title')
      end
    end
    
    context 'as viewer' do
      before { sign_in viewer }
      
      it 'denies update' do
        expect {
          patch :update, params: update_params
        }.to raise_error(CanCan::AccessDenied)
        
        expect(task.reload.title).not_to eq('Updated Title')
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'as owner' do
      before { sign_in owner }
      
      it 'allows deletion' do
        task # create task
        
        expect {
          delete :destroy, params: { id: task.id }
        }.to change { Mongodb::MongoTask.count }.by(-1)
        
        expect(response).to redirect_to(tasks_path)
      end
    end
    
    context 'as admin' do
      before { sign_in admin }
      
      it 'allows deletion' do
        task # create task
        
        expect {
          delete :destroy, params: { id: task.id }
        }.to change { Mongodb::MongoTask.count }.by(-1)
      end
    end
    
    context 'as member' do
      before { sign_in member }
      
      it 'denies deletion even for assigned tasks' do
        member_task # create task
        
        expect {
          expect {
            delete :destroy, params: { id: member_task.id }
          }.to raise_error(CanCan::AccessDenied)
        }.not_to change { Mongodb::MongoTask.count }
      end
    end
    
    context 'as viewer' do
      before { sign_in viewer }
      
      it 'denies deletion' do
        task # create task
        
        expect {
          expect {
            delete :destroy, params: { id: task.id }
          }.to raise_error(CanCan::AccessDenied)
        }.not_to change { Mongodb::MongoTask.count }
      end
    end
  end

  describe 'Multi-tenant isolation' do
    let(:other_organization) { create(:organization) }
    let(:other_task) { create(:mongo_task, organization: other_organization) }
    
    before { sign_in owner }
    
    it 'cannot access tasks from other organizations' do
      expect {
        get :show, params: { id: other_task.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
    
    it 'cannot update tasks from other organizations' do
      expect {
        patch :update, params: { id: other_task.id, task: { title: 'Hacked' } }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
    
    it 'cannot delete tasks from other organizations' do
      expect {
        delete :destroy, params: { id: other_task.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'Dynamic role permissions' do
    let(:custom_role) { create(:role, organization: organization, key: 'project_manager', priority: 60) }
    let(:custom_user) { create(:user) }
    let!(:custom_membership) do
      create(:organization_membership, 
        user: custom_user, 
        organization: organization, 
        role_id: custom_role.id
      )
    end
    
    before do
      # Add specific permissions to the custom role
      read_perm = create(:permission, resource: 'Mongodb::MongoTask', action: 'read')
      create_perm = create(:permission, resource: 'Mongodb::MongoTask', action: 'create')
      update_perm = create(:permission, resource: 'Mongodb::MongoTask', action: 'update')
      
      custom_role.add_permission(read_perm)
      custom_role.add_permission(create_perm)
      custom_role.add_permission(update_perm, conditions: { 'own_only' => true })
      
      sign_in custom_user
    end
    
    it 'allows actions based on dynamic permissions' do
      # Can read
      get :index
      expect(response).to be_successful
      
      # Can create
      expect {
        post :create, params: {
          task: {
            title: 'PM Mongodb::MongoTask',
            service_id: service.id
          }
        }
      }.to change { Mongodb::MongoTask.count }.by(1)
    end
    
    it 'respects permission conditions' do
      # Can update own task
      own_task = create(:mongo_task, organization: organization, assignee_id: custom_user.id)
      patch :update, params: { id: own_task.id, task: { title: 'Updated' } }
      expect(own_task.reload.title).to eq('Updated')
      
      # Cannot update others' tasks
      expect {
        patch :update, params: { id: task.id, task: { title: 'Hacked' } }
      }.to raise_error(CanCan::AccessDenied)
    end
    
    it 'denies actions not granted' do
      # Cannot delete (permission not granted)
      expect {
        delete :destroy, params: { id: task.id }
      }.to raise_error(CanCan::AccessDenied)
    end
  end
end