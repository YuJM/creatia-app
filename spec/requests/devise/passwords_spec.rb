require 'rails_helper'

RSpec.describe "Devise::Passwords", type: :request do
  describe "GET /users/password/new" do
    it "returns success" do
      get new_user_password_path
      expect(response).to have_http_status(:success)
    end
    
    it "renders the password reset form" do
      get new_user_password_path
      expect(response.body).to include("Forgot your password?")
    end
  end
  
  describe "POST /users/password" do
    let(:user) { create(:user) }
    
    context "with valid email" do
      let(:valid_params) do
        {
          user: {
            email: user.email
          }
        }
      end
      
      it "sends password reset email" do
        expect {
          post user_password_path, params: valid_params
        }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end
      
      it "sets reset password token" do
        post user_password_path, params: valid_params
        user.reload
        expect(user.reset_password_token).to be_present
        expect(user.reset_password_sent_at).to be_present
      end
      
      it "redirects to sign in page" do
        post user_password_path, params: valid_params
        expect(response).to redirect_to(new_user_session_path)
      end
      
      it "shows success message" do
        post user_password_path, params: valid_params
        follow_redirect!
        expect(response.body).to include("You will receive an email with instructions")
      end
    end
    
    context "with non-existent email" do
      let(:invalid_params) do
        {
          user: {
            email: "nonexistent@example.com"
          }
        }
      end
      
      it "does not send email" do
        expect {
          post user_password_path, params: invalid_params
        }.not_to change { ActionMailer::Base.deliveries.count }
      end
      
      it "returns unprocessable entity status" do
        post user_password_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
      
      it "shows error message" do
        post user_password_path, params: invalid_params
        expect(response.body).to include("Email not found")
      end
    end
    
    context "with invalid email format" do
      let(:invalid_params) do
        {
          user: {
            email: "invalid_email"
          }
        }
      end
      
      it "does not send email" do
        expect {
          post user_password_path, params: invalid_params
        }.not_to change { ActionMailer::Base.deliveries.count }
      end
      
      it "shows error message" do
        post user_password_path, params: invalid_params
        expect(response.body).to include("Email is invalid")
      end
    end
  end
  
  describe "GET /users/password/edit" do
    let(:user) { create(:user) }
    let(:raw_token) { user.send_reset_password_instructions }
    
    context "with valid reset token" do
      it "returns success" do
        get edit_user_password_path(reset_password_token: raw_token)
        expect(response).to have_http_status(:success)
      end
      
      it "renders the password change form" do
        get edit_user_password_path(reset_password_token: raw_token)
        expect(response.body).to include("Change your password")
      end
    end
    
    context "without reset token" do
      it "redirects to sign in" do
        get edit_user_password_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
  
  describe "PUT /users/password" do
    let(:user) { create(:user) }
    let(:raw_token) { user.send_reset_password_instructions }
    
    context "with valid token and passwords" do
      let(:valid_params) do
        {
          user: {
            reset_password_token: raw_token,
            password: "newpassword123",
            password_confirmation: "newpassword123"
          }
        }
      end
      
      it "resets the password" do
        put user_password_path, params: valid_params
        user.reload
        expect(user.valid_password?("newpassword123")).to be true
      end
      
      it "signs in the user" do
        put user_password_path, params: valid_params
        expect(controller.current_user).to eq(user)
      end
      
      it "clears reset password token" do
        put user_password_path, params: valid_params
        user.reload
        expect(user.reset_password_token).to be_nil
        expect(user.reset_password_sent_at).to be_nil
      end
      
      it "redirects to root path" do
        put user_password_path, params: valid_params
        expect(response).to redirect_to(root_path)
      end
      
      it "shows success message" do
        put user_password_path, params: valid_params
        follow_redirect!
        expect(response.body).to include("Your password has been changed successfully")
      end
    end
    
    context "with invalid token" do
      let(:invalid_params) do
        {
          user: {
            reset_password_token: "invalid_token",
            password: "newpassword123",
            password_confirmation: "newpassword123"
          }
        }
      end
      
      it "does not reset the password" do
        put user_password_path, params: invalid_params
        user.reload
        expect(user.valid_password?("newpassword123")).to be false
      end
      
      it "returns unprocessable entity status" do
        put user_password_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
      
      it "shows error message" do
        put user_password_path, params: invalid_params
        expect(response.body).to include("Reset password token is invalid")
      end
    end
    
    context "with expired token" do
      let(:expired_params) do
        {
          user: {
            reset_password_token: raw_token,
            password: "newpassword123",
            password_confirmation: "newpassword123"
          }
        }
      end
      
      before do
        user.update(reset_password_sent_at: 7.hours.ago)
      end
      
      it "does not reset the password" do
        put user_password_path, params: expired_params
        user.reload
        expect(user.valid_password?("newpassword123")).to be false
      end
      
      it "shows error message" do
        put user_password_path, params: expired_params
        expect(response.body).to include("Reset password token has expired")
      end
    end
    
    context "with mismatched passwords" do
      let(:mismatch_params) do
        {
          user: {
            reset_password_token: raw_token,
            password: "newpassword123",
            password_confirmation: "differentpassword"
          }
        }
      end
      
      it "does not reset the password" do
        put user_password_path, params: mismatch_params
        user.reload
        expect(user.valid_password?("newpassword123")).to be false
      end
      
      it "shows error message" do
        put user_password_path, params: mismatch_params
        expect(response.body).to include("Password confirmation doesn't match")
      end
    end
    
    context "with too short password" do
      let(:short_params) do
        {
          user: {
            reset_password_token: raw_token,
            password: "123",
            password_confirmation: "123"
          }
        }
      end
      
      it "does not reset the password" do
        put user_password_path, params: short_params
        user.reload
        expect(user.valid_password?("123")).to be false
      end
      
      it "shows error message" do
        put user_password_path, params: short_params
        expect(response.body).to include("Password is too short")
      end
    end
  end
end