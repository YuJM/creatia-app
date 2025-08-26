# frozen_string_literal: true

class OrganizationMembershipsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_current_organization
  before_action :set_membership, only: [:show, :update, :destroy]
  
  # GET /organization_memberships
  # 현재 조직의 멤버십 목록을 반환합니다.
  def index
    @memberships = policy_scope(OrganizationMembership)
                     .where(organization: current_organization)
                     .includes(:user, :organization)
    authorize OrganizationMembership
    
    render_serialized(
      OrganizationMembershipSerializer,
      @memberships,
      params: { skip_organization: true }
    )
  end
  
  # GET /organization_memberships/:id
  # 특정 멤버십의 상세 정보를 반환합니다.
  def show
    authorize @membership
    
    render_serialized(
      OrganizationMembershipSerializer,
      @membership
    )
  end
  
  # POST /organization_memberships
  # 새로운 멤버를 조직에 초대합니다.
  def create
    @membership = current_organization.organization_memberships.build(membership_params)
    authorize @membership
    
    # 이메일로 사용자 찾기
    user = User.find_by(email: params[:email])
    unless user
      return render_error("해당 이메일의 사용자를 찾을 수 없습니다.", status: :not_found)
    end
    
    @membership.user = user
    
    if @membership.save
      render_with_success(
        OrganizationMembershipSerializer,
        @membership,
        status: :created
      )
    else
      render_error(@membership.errors)
    end
  end
  
  # PATCH/PUT /organization_memberships/:id
  # 멤버십 정보를 업데이트합니다 (주로 역할 변경).
  def update
    authorize @membership
    
    # 소유자 역할 변경시 특별 처리
    if params[:organization_membership][:role] == 'owner'
      unless policy(@membership).change_role?
        return render_error("소유자 역할을 변경할 권한이 없습니다.", status: :forbidden)
      end
    end
    
    if @membership.update(membership_params)
      render_serialized(OrganizationMembershipSerializer, @membership)
    else
      render_error(@membership.errors)
    end
  end
  
  # DELETE /organization_memberships/:id
  # 멤버를 조직에서 제거합니다.
  def destroy
    authorize @membership
    
    # 자신이 소유자인 경우 탈퇴 방지
    if @membership.owner? && @membership.user == current_user
      return render_error("소유자는 조직을 탈퇴할 수 없습니다. 먼저 소유권을 이전하세요.", status: :forbidden)
    end
    
    if @membership.destroy
      render json: { 
        success: true, 
        message: "#{@membership.user.email}님이 조직에서 제거되었습니다." 
      }
    else
      render_error("멤버십을 삭제할 수 없습니다.")
    end
  end
  
  # PATCH /organization_memberships/:id/toggle_active
  # 멤버십을 활성화/비활성화합니다.
  def toggle_active
    @membership = current_organization.organization_memberships.find(params[:id])
    authorize @membership, :toggle_active?
    
    @membership.update!(active: !@membership.active)
    
    render_serialized(OrganizationMembershipSerializer, @membership)
  end
  
  # POST /organization_memberships/invite
  # 이메일로 멤버를 초대합니다.
  def invite
    authorize OrganizationMembership, :create?
    
    email = params[:email]
    role = params[:role] || 'member'
    
    unless OrganizationMembership::ROLES.include?(role)
      return render_error("유효하지 않은 역할입니다.", status: :unprocessable_entity)
    end
    
    user = User.find_by(email: email)
    unless user
      return render_error("해당 이메일의 사용자를 찾을 수 없습니다.", status: :not_found)
    end
    
    # 이미 멤버인지 확인
    existing_membership = current_organization.organization_memberships
                                             .find_by(user: user)
    if existing_membership
      return render_error("이미 조직의 멤버입니다.", status: :unprocessable_entity)
    end
    
    @membership = current_organization.organization_memberships.create!(
      user: user,
      role: role
    )
    
    render_with_success(
      OrganizationMembershipSerializer,
      @membership,
      status: :created
    )
  end
  
  private
  
  def ensure_current_organization
    unless current_organization
      render_error("조직 컨텍스트가 필요합니다.", status: :bad_request)
    end
  end
  
  def set_membership
    @membership = current_organization.organization_memberships.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error("멤버십을 찾을 수 없습니다.", status: :not_found)
  end
  
  def membership_params
    params.require(:organization_membership).permit(:role, :active)
  end
end
