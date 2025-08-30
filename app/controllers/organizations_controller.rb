# frozen_string_literal: true

class OrganizationsController < ApplicationController
  layout 'application'
  before_action :authenticate_user!
  before_action :set_organization, only: [:show, :update, :destroy, :switch]
  
  # GET /organizations
  # 사용자가 속한 조직 목록을 반환합니다.
  def index
    @organizations = Organization.accessible_by(current_ability)
    authorize! :index, Organization
    
    respond_to do |format|
      format.html # renders index.html.erb
      format.json do
        render_serialized(
          OrganizationSerializer,
          @organizations,
          params: { include_organizations: true }
        )
      end
    end
  end
  
  # GET /organizations/:id
  # 특정 조직의 상세 정보를 반환합니다.
  def show
    authorize! :show, @organization
    
    respond_to do |format|
      format.html # renders show.html.erb
      format.json do
        render_serialized(
          OrganizationSerializer,
          @organization,
          params: { 
            current_organization: @organization,
            include_membership: true 
          }
        )
      end
    end
  end
  
  # GET /organizations/new
  # 새 조직 생성 폼을 표시합니다.
  def new
    @organization = Organization.new
    authorize! :new, @organization
  end
  
  # POST /organizations
  # 새로운 조직을 생성합니다.
  def create
    @organization = Organization.new(organization_params)
    authorize! :create, @organization
    
    respond_to do |format|
      if @organization.save
        # 생성자를 소유자로 설정
        @organization.organization_memberships.create!(
          user: current_user,
          role: 'owner'
        )
        
        format.html do
          redirect_to organizations_path, notice: 'Organization was successfully created.'
        end
        format.json do
          render_with_success(
            OrganizationSerializer,
            @organization,
            status: :created
          )
        end
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render_error(@organization.errors) }
      end
    end
  end
  
  # PATCH/PUT /organizations/:id
  # 조직 정보를 업데이트합니다.
  def update
    authorize! :update, @organization
    
    if @organization.update(organization_params)
      render_serialized(OrganizationSerializer, @organization)
    else
      render_error(@organization.errors)
    end
  end
  
  # DELETE /organizations/:id
  # 조직을 삭제합니다.
  def destroy
    authorize! :destroy, @organization
    
    if @organization.destroy
      render_serialized(SuccessSerializer, { message: "조직이 삭제되었습니다." })
    else
      render_error("조직을 삭제할 수 없습니다.")
    end
  end
  
  # GET /dashboard
  # 현재 조직의 대시보드를 표시합니다.
  def dashboard
    unless current_organization
      # 인증된 사용자가 조직에 접근하려고 하지만 권한이 없는 경우
      if current_user
        # 사용자가 속한 첫 번째 조직으로 리다이렉트하거나 조직 선택 페이지로
        first_org = current_user.organizations.first
        if first_org
          redirect_to DomainService.organization_url(first_org.subdomain, 'dashboard'), allow_other_host: true
        else
          redirect_to DomainService.auth_url('organization_selection'), allow_other_host: true
        end
      else
        # 로그인이 필요한 경우
        subdomain = DomainService.extract_subdomain(request)
        return_param = subdomain.present? ? "?return_to=#{subdomain}" : ""
        redirect_to DomainService.auth_url("login#{return_param}"), allow_other_host: true
      end
      return
    end
    
    authorize! :show, current_organization
    
    # 대시보드에서 필요한 데이터들
    @organization = current_organization
    @recent_tasks = Task.accessible_by(current_ability).includes(:assigned_user)
                                     .order(updated_at: :desc)
                                     .limit(10)
    @task_stats = {
      total: Task.accessible_by(current_ability).count,
      todo: Task.accessible_by(current_ability).todo.count,
      in_progress: Task.accessible_by(current_ability).in_progress.count,
      done: Task.accessible_by(current_ability).done.count
    }
    
    if request.format.json?
      render_serialized(OrganizationDashboardSerializer, {
        success: true,
        data: {
          organization: @organization,
          recent_tasks: @recent_tasks,
          task_stats: @task_stats
        }
      }, params: serializer_context)
    else
      # HTML 렌더링 (추후 뷰 파일 생성시)
      render :dashboard
    end
  end
  
  # POST /organizations/:id/switch
  # 현재 작업 중인 조직을 전환합니다.
  def switch
    authorize! :switch, @organization
    
    if current_user.can_access?(@organization)
      # 세션에 현재 조직 정보 저장
      session[:current_organization_id] = @organization.id
      
      organization_url = DomainService.organization_url(@organization.subdomain)
      
      if request.format.json?
        render_serialized(TenantSwitcherSerializer, {
          success: true,
          message: "#{@organization.display_name}으로 전환되었습니다.",
          redirect_url: organization_url,
          data: {
            organization: @organization
          }
        }, params: serializer_context)
      else
        redirect_to organization_url
      end
    else
      render_error("해당 조직에 접근할 권한이 없습니다.", status: :forbidden)
    end
  end
  
  private
  
  def set_organization
    @organization = Organization.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error("조직을 찾을 수 없습니다.", status: :not_found)
  end
  
  def organization_params
    params.require(:organization).permit(:name, :subdomain, :description, :plan)
  end
  
  def serializer_context
    {
      current_user: current_user,
      current_organization: current_organization,
      current_membership: current_membership,
      time_helper: helpers
    }
  end
end
