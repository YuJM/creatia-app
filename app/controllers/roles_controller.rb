class RolesController < ApplicationController
  before_action :set_organization
  before_action :set_role, only: [:show, :edit, :update, :destroy, :permissions]
  before_action :authorize_role_management!

  def index
    @roles = @organization.roles.includes(:permissions).by_priority
    @custom_roles = @roles.custom
    @system_roles = @roles.system
    
    respond_to do |format|
      format.html
      format.json { render json: RoleSerializer.new(@roles) }
    end
  end

  def show
    @role_permissions = @role.role_permissions.includes(:permission)
    @available_permissions = Permission.all.group_by(&:resource)
    
    respond_to do |format|
      format.html
      format.json { render json: RoleSerializer.new(@role) }
    end
  end

  def new
    @role = @organization.roles.build
    @available_permissions = Permission.all.group_by(&:resource)
  end

  def create
    @role = @organization.roles.build(role_params)
    
    if @role.save
      add_permissions_to_role if params[:permission_ids].present?
      
      respond_to do |format|
        format.html { redirect_to organization_role_path(@organization, @role), notice: '역할이 생성되었습니다.' }
        format.turbo_stream
        format.json { render json: RoleSerializer.new(@role), status: :created }
      end
    else
      @available_permissions = Permission.all.group_by(&:resource)
      
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render turbo_stream: turbo_stream.replace('role_form', partial: 'form', locals: { role: @role }) }
        format.json { render json: { errors: @role.errors }, status: :unprocessable_entity }
      end
    end
  end

  def edit
    unless @role.editable?
      redirect_to organization_roles_path(@organization), alert: '시스템 역할은 수정할 수 없습니다.'
      return
    end
    
    @available_permissions = Permission.all.group_by(&:resource)
    @current_permission_ids = @role.permission_ids
  end

  def update
    unless @role.editable?
      redirect_to organization_roles_path(@organization), alert: '시스템 역할은 수정할 수 없습니다.'
      return
    end
    
    if @role.update(role_params)
      update_role_permissions if params[:permission_ids]
      
      respond_to do |format|
        format.html { redirect_to organization_role_path(@organization, @role), notice: '역할이 수정되었습니다.' }
        format.turbo_stream
        format.json { render json: RoleSerializer.new(@role) }
      end
    else
      @available_permissions = Permission.all.group_by(&:resource)
      @current_permission_ids = @role.permission_ids
      
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render turbo_stream: turbo_stream.replace('role_form', partial: 'form', locals: { role: @role }) }
        format.json { render json: { errors: @role.errors }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    if @role.destroyable?
      @role.destroy
      
      respond_to do |format|
        format.html { redirect_to organization_roles_path(@organization), notice: '역할이 삭제되었습니다.' }
        format.turbo_stream { render turbo_stream: turbo_stream.remove(dom_id(@role)) }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html { redirect_to organization_roles_path(@organization), alert: '사용 중인 역할은 삭제할 수 없습니다.' }
        format.turbo_stream { render turbo_stream: turbo_stream.replace('flash', partial: 'shared/flash', locals: { alert: '사용 중인 역할은 삭제할 수 없습니다.' }) }
        format.json { render json: { error: 'Role cannot be deleted' }, status: :unprocessable_entity }
      end
    end
  end

  def permissions
    @role_permissions = @role.role_permissions.includes(:permission)
    @available_permissions = Permission.all.group_by(&:resource)
    @current_permission_ids = @role.permission_ids
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def duplicate
    @source_role = @organization.roles.find(params[:id])
    @new_role = @source_role.duplicate("#{@source_role.name} (복사본)")
    
    if @new_role.persisted?
      redirect_to edit_organization_role_path(@organization, @new_role), notice: '역할이 복제되었습니다.'
    else
      redirect_to organization_roles_path(@organization), alert: '역할 복제에 실패했습니다.'
    end
  end

  private

  def set_organization
    @organization = current_organization
  end

  def set_role
    @role = @organization.roles.find(params[:id])
  end

  def authorize_role_management!
    authorize! :manage, Role
  end

  def role_params
    params.require(:role).permit(:name, :key, :description, :priority, :editable)
  end

  def add_permissions_to_role
    permission_ids = params[:permission_ids].reject(&:blank?)
    permissions = Permission.where(id: permission_ids)
    
    permissions.each do |permission|
      @role.add_permission(permission)
    end
  end

  def update_role_permissions
    # Remove existing permissions
    @role.role_permissions.destroy_all
    
    # Add new permissions
    permission_ids = params[:permission_ids].reject(&:blank?)
    permissions = Permission.where(id: permission_ids)
    
    permissions.each do |permission|
      conditions = params.dig(:permission_conditions, permission.id.to_s)
      scope = params.dig(:permission_scopes, permission.id.to_s)
      
      @role.add_permission(
        permission,
        conditions: conditions || {},
        scope: scope || {}
      )
    end
  end
end