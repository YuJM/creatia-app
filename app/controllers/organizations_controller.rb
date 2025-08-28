# frozen_string_literal: true

class OrganizationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_organization, only: [:show, :update, :destroy, :switch]
  
  # GET /organizations
  # 사용자가 속한 조직 목록을 반환합니다.
  def index
    @organizations = policy_scope(Organization)
    authorize Organization
    
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
    authorize @organization
    
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
    authorize @organization
  end
  
  # POST /organizations
  # 새로운 조직을 생성합니다.
  def create
    @organization = Organization.new(organization_params)
    authorize @organization
    
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
    authorize @organization
    
    if @organization.update(organization_params)
      render_serialized(OrganizationSerializer, @organization)
    else
      render_error(@organization.errors)
    end
  end
  
  # DELETE /organizations/:id
  # 조직을 삭제합니다.
  def destroy
    authorize @organization
    
    if @organization.destroy
      render json: { success: true, message: "조직이 삭제되었습니다." }
    else
      render_error("조직을 삭제할 수 없습니다.")
    end
  end
  
  # GET /dashboard
  # 현재 조직의 대시보드를 표시합니다.
  def dashboard
    unless current_organization
      redirect_to DomainService.main_url, allow_other_host: true
      return
    end
    
    authorize current_organization, :show?
    
    # 대시보드에서 필요한 데이터들
    @organization = current_organization
    @recent_tasks = policy_scope(Task).includes(:assigned_user)
                                     .order(updated_at: :desc)
                                     .limit(10)
    @task_stats = {
      total: policy_scope(Task).count,
      todo: policy_scope(Task).todo.count,
      in_progress: policy_scope(Task).in_progress.count,
      done: policy_scope(Task).done.count
    }
    
    if request.format.json?
      render json: {
        success: true,
        data: {
          organization: OrganizationSerializer.new(@organization, params: serializer_context).serializable_hash,
          recent_tasks: TaskSerializer.new(@recent_tasks, params: serializer_context.merge(skip_organization: true)).serializable_hash,
          task_stats: @task_stats
        }
      }
    else
      # HTML 렌더링 (추후 뷰 파일 생성시)
      render :dashboard
    end
  end
  
  # POST /organizations/:id/switch
  # 현재 작업 중인 조직을 전환합니다.
  def switch
    authorize @organization, :switch?
    
    if current_user.can_access?(@organization)
      # 세션에 현재 조직 정보 저장
      session[:current_organization_id] = @organization.id
      
      organization_url = DomainService.organization_url(@organization.subdomain)
      
      if request.format.json?
        render json: {
          success: true,
          message: "#{@organization.display_name}으로 전환되었습니다.",
          redirect_url: organization_url,
          organization: OrganizationSerializer.new(
            @organization,
            params: serializer_context
          ).serializable_hash
        }
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
