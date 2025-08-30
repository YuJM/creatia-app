# frozen_string_literal: true

# 테스트 환경에서만 사용되는 자동 로그인 컨트롤러
class TestAuthController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :ensure_organization_access
  skip_authorization_check
  
  # GET /test_auth/login
  def login
    unless Rails.env.development? || Rails.env.test?
      redirect_to root_path, alert: "This feature is only available in development/test environment"
      return
    end
    
    email = params[:email]
    if email.present?
      user = User.find_by(email: email)
      if user
        sign_in(user, scope: :user)
        
        # 조직 설정
        subdomain = params[:subdomain] || 'demo'
        organization = Organization.find_by(subdomain: subdomain)
        
        if organization
          # 세션에 현재 조직 저장
          session[:current_organization_id] = organization.id
          
          # 사용자가 해당 조직의 멤버인지 확인
          membership = OrganizationMembership.find_by(user: user, organization: organization)
          if membership || user.email == organization.owner_email
            # 조직 접근 권한 설정
            session[:accessible_organizations] ||= []
            session[:accessible_organizations] << organization.id unless session[:accessible_organizations].include?(organization.id)
            
            redirect_to "http://#{subdomain}.creatia.local:3000/dashboard", notice: "Test login successful", allow_other_host: true
          else
            render json: { error: "User does not have access to this organization" }, status: :forbidden
          end
        else
          redirect_to root_path, notice: "Test login successful"
        end
      else
        render json: { error: "User not found: #{email}" }, status: :not_found
      end
    else
      render json: { error: "Email parameter required" }, status: :bad_request
    end
  end
end