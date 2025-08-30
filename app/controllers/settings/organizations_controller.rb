class Settings::OrganizationsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :ensure_organization_admin!

  def show
    @organization = current_organization
  end

  def edit
    @organization = current_organization
  end

  def update
    @organization = current_organization
    
    if @organization.update(organization_params)
      redirect_to settings_organization_path, notice: 'Organization settings updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def current_organization
    @current_organization ||= ActsAsTenant.current_tenant
  end

  def organization_params
    params.require(:organization).permit(:name, :description, :website, :logo_url)
  end

  def ensure_organization_access!
    unless current_user.member_of?(current_organization)
      redirect_to root_path, alert: 'Access denied.'
    end
  end

  def ensure_organization_admin!
    unless current_user.admin_of?(current_organization)
      redirect_to root_path, alert: 'Administrative access required.'
    end
  end
end