# frozen_string_literal: true

class Api::V1::AuthController < ApplicationController
  before_action :authenticate_user!
  
  # API 컨트롤러에서는 Pundit verification을 우회
  after_action :verify_authorized, except: [:me, :login, :logout]
  
  # GET /api/v1/auth/me
  def me
    user = current_user
    
    # Handle case where current_user might return an array (testing scenario)
    if user.is_a?(Array)
      user = user.first.is_a?(User) ? user.first : User.find(user.first)
    end
    
    render_serialized(UserApiSerializer, user)
  end

  # POST /api/v1/auth/login
  def login
    # 이미 인증된 사용자라면 사용자 정보 반환
    if user_signed_in?
      render json: {
        message: 'Already authenticated',
        user: UserApiSerializer.new(current_user).serializable_hash
      }
    else
      render_error('Authentication required', status: :unauthorized)
    end
  end

  # POST /api/v1/auth/logout
  def logout
    if user_signed_in?
      sign_out current_user
      render json: { success: true, message: 'Logged out successfully' }
    else
      render_error('Not authenticated', status: :unauthorized)
    end
  end
end