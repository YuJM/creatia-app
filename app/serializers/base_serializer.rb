# frozen_string_literal: true

# BaseSerializer - 모든 Alba serializer의 부모 클래스
# JSON 응답의 키를 camelCase로 변환하는 기본 설정을 제공합니다.
class BaseSerializer
  include Alba::Resource
  
  # 모든 키를 camelCase로 변환
  transform_keys :lower_camel
  
  # 멀티테넌트 관련 공통 속성들
  
  # params 헬퍼 메서드 - Alba에서 params가 nil일 수 있음
  def params
    @params || {}
  end
  
  # 현재 조직 정보를 params에서 가져오는 헬퍼
  def current_organization
    params[:current_organization] || ActsAsTenant.current_tenant
  end
  
  # 현재 사용자 정보를 가져오는 헬퍼
  def current_user
    params[:current_user]
  end
  
  # 현재 사용자의 멤버십 정보를 가져오는 헬퍼
  def current_membership
    return nil unless current_user && current_organization
    
    params[:current_membership] || 
      current_user.organization_memberships.find_by(
        organization: current_organization, 
        active: true
      )
  end
  
  # 권한 확인 헬퍼
  def can_view_details?
    return false unless current_membership
    current_membership.role.in?(%w[owner admin member])
  end
  
  def can_admin?
    return false unless current_membership
    current_membership.role.in?(%w[owner admin])
  end
  
  def is_owner?
    return false unless current_membership
    current_membership.role == 'owner'
  end
end
