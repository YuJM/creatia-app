class LandingController < ApplicationController
  layout 'public'
  skip_before_action :authenticate_user!
  skip_before_action :ensure_organization_access
  skip_authorization_check
  
  def index
    # 로그아웃 후 세션 정리 확인
    if user_signed_in?
      # 로그인된 사용자가 있으면 대시보드로 리다이렉트
      redirect_to_dashboard
    else
      # 로그인되지 않은 사용자에게는 랜딩 페이지 표시
      render 'index_short'
    end
  end
  
  private
  
  def redirect_to_dashboard
    # 사용자의 첫 번째 조직으로 리다이렉트
    if current_user.organizations.active.any?
      organization = current_user.organizations.active.first
      redirect_to DomainService.organization_url(organization.subdomain, 'dashboard'), allow_other_host: true
    else
      # 조직이 없으면 조직 생성 페이지로
      redirect_to "#{request.protocol}www.#{DomainService.base_domain}/web/organizations/new", allow_other_host: true
    end
  end
end
