require 'rails_helper'

RSpec.describe OrganizationsController, type: :controller do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  
  let(:owner) { create(:user) }
  let(:admin) { create(:user) }
  let(:member) { create(:user) }
  let(:viewer) { create(:user) }
  let(:non_member) { create(:user) }
  
  let!(:owner_membership) { create(:organization_membership, user: owner, organization: organization, role: 'owner') }
  let!(:admin_membership) { create(:organization_membership, user: admin, organization: organization, role: 'admin') }
  let!(:member_membership) { create(:organization_membership, user: member, organization: organization, role: 'member') }
  let!(:viewer_membership) { create(:organization_membership, user: viewer, organization: organization, role: 'viewer') }
  
  before do
    ActsAsTenant.current_tenant = organization
  end

  describe 'GET #show' do
    context 'as owner' do
      before { sign_in owner }
      
      it 'allows access' do
        get :show, params: { id: organization.id }
        expect(response).to be_successful
      end
    end
    
    context 'as member' do
      before { sign_in member }
      
      it 'allows access' do
        get :show, params: { id: organization.id }
        expect(response).to be_successful
      end
    end
    
    context 'as viewer' do
      before { sign_in viewer }
      
      it 'allows access' do
        get :show, params: { id: organization.id }
        expect(response).to be_successful
      end
    end
    
    context 'as non-member' do
      before { sign_in non_member }
      
      it 'denies access' do
        expect {
          get :show, params: { id: organization.id }
        }.to raise_error(CanCan::AccessDenied)
      end
    end
  end

  describe 'GET #edit' do
    context 'as owner' do
      before { sign_in owner }
      
      it 'allows access' do
        get :edit, params: { id: organization.id }
        expect(response).to be_successful
      end
    end
    
    context 'as admin' do
      before { sign_in admin }
      
      it 'allows access' do
        get :edit, params: { id: organization.id }
        expect(response).to be_successful
      end
    end
    
    context 'as member' do
      before { sign_in member }
      
      it 'denies access' do
        expect {
          get :edit, params: { id: organization.id }
        }.to raise_error(CanCan::AccessDenied)
      end
    end
    
    context 'as viewer' do
      before { sign_in viewer }
      
      it 'denies access' do
        expect {
          get :edit, params: { id: organization.id }
        }.to raise_error(CanCan::AccessDenied)
      end
    end
  end

  describe 'PATCH #update' do
    let(:update_params) do
      {
        id: organization.id,
        organization: { name: 'Updated Name' }
      }
    end
    
    context 'as owner' do
      before { sign_in owner }
      
      it 'allows update' do
        patch :update, params: update_params
        expect(organization.reload.name).to eq('Updated Name')
        expect(response).to redirect_to(organization_path(organization))
      end
    end
    
    context 'as admin' do
      before { sign_in admin }
      
      it 'allows update' do
        patch :update, params: update_params
        expect(organization.reload.name).to eq('Updated Name')
      end
    end
    
    context 'as member' do
      before { sign_in member }
      
      it 'denies update' do
        expect {
          patch :update, params: update_params
        }.to raise_error(CanCan::AccessDenied)
        
        expect(organization.reload.name).not_to eq('Updated Name')
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'as owner' do
      before { sign_in owner }
      
      it 'allows deletion' do
        delete :destroy, params: { id: organization.id }
        expect(response).to redirect_to(root_path)
        expect(Organization.find_by(id: organization.id)).to be_nil
      end
    end
    
    context 'as admin' do
      before { sign_in admin }
      
      it 'denies deletion' do
        expect {
          delete :destroy, params: { id: organization.id }
        }.to raise_error(CanCan::AccessDenied)
        
        expect(Organization.find(organization.id)).to be_present
      end
    end
    
    context 'as member' do
      before { sign_in member }
      
      it 'denies deletion' do
        expect {
          delete :destroy, params: { id: organization.id }
        }.to raise_error(CanCan::AccessDenied)
      end
    end
  end

  describe 'GET #settings' do
    context 'as owner' do
      before { sign_in owner }
      
      it 'allows access to settings' do
        get :settings, params: { id: organization.id }
        expect(response).to be_successful
      end
    end
    
    context 'as admin' do
      before { sign_in admin }
      
      it 'denies access to settings' do
        expect {
          get :settings, params: { id: organization.id }
        }.to raise_error(CanCan::AccessDenied)
      end
    end
  end

  describe 'GET #billing' do
    context 'as owner' do
      before { sign_in owner }
      
      it 'allows access to billing' do
        get :billing, params: { id: organization.id }
        expect(response).to be_successful
      end
    end
    
    context 'as admin' do
      before { sign_in admin }
      
      it 'denies access to billing' do
        expect {
          get :billing, params: { id: organization.id }
        }.to raise_error(CanCan::AccessDenied)
      end
    end
  end

  describe 'Organization switching' do
    let!(:second_membership) do
      create(:organization_membership, user: member, organization: other_organization, role: 'member')
    end
    
    before { sign_in member }
    
    it 'allows switching to organizations where user is a member' do
      post :switch, params: { id: other_organization.id }
      expect(response).to redirect_to(organization_path(other_organization))
      expect(session[:current_organization_id]).to eq(other_organization.id)
    end
    
    it 'denies switching to organizations where user is not a member' do
      third_org = create(:organization)
      
      expect {
        post :switch, params: { id: third_org.id }
      }.to raise_error(CanCan::AccessDenied)
      
      expect(session[:current_organization_id]).not_to eq(third_org.id)
    end
  end

  describe 'Multi-tenant isolation' do
    before { sign_in owner }
    
    it 'cannot access other organizations even as owner of current org' do
      expect {
        get :show, params: { id: other_organization.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
    
    it 'cannot update other organizations' do
      expect {
        patch :update, params: {
          id: other_organization.id,
          organization: { name: 'Hacked' }
        }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
    
    it 'cannot delete other organizations' do
      expect {
        delete :destroy, params: { id: other_organization.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end