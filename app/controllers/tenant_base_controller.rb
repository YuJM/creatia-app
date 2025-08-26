# frozen_string_literal: true

# TenantBaseController - 테넌트(조직) 내 리소스를 다루는 컨트롤러의 기본 클래스
# 
# 이 컨트롤러는 다음을 제공합니다:
# - 조직 컨텍스트 확인
# - acts_as_tenant 자동 설정
# - 공통 권한 확인
# - 표준화된 에러 처리
class TenantBaseController < ApplicationController
  include TenantSecurity
  
  before_action :authenticate_user!
  before_action :ensure_tenant_context
  before_action :verify_organization_membership
  
  # 강화된 보안 모드 활성화
  enable_enhanced_tenant_security
  
  protected
  
  # 현재 조직 컨텍스트가 설정되어 있는지 확인
  def ensure_tenant_context
    unless current_organization
      render_error(
        "조직 컨텍스트가 필요합니다. 올바른 서브도메인으로 접근해주세요.", 
        status: :bad_request
      )
      return false
    end
    
    # acts_as_tenant 컨텍스트 설정
    ActsAsTenant.current_tenant = current_organization
    true
  end
  
  # 사용자가 현재 조직의 멤버인지 확인
  def verify_organization_membership
    unless current_user.member_of?(current_organization)
      render_error(
        "이 조직에 접근할 권한이 없습니다.", 
        status: :forbidden
      )
      return false
    end
    true
  end
  
  # 테넌트별 정책 스코프 적용
  def apply_tenant_scope(model_class)
    policy_scope(model_class).where(organization: current_organization)
  end
  
  # 테넌트별 리소스 생성시 조직 자동 할당
  def build_tenant_resource(model_class, params = {})
    resource = model_class.new(params)
    resource.organization = current_organization if resource.respond_to?(:organization=)
    resource
  end
  
  # 권한 확인 헬퍼들
  def require_member!
    unless current_membership
      render_error("조직 멤버만 접근 가능합니다.", status: :forbidden)
      return false
    end
    true
  end
  
  def require_admin!
    unless current_membership&.admin?
      render_error("관리자 권한이 필요합니다.", status: :forbidden)
      return false
    end
    true
  end
  
  def require_owner!
    unless current_membership&.owner?
      render_error("소유자 권한이 필요합니다.", status: :forbidden)
      return false
    end
    true
  end
  
  # 표준 CRUD 액션들을 위한 헬퍼 메서드들
  
  # 표준 index 액션 구현
  def render_tenant_index(model_class, serializer_class, additional_includes: [], additional_params: {})
    resources = apply_tenant_scope(model_class)
    resources = resources.includes(additional_includes) if additional_includes.any?
    
    authorize model_class
    
    render_serialized(
      serializer_class,
      resources,
      params: additional_params
    )
  end
  
  # 표준 show 액션 구현
  def render_tenant_show(resource, serializer_class, additional_params: {})
    authorize resource
    
    render_serialized(
      serializer_class,
      resource,
      params: additional_params
    )
  end
  
  # 표준 create 액션 구현
  def create_tenant_resource(model_class, serializer_class, resource_params, additional_params: {})
    resource = build_tenant_resource(model_class, resource_params)
    authorize resource
    
    if resource.save
      render_with_success(
        serializer_class,
        resource,
        status: :created,
        params: additional_params
      )
    else
      render_error(resource.errors)
    end
  end
  
  # 표준 update 액션 구현
  def update_tenant_resource(resource, serializer_class, resource_params, additional_params: {})
    authorize resource
    
    if resource.update(resource_params)
      render_serialized(
        serializer_class,
        resource,
        params: additional_params
      )
    else
      render_error(resource.errors)
    end
  end
  
  # 표준 destroy 액션 구현
  def destroy_tenant_resource(resource, success_message = nil)
    authorize resource
    
    if resource.destroy
      message = success_message || "#{resource.class.name.humanize}가 삭제되었습니다."
      render json: { success: true, message: message }
    else
      render_error("삭제할 수 없습니다.")
    end
  end
  
  private
  
  # Pundit 검증을 건너뛸 조건들 (부모 클래스 메서드 오버라이드)
  def skip_pundit?
    false # 테넌트 컨트롤러에서는 항상 권한 검증 수행
  end
  
  def skip_organization_check?
    false # 테넌트 컨트롤러에서는 항상 조직 검증 수행
  end
end
