# frozen_string_literal: true

module Web
  class OrganizationMembershipsController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_current_organization
    before_action :set_membership, only: [:show, :edit, :update, :destroy]
    
    # GET /organization_memberships
    def index
      @memberships = OrganizationMembership.accessible_by(current_ability)
                       .where(organization: current_organization)
                       .includes(:user, :organization, :role)
                       .page(params[:page])
      
      authorize! :index, OrganizationMembership
    end
    
    # GET /organization_memberships/:id
    def show
      authorize! :show, @membership
    end
    
    # GET /organization_memberships/new
    def new
      @membership = current_organization.organization_memberships.build
      authorize! :new, @membership
    end
    
    # GET /organization_memberships/:id/edit
    def edit
      authorize! :edit, @membership
    end
    
    # POST /organization_memberships
    def create
      @membership = current_organization.organization_memberships.build(membership_params)
      authorize! :create, @membership
      
      # 이메일로 사용자 찾기
      if params[:email].present?
        user = User.find_by(email: params[:email])
        unless user
          flash[:alert] = "해당 이메일의 사용자를 찾을 수 없습니다."
          render :new, status: :unprocessable_entity
          return
        end
        @membership.user = user
      end
      
      if @membership.save
        respond_to do |format|
          format.html { redirect_to web_organization_membership_path(@membership), notice: '멤버가 추가되었습니다.' }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.append("members_list",
                render_to_string(partial: "organization_memberships/member_row", locals: { membership: @membership })
              ),
              turbo_stream.replace("flash_messages",
                render_to_string(partial: "shared/flash_messages")
              )
            ]
          end
        end
      else
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace("membership_form",
              render_to_string(partial: "organization_memberships/form", locals: { membership: @membership })
            )
          end
        end
      end
    end
    
    # PATCH/PUT /organization_memberships/:id
    def update
      authorize! :update, @membership
      
      # 소유자 역할 변경시 특별 처리
      if params[:organization_membership][:role] == 'owner'
        unless can?(:change_role, @membership)
          flash[:alert] = "소유자 역할을 변경할 권한이 없습니다."
          render :edit, status: :forbidden
          return
        end
      end
      
      if @membership.update(membership_params)
        respond_to do |format|
          format.html { redirect_to web_organization_membership_path(@membership), notice: '멤버 정보가 업데이트되었습니다.' }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace("membership_#{@membership.id}",
                render_to_string(partial: "organization_memberships/member_row", locals: { membership: @membership })
              ),
              turbo_stream.replace("flash_messages",
                render_to_string(partial: "shared/flash_messages")
              )
            ]
          end
        end
      else
        respond_to do |format|
          format.html { render :edit, status: :unprocessable_entity }
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace("membership_form",
              render_to_string(partial: "organization_memberships/form", locals: { membership: @membership })
            )
          end
        end
      end
    end
    
    # DELETE /organization_memberships/:id
    def destroy
      authorize! :destroy, @membership
      
      # 자신이 소유자인 경우 탈퇴 방지
      if @membership.owner? && @membership.user == current_user
        flash[:alert] = "소유자는 조직을 탈퇴할 수 없습니다. 먼저 소유권을 이전하세요."
        redirect_to web_organization_memberships_path, status: :see_other
        return
      end
      
      if @membership.destroy
        respond_to do |format|
          format.html { 
            redirect_to web_organization_memberships_path, 
            notice: "#{@membership.user.email}님이 조직에서 제거되었습니다.",
            status: :see_other 
          }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.remove("membership_#{@membership.id}"),
              turbo_stream.replace("flash_messages",
                render_to_string(partial: "shared/flash_messages")
              )
            ]
          end
        end
      else
        flash[:alert] = "멤버십을 삭제할 수 없습니다."
        redirect_to web_organization_memberships_path, status: :see_other
      end
    end
    
    # PATCH /organization_memberships/:id/toggle_active
    def toggle_active
      @membership = current_organization.organization_memberships.find(params[:id])
      authorize! :toggle_active, @membership
      
      @membership.update!(active: !@membership.active)
      
      respond_to do |format|
        format.html { redirect_to web_organization_membership_path(@membership), notice: '멤버 상태가 변경되었습니다.' }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("membership_#{@membership.id}",
            render_to_string(partial: "organization_memberships/member_row", locals: { membership: @membership })
          )
        end
      end
    end
    
    private
    
    def ensure_current_organization
      unless current_organization
        redirect_to root_path, alert: "조직 컨텍스트가 필요합니다."
      end
    end
    
    def set_membership
      @membership = current_organization.organization_memberships.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to web_organization_memberships_path, alert: "멤버십을 찾을 수 없습니다."
    end
    
    def membership_params
      params.require(:organization_membership).permit(:role, :role_id, :active)
    end
  end
end