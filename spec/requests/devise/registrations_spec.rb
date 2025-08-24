require 'rails_helper'

RSpec.describe "Devise::Registrations", type: :request do
  describe "GET /users/sign_up" do
    it "returns success" do
      get new_user_registration_path
      expect(response).to have_http_status(:success)
    end
    
    it "renders the sign up form" do
      get new_user_registration_path
      expect(response.body).to include("Sign up")
    end
  end
  
  describe "POST /users" do
    context "with valid parameters" do
      let(:valid_params) do
        {
          user: {
            email: Faker::Internet.unique.email,
            password: "password123",
            password_confirmation: "password123",
            username: Faker::Internet.unique.username(specifier: 3..20, separators: %w[_ -])
          }
        }
      end
      
      it "creates a new user" do
        expect {
          post user_registration_path, params: valid_params
        }.to change(User, :count).by(1)
      end
      
      it "signs in the user" do
        post user_registration_path, params: valid_params
        expect(controller.current_user).to be_present
      end
      
      it "redirects to root path" do
        post user_registration_path, params: valid_params
        expect(response).to redirect_to(root_path)
      end
      
      it "creates user with UUID" do
        post user_registration_path, params: valid_params
        user = User.last
        expect(user.id).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
      end
    end
    
    context "with invalid parameters" do
      let(:invalid_params) do
        {
          user: {
            email: "invalid_email",
            password: "123",
            password_confirmation: "456"
          }
        }
      end
      
      it "does not create a new user" do
        expect {
          post user_registration_path, params: invalid_params
        }.not_to change(User, :count)
      end
      
      it "returns unprocessable entity status" do
        post user_registration_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
      
      it "renders the sign up form with errors" do
        post user_registration_path, params: invalid_params
        expect(response.body).to include("Email is invalid")
      end
    end
    
    context "with duplicate email" do
      let!(:existing_user) { create(:user) }
      let(:duplicate_params) do
        {
          user: {
            email: existing_user.email,
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end
      
      it "does not create a new user" do
        expect {
          post user_registration_path, params: duplicate_params
        }.not_to change(User, :count)
      end
      
      it "shows error message" do
        post user_registration_path, params: duplicate_params
        expect(response.body).to include("Email has already been taken")
      end
    end
  end
  
  describe "GET /users/edit" do
    context "when authenticated" do
      let(:user) { create(:user) }
      
      before { sign_in user }
      
      it "returns success" do
        get edit_user_registration_path
        expect(response).to have_http_status(:success)
      end
      
      it "renders the edit form" do
        get edit_user_registration_path
        expect(response.body).to include("Edit User")
      end
    end
    
    context "when not authenticated" do
      it "redirects to sign in" do
        get edit_user_registration_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
  
  describe "PUT /users" do
    let(:user) { create(:user) }
    
    before { sign_in user }
    
    context "with valid current password" do
      let(:update_params) do
        {
          user: {
            email: Faker::Internet.unique.email,
            current_password: "password123"
          }
        }
      end
      
      it "updates the user" do
        put user_registration_path, params: update_params
        user.reload
        expect(user.email).to eq(update_params[:user][:email])
      end
      
      it "redirects to root path" do
        put user_registration_path, params: update_params
        expect(response).to redirect_to(root_path)
      end
    end
    
    context "with invalid current password" do
      let(:update_params) do
        {
          user: {
            email: Faker::Internet.unique.email,
            current_password: "wrong_password"
          }
        }
      end
      
      it "does not update the user" do
        original_email = user.email
        put user_registration_path, params: update_params
        user.reload
        expect(user.email).to eq(original_email)
      end
      
      it "returns unprocessable entity status" do
        put user_registration_path, params: update_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
    
    context "updating password" do
      let(:update_params) do
        {
          user: {
            password: "newpassword123",
            password_confirmation: "newpassword123",
            current_password: "password123"
          }
        }
      end
      
      it "updates the password" do
        put user_registration_path, params: update_params
        user.reload
        expect(user.valid_password?("newpassword123")).to be true
      end
      
      it "keeps the user signed in" do
        put user_registration_path, params: update_params
        expect(controller.current_user).to eq(user)
      end
    end
  end
  
  describe "DELETE /users" do
    let(:user) { create(:user) }
    
    before { sign_in user }
    
    it "deletes the user account" do
      expect {
        delete user_registration_path
      }.to change(User, :count).by(-1)
    end
    
    it "signs out the user" do
      delete user_registration_path
      expect(controller.current_user).to be_nil
    end
    
    it "redirects to root path" do
      delete user_registration_path
      expect(response).to redirect_to(root_path)
    end
    
    it "shows success message" do
      delete user_registration_path
      follow_redirect!
      expect(response.body).to include("Your account has been successfully cancelled")
    end
  end
end