require 'rails_helper'

RSpec.describe "Users", type: :request do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  
  describe "GET /users" do
    context "when not authenticated" do
      it "redirects to login" do
        get users_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
    
    context "when authenticated as regular user" do
      before { sign_in user }
      
      it "redirects with not authorized" do
        get users_path
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You are not authorized to perform this action.")
      end
    end
    
    context "when authenticated as admin" do
      before { sign_in admin }
      
      it "returns http success" do
        get users_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /users/:id" do
    context "when not authenticated" do
      it "redirects to login" do
        get user_path(user)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
    
    context "when authenticated" do
      before { sign_in user }
      
      it "returns http success" do
        get user_path(user)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /users/:id/edit" do
    context "when not authenticated" do
      it "redirects to login" do
        get edit_user_path(user)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
    
    context "when authenticated as user" do
      before { sign_in user }
      
      it "returns http success for own profile" do
        get edit_user_path(user)
        expect(response).to have_http_status(:success)
      end
      
      it "redirects with not authorized for other user" do
        other_user = create(:user)
        get edit_user_path(other_user)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You are not authorized to perform this action.")
      end
    end
  end

  describe "PATCH /users/:id" do
    context "when not authenticated" do
      it "redirects to login" do
        patch user_path(user), params: { user: { name: "New Name" } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
    
    context "when authenticated as user" do
      before { sign_in user }
      
      it "updates own profile" do
        patch user_path(user), params: { user: { name: "New Name" } }
        expect(response).to redirect_to(user_path(user))
        expect(user.reload.name).to eq("New Name")
      end
      
      it "redirects with not authorized for other user" do
        other_user = create(:user)
        patch user_path(other_user), params: { user: { name: "New Name" } }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You are not authorized to perform this action.")
      end
    end
  end

end
