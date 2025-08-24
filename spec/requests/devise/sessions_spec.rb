require 'rails_helper'

RSpec.describe "Devise::Sessions", type: :request do
  describe "GET /users/sign_in" do
    it "returns success" do
      get new_user_session_path
      expect(response).to have_http_status(:success)
    end
    
    it "renders the sign in form" do
      get new_user_session_path
      expect(response.body).to include("Log in")
    end
    
    context "when already signed in" do
      let(:user) { create(:user) }
      
      before { sign_in user }
      
      it "redirects to root path" do
        get new_user_session_path
        expect(response).to redirect_to(root_path)
      end
    end
  end
  
  describe "POST /users/sign_in" do
    let(:user) { create(:user, email: "test@example.com", password: "password123") }
    
    context "with valid credentials" do
      let(:valid_params) do
        {
          user: {
            email: user.email,
            password: "password123"
          }
        }
      end
      
      it "signs in the user" do
        post user_session_path, params: valid_params
        expect(controller.current_user).to eq(user)
      end
      
      it "redirects to root path" do
        post user_session_path, params: valid_params
        expect(response).to redirect_to(root_path)
      end
      
      it "shows success message" do
        post user_session_path, params: valid_params
        follow_redirect!
        expect(response.body).to include("Signed in successfully")
      end
      
      it "updates sign in tracking" do
        expect {
          post user_session_path, params: valid_params
          user.reload
        }.to change { user.sign_in_count }.by(1)
      end
      
      it "updates last sign in time" do
        post user_session_path, params: valid_params
        user.reload
        expect(user.current_sign_in_at).to be_present
      end
    end
    
    context "with invalid credentials" do
      let(:invalid_params) do
        {
          user: {
            email: user.email,
            password: "wrong_password"
          }
        }
      end
      
      it "does not sign in the user" do
        post user_session_path, params: invalid_params
        expect(controller.current_user).to be_nil
      end
      
      it "returns unprocessable entity status" do
        post user_session_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
      
      it "shows error message" do
        post user_session_path, params: invalid_params
        expect(response.body).to include("Invalid Email or password")
      end
    end
    
    context "with remember me" do
      let(:params_with_remember) do
        {
          user: {
            email: user.email,
            password: "password123",
            remember_me: "1"
          }
        }
      end
      
      it "creates remember token" do
        post user_session_path, params: params_with_remember
        user.reload
        expect(user.remember_created_at).to be_present
      end
      
      it "sets remember cookie" do
        post user_session_path, params: params_with_remember
        expect(response.cookies['remember_user_token']).to be_present
      end
    end
    
    context "with non-existent email" do
      let(:non_existent_params) do
        {
          user: {
            email: "nonexistent@example.com",
            password: "password123"
          }
        }
      end
      
      it "does not sign in" do
        post user_session_path, params: non_existent_params
        expect(controller.current_user).to be_nil
      end
      
      it "shows error message" do
        post user_session_path, params: non_existent_params
        expect(response.body).to include("Invalid Email or password")
      end
    end
  end
  
  describe "DELETE /users/sign_out" do
    let(:user) { create(:user) }
    
    context "when signed in" do
      before { sign_in user }
      
      it "signs out the user" do
        delete destroy_user_session_path
        expect(controller.current_user).to be_nil
      end
      
      it "redirects to root path" do
        delete destroy_user_session_path
        expect(response).to redirect_to(root_path)
      end
      
      it "shows success message" do
        delete destroy_user_session_path
        follow_redirect!
        expect(response.body).to include("Signed out successfully")
      end
      
      it "clears remember token" do
        user.update(remember_created_at: Time.current)
        delete destroy_user_session_path
        user.reload
        expect(user.remember_created_at).to be_nil
      end
    end
    
    context "when not signed in" do
      it "redirects to root path" do
        delete destroy_user_session_path
        expect(response).to redirect_to(root_path)
      end
    end
  end
end