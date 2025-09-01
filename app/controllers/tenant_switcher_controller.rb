# frozen_string_literal: true

# TenantSwitcherController - 조직 간 전환을 처리하는 API 컨트롤러
# 
# 이 컨트롤러는 다음을 제공합니다:
# - AJAX/API를 통한 빠른 조직 전환
# - 전환 가능한 조직 목록 제공
# - 전환 이력 및 통계 제공
# - 즐겨찾기 조직 관리
class TenantSwitcherController < ApplicationController
  before_action :authenticate_user!
  before_action :set_tenant_switcher
  
  # GET /tenant_switcher
  # 조직 전환 UI에 필요한 모든 데이터를 반환합니다.
  def show
    data = @tenant_switcher.switcher_data
    
    respond_to do |format|
      format.json do
        render_serialized(TenantSwitcherSerializer, {
          success: true,
          data: data
        })
      end
      format.html do
        @switcher_data = data
        # organization_switcher.html.erb 뷰 렌더링
      end
    end
  end
  
  # POST /tenant_switcher/switch
  # 지정된 조직으로 전환합니다.
  def switch
    subdomain = switcher_params[:subdomain]
    
    unless subdomain.present?
      return render_serialized(TenantSwitcherSerializer, {
        success: false,
        error: "조직 서브도메인이 필요합니다."
      }, status: :bad_request)
    end
    
    # 전환 전 현재 조직 정보 저장
    from_tenant = current_organization
    to_tenant = ::Organization.find_by(subdomain: subdomain)
    
    result = @tenant_switcher.switch_to!(subdomain, record_history: true)
    
    case result
    in Success(data)
      # 테넌트 전환 성공 감사 로그
      SecurityAuditService.log_tenant_switch(current_user, from_tenant, to_tenant, request)
      data[:success] = true
      render_serialized(TenantSwitcherSerializer, data)
    in Failure(error_data)
      # 무권한 테넌트 접근 시도 감사 로그
      SecurityAuditService.log_cross_tenant_access(current_user, to_tenant, from_tenant, request)
      error_data[:success] = false
      render_serialized(TenantSwitcherSerializer, error_data, status: :forbidden)
    end
  end
  
  # GET /tenant_switcher/available
  # 전환 가능한 조직 목록을 반환합니다.
  def available
    organizations = @tenant_switcher.available_organizations
    
    serialized_organizations = organizations.map do |org|
      membership = current_user.organization_memberships.find_by(organization: org, active: true)
      
      {
        id: org.id,
        name: org.name,
        subdomain: org.subdomain,
        display_name: org.display_name,
        plan: org.plan,
        role: membership&.role,
        is_current: org == current_organization,
        url: DomainService.organization_url(org.subdomain),
        member_count: org.organization_memberships.active.count
      }
    end
    
    render_serialized(TenantSwitcherSerializer, {
      success: true,
      organizations: serialized_organizations,
      data: { total_count: serialized_organizations.count }
    })
  end
  
  # GET /tenant_switcher/quick_options
  # 빠른 전환 옵션 (자주 사용하는 조직)을 반환합니다.
  def quick_options
    options = @tenant_switcher.quick_switch_options
    
    render_serialized(TenantSwitcherSerializer, {
      success: true,
      quick_options: options
    })
  end
  
  # GET /tenant_switcher/history
  # 최근 전환 이력을 반환합니다.
  def history
    limit = history_params[:limit]&.to_i || 10
    history = @tenant_switcher.recent_switch_history(limit)
    
    render_serialized(TenantSwitcherSerializer, {
      success: true,
      history: history,
      data: { total_count: history.count }
    })
  end
  
  # GET /tenant_switcher/statistics
  # 전환 통계를 반환합니다.
  def statistics
    stats = @tenant_switcher.switch_statistics
    
    render json: {
      success: true,
      statistics: stats
    }
  end
  
  # POST /tenant_switcher/leave
  # 현재 조직에서 나가기 (테넌트 컨텍스트 클리어)
  def leave
    result = @tenant_switcher.leave_current_organization!
    
    if result[:success]
      render json: result
    else
      render json: result, status: :bad_request
    end
  end
  
  # GET /tenant_switcher/context
  # 현재 테넌트 컨텍스트 정보를 반환합니다.
  def context
    context_info = tenant_context&.context_info || {}
    
    render_serialized(TenantSwitcherSerializer, {
      success: true,
      context: context_info,
      data: { debug: Rails.env.development? ? tenant_context&.debug_info : nil }
    })
  end
  
  # POST /tenant_switcher/validate_access
  # 특정 조직에 대한 접근 권한을 확인합니다.
  def validate_access
    subdomain = switcher_params[:subdomain]
    
    unless subdomain.present?
      return render_serialized(TenantSwitcherSerializer, {
        success: false,
        error: "조직 서브도메인이 필요합니다."
      }, status: :bad_request)
    end
    
    can_access = @tenant_switcher.can_switch_to?(subdomain)
    organization = ::Organization.find_by(subdomain: subdomain)
    
    response_data = {
      success: true,
      can_access: can_access,
      subdomain: subdomain
    }
    
    if organization
      response_data[:organization] = {
        id: organization.id,
        name: organization.name,
        display_name: organization.display_name,
        plan: organization.plan,
        active: organization.active?
      }
      
      if can_access
        membership = current_user.organization_memberships.find_by(organization: organization, active: true)
        response_data[:user_role] = membership&.role
      end
    else
      response_data[:error] = "조직을 찾을 수 없습니다."
    end
    
    render json: response_data
  end
  
  # PUT /tenant_switcher/update_preferences
  # 사용자의 조직 전환 관련 설정을 업데이트합니다.
  def update_preferences
    preferences = preferences_params[:preferences] || {}
    
    # 세션에 사용자 설정 저장
    session[:switcher_preferences] = {
      show_member_count: preferences[:show_member_count],
      sort_by: preferences[:sort_by] || 'name',
      show_recent_first: preferences[:show_recent_first],
      quick_switch_count: [preferences[:quick_switch_count]&.to_i || 5, 10].min
    }
    
    render json: {
      success: true,
      message: "설정이 저장되었습니다.",
      preferences: session[:switcher_preferences]
    }
  end
  
  private
  
  def set_tenant_switcher
    @tenant_switcher = TenantSwitcher.new(current_user, session)
  end

  def switcher_params
    params.permit(:subdomain)
  end

  def history_params
    params.permit(:limit)
  end

  def preferences_params
    params.permit(preferences: [:show_member_count, :sort_by, :show_recent_first, :quick_switch_count])
  end
end
