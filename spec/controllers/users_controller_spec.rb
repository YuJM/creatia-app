require 'rails_helper'

RSpec.describe UsersController, type: :controller do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:moderator) { create(:user, :moderator) }
  
  describe "GET #index" do
    it_behaves_like "requires authentication", :index
    
    context "when authenticated as regular user" do
      before do
        @request.env["devise.mapping"] = Devise.mappings[:user]
        sign_in user, scope: :user
      end
      
      it "redirects with not authorized alert" do
        get :index
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You are not authorized to perform this action.")
      end
    end
    
    context "when authenticated as moderator" do
      before do
        @request.env["devise.mapping"] = Devise.mappings[:user]
        sign_in moderator, scope: :user
      end
      
      it "returns success" do
        get :index
        expect(response).to be_successful
      end
      
      it "assigns all users" do
        get :index
        expect(assigns(:users)).to match_array([user, other_user, admin, moderator])
      end
      
      it "authorizes the action" do
        expect_to_authorize(:index?, User)
        get :index
      end
      
      it "uses policy scope" do
        expect_to_policy_scope(User)
        get :index
      end
    end
    
    context "when authenticated as admin" do
      before do
        @request.env["devise.mapping"] = Devise.mappings[:user]
        sign_in admin, scope: :user
      end
      
      it "returns success" do
        get :index
        expect(response).to be_successful
      end
      
      it "assigns all users" do
        get :index
        expect(assigns(:users)).to include(user, other_user, moderator)
      end
    end
  end
  
  describe "GET #show" do
    it_behaves_like "requires authentication", :show, :get, { id: 1 }
    
    context "when authenticated" do
      before do
        @request.env["devise.mapping"] = Devise.mappings[:user]
        sign_in user, scope: :user
      end
      
      it "returns success for own profile" do
        get :show, params: { id: user.id }
        expect(response).to be_successful
      end
      
      it "returns success for other user profile" do
        get :show, params: { id: other_user.id }
        expect(response).to be_successful
      end
      
      it "assigns the requested user" do
        get :show, params: { id: other_user.id }
        expect(assigns(:user)).to eq(other_user)
      end
      
      it "authorizes the action" do
        expect_to_authorize(:show?, other_user)
        get :show, params: { id: other_user.id }
      end
    end
  end
  
  describe "GET #edit" do
    it_behaves_like "requires authentication", :edit, :get, { id: 1 }
    
    context "when authenticated as regular user" do
      before do
        @request.env["devise.mapping"] = Devise.mappings[:user]
        sign_in user, scope: :user
      end
      
      it "returns success for own profile" do
        get :edit, params: { id: user.id }
        expect(response).to be_successful
      end
      
      it "redirects with not authorized for other user" do
        get :edit, params: { id: other_user.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You are not authorized to perform this action.")
      end
      
      it "authorizes the action" do
        expect_to_authorize(:edit?, user)
        get :edit, params: { id: user.id }
      end
    end
    
    context "when authenticated as admin" do
      before do
        @request.env["devise.mapping"] = Devise.mappings[:user]
        sign_in admin, scope: :user
      end
      
      it "returns success for any user" do
        get :edit, params: { id: other_user.id }
        expect(response).to be_successful
      end
    end
  end
  
  describe "PATCH #update" do
    let(:valid_attributes) { { username: "newusername" } }
    let(:invalid_attributes) { { email: "invalid" } }
    
    it_behaves_like "requires authentication", :update, :patch, { id: 1 }
    
    context "when authenticated as regular user" do
      before do
        @request.env["devise.mapping"] = Devise.mappings[:user]
        sign_in user, scope: :user
      end
      
      context "updating own profile" do
        it "updates the user" do
          patch :update, params: { id: user.id, user: valid_attributes }
          user.reload
          expect(user.username).to eq("newusername")
        end
        
        it "redirects to user profile" do
          patch :update, params: { id: user.id, user: valid_attributes }
          expect(response).to redirect_to(user)
        end
        
        it "cannot update role" do
          patch :update, params: { id: user.id, user: { role: "admin" } }
          user.reload
          expect(user.role).to eq("user")
        end
        
        it "authorizes the action" do
          expect_to_authorize(:update?, user)
          patch :update, params: { id: user.id, user: valid_attributes }
        end
        
        context "with invalid attributes" do
          it "does not update the user" do
            original_email = user.email
            patch :update, params: { id: user.id, user: invalid_attributes }
            user.reload
            expect(user.email).to eq(original_email)
          end
          
          it "returns unprocessable entity" do
            patch :update, params: { id: user.id, user: invalid_attributes }
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end
      end
      
      context "updating other user" do
        it "redirects with not authorized error" do
          patch :update, params: { id: other_user.id, user: valid_attributes }
          expect(response).to redirect_to(root_path)
          expect(flash[:alert]).to eq("You are not authorized to perform this action.")
        end
      end
    end
    
    context "when authenticated as admin" do
      before do
        @request.env["devise.mapping"] = Devise.mappings[:user]
        sign_in admin, scope: :user
      end
      
      it "can update any user" do
        patch :update, params: { id: other_user.id, user: valid_attributes }
        other_user.reload
        expect(other_user.username).to eq("newusername")
      end
      
      it "can update role" do
        patch :update, params: { id: other_user.id, user: { role: "moderator" } }
        other_user.reload
        expect(other_user.role).to eq("moderator")
      end
    end
  end
  
  describe "DELETE #destroy" do
    it_behaves_like "requires authentication", :destroy, :delete, { id: 1 }
    
    context "when authenticated as regular user" do
      before do
        @request.env["devise.mapping"] = Devise.mappings[:user]
        sign_in user, scope: :user
      end
      
      it "redirects with not authorized error for own account" do
        delete :destroy, params: { id: user.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You are not authorized to perform this action.")
      end
      
      it "redirects with not authorized error for other user" do
        delete :destroy, params: { id: other_user.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You are not authorized to perform this action.")
      end
    end
    
    context "when authenticated as moderator" do
      before do
        @request.env["devise.mapping"] = Devise.mappings[:user]
        sign_in moderator, scope: :user
      end
      
      it "redirects with not authorized error" do
        delete :destroy, params: { id: other_user.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You are not authorized to perform this action.")
      end
    end
    
    context "when authenticated as admin" do
      before do
        sign_in admin
        other_user # ensure user exists before test
      end
      
      it "destroys the user" do
        expect {
          delete :destroy, params: { id: other_user.id }
        }.to change(User, :count).by(-1)
      end
      
      it "redirects to users list" do
        delete :destroy, params: { id: other_user.id }
        expect(response).to redirect_to(users_url)
      end
      
      it "authorizes the action" do
        expect_to_authorize(:destroy?, other_user)
        delete :destroy, params: { id: other_user.id }
      end
    end
  end
  
  describe "Pundit integration" do
    context "policy usage" do
      before do
        @request.env["devise.mapping"] = Devise.mappings[:user]
        sign_in user, scope: :user
      end
      
      it "uses UserPolicy for authorization" do
        expect(UserPolicy).to receive(:new).with(user, user).and_call_original
        get :show, params: { id: user.id }
      end
      
      it "uses UserPolicy::Scope for index" do
        sign_in moderator
        expect(UserPolicy::Scope).to receive(:new).with(moderator, User).and_call_original
        get :index
      end
    end
    
    context "permitted attributes" do
      before do
        @request.env["devise.mapping"] = Devise.mappings[:user]
        sign_in user, scope: :user
      end
      
      it "uses policy for permitted attributes" do
        policy = instance_double(UserPolicy)
        expect(policy).to receive(:permitted_attributes).and_return([:username])
        expect(controller).to receive(:policy).with(user).and_return(policy)
        
        patch :update, params: { id: user.id, user: { username: "test" } }
      end
    end
  end
end