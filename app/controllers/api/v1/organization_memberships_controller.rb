# frozen_string_literal: true

module Api
  module V1
    class OrganizationMembershipsController < BaseController
      before_action :ensure_current_organization
      before_action :set_membership, only: [:show, :update, :destroy]
      
      # GET /api/v1/organization_memberships
      def index
        @memberships = OrganizationMembership.accessible_by(current_ability)
                         .where(organization: current_organization)
                         .includes(:user, :organization, :role)
                         .page(params[:page]).per(params[:per_page] || 25)
        
        authorize! :index, OrganizationMembership
        
        render_serialized(
          OrganizationMembershipSerializer,
          @memberships,
          params: { skip_organization: true }
        )
      end
      
      # GET /api/v1/organization_memberships/:id
      def show
        authorize! :show, @membership
        
        render_serialized(
          OrganizationMembershipSerializer,
          @membership
        )
      end
      
      # POST /api/v1/organization_memberships
      def create
        @membership = current_organization.organization_memberships.build(membership_params)
        authorize! :create, @membership
        
        # 이메일로 사용자 찾기
        if params[:email].present?
          user = User.find_by(email: params[:email])
          unless user
            return render_error("해당 이메일의 사용자를 찾을 수 없습니다.", status: :not_found)
          end
          @membership.user = user
        end
        
        # 이미 멤버인지 확인
        existing_membership = current_organization.organization_memberships.find_by(user: @membership.user)
        if existing_membership
          return render_error("이미 조직의 멤버입니다.", status: :unprocessable_entity)
        end
        
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
      
      # PATCH/PUT /api/v1/organization_memberships/:id
      def update
        authorize! :update, @membership
        
        # 소유자 역할 변경시 특별 처리
        if params[:organization_membership][:role] == 'owner'
          unless can?(:change_role, @membership)
            return render_error("소유자 역할을 변경할 권한이 없습니다.", status: :forbidden)
          end
        end
        
        if @membership.update(membership_params)
          render_serialized(OrganizationMembershipSerializer, @membership)
        else
          render_error(@membership.errors)
        end
      end
      
      # DELETE /api/v1/organization_memberships/:id
      def destroy
        authorize! :destroy, @membership
        
        # 자신이 소유자인 경우 탈퇴 방지
        if @membership.owner? && @membership.user == current_user
          return render_error("소유자는 조직을 탈퇴할 수 없습니다. 먼저 소유권을 이전하세요.", status: :forbidden)
        end
        
        if @membership.destroy
          render_serialized(SuccessSerializer, { 
            message: "#{@membership.user.email}님이 조직에서 제거되었습니다." 
          })
        else
          render_error("멤버십을 삭제할 수 없습니다.")
        end
      end
      
      # PATCH /api/v1/organization_memberships/:id/toggle_active
      def toggle_active
        @membership = current_organization.organization_memberships.find(params[:id])
        authorize! :toggle_active, @membership
        
        @membership.update!(active: !@membership.active)
        
        render_serialized(OrganizationMembershipSerializer, @membership)
      end
      
      # POST /api/v1/organization_memberships/invite
      def invite
        authorize! :create, OrganizationMembership
        
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
        existing_membership = current_organization.organization_memberships.find_by(user: user)
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
        params.require(:organization_membership).permit(:role, :role_id, :active, :user_id)
      end
    end
  end
end