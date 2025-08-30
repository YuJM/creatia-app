class LandingController < ApplicationController
  layout 'public'
  skip_before_action :authenticate_user!
  skip_before_action :ensure_organization_access
  skip_authorization_check
  
  def index
    # user_signed_in?가 있으면 대시보드로 리다이렉트
    # 없으면 랜딩 페이지 표시
  end
end
