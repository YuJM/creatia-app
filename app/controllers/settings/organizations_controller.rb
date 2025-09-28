class Settings::OrganizationsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_organization
  
  # CanCanCan authorization
  # Settings 페이지는 :read 권한으로 보여주고, update는 :manage 권한이 필요
  authorize_resource :organization, through: :current_organization, singleton: true

  def show
    # @organization is already set by set_organization
    authorize! :read, @organization
  end

  def edit
    # @organization is already set by set_organization
    authorize! :manage, @organization
  end

  def update
    authorize! :manage, @organization
    
    if @organization.update(organization_params)
      redirect_to settings_organization_path, notice: '조직 설정이 성공적으로 업데이트되었습니다.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_organization
    @organization = current_organization
  end

  def current_organization
    @current_organization ||= ActsAsTenant.current_tenant
  end

  def organization_params
    params.require(:organization).permit(:name, :description, :website, :logo_url, :subdomain, :settings)
  end

  def ensure_organization_access!
    unless current_organization
      redirect_to root_path, alert: '조직 컨텍스트가 필요합니다.'
      return
    end
    
    unless current_user.member_of?(current_organization)
      redirect_to root_path, alert: '이 조직에 접근할 권한이 없습니다.'
    end
  end
end