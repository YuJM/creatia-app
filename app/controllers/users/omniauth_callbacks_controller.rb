# frozen_string_literal: true

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token, only: [:github, :google_oauth2]
  
  def github
    @user = User.from_github_omniauth(request.env["omniauth.auth"])
    
    if @user.persisted?
      # GitHub 토큰을 세션에 저장 (Service 연결용)
      session[:github_token] = request.env["omniauth.auth"].credentials.token
      
      sign_in_and_redirect @user, event: :authentication
      set_flash_message(:notice, :success, kind: "GitHub") if is_navigational_format?
    else
      session["devise.github_data"] = request.env["omniauth.auth"].except(:extra)
      redirect_to new_user_registration_url
    end
  end
  
  def google_oauth2
    @user = User.from_google_omniauth(request.env["omniauth.auth"])
    
    if @user.persisted?
      sign_in_and_redirect @user, event: :authentication
      set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
    else
      session["devise.google_data"] = request.env["omniauth.auth"].except(:extra)
      redirect_to new_user_registration_url
    end
  end
  
  def failure
    redirect_to root_path, alert: "Authentication failed: #{params[:message]}"
  end
end