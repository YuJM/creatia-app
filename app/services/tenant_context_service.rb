# frozen_string_literal: true

# TenantContextService - 테넌트 컨텍스트를 관리하는 서비스
# 
# 이 서비스는 다음을 제공합니다:
# - 현재 테넌트 컨텍스트 설정 및 관리
# - 사용자별 접근 가능한 조직 확인
# - 테넌트 전환 및 세션 관리
# - 안전한 테넌트 격리
class TenantContextService
  prepend MemoWise
  
  class TenantNotFound < StandardError; end
  class AccessDenied < StandardError; end
  class InvalidTenant < StandardError; end
  
  attr_reader :request, :user, :subdomain, :organization
  
  def initialize(request, user = nil)
    @request = request
    @user = user
    @subdomain = DomainService.extract_subdomain(request)
  end
  
  # 현재 요청에 대한 테넌트 컨텍스트를 설정합니다.
  def setup_tenant_context!
    # 서브도메인이 없거나 예약된 경우 건너뛰기
    return nil if skip_tenant_setup?
    
    # 조직 찾기 및 유효성 검증
    @organization = find_and_validate_organization!
    
    # acts_as_tenant 컨텍스트 설정
    ActsAsTenant.current_tenant = @organization
    
    # 사용자 접근 권한 확인 (사용자가 있는 경우)
    verify_user_access! if @user
    
    @organization
  end
  
  # 현재 테넌트가 설정되어 있는지 확인
  def tenant_set?
    ActsAsTenant.current_tenant.present?
  end
  
  # 현재 테넌트 반환
  def current_tenant
    ActsAsTenant.current_tenant
  end
  
  # 테넌트 컨텍스트를 클리어합니다.
  def clear_tenant_context!
    ActsAsTenant.current_tenant = nil
  end
  
  # 테넌트 컨텍스트를 임시로 전환합니다.
  def with_tenant(organization)
    original_tenant = ActsAsTenant.current_tenant
    begin
      ActsAsTenant.current_tenant = organization
      yield
    ensure
      ActsAsTenant.current_tenant = original_tenant
    end
  end
  
  # 사용자가 현재 조직에 접근할 수 있는지 확인
  def user_can_access?
    return false unless @user && @organization
    @user.can_access?(@organization)
  end
  
  # 사용자의 현재 조직에서의 역할 반환
  def user_role
    return nil unless @user && @organization
    @user.role_in(@organization)
  end
  
  # 사용자의 현재 조직에서의 멤버십 반환 (메모이제이션 적용)
  memo_wise def user_membership
    return nil unless @user && @organization
    @user.organization_memberships.find_by(organization: @organization, active: true)
  end
  
  # 사용자가 접근 가능한 모든 조직 반환 (메모이제이션 적용)
  memo_wise def accessible_organizations
    return Organization.none unless @user
    @user.organizations.active
  end
  
  # 조직 전환이 가능한지 확인
  def can_switch_to?(target_organization)
    return false unless @user
    @user.can_access?(target_organization)
  end
  
  # 조직 전환을 수행합니다.
  def switch_to!(target_organization, session = nil)
    unless can_switch_to?(target_organization)
      raise AccessDenied, "조직에 접근할 권한이 없습니다: #{target_organization.subdomain}"
    end
    
    # 테넌트 컨텍스트 변경
    ActsAsTenant.current_tenant = target_organization
    @organization = target_organization
    
    # 세션에 현재 조직 정보 저장 (세션이 제공된 경우)
    if session
      session[:current_organization_id] = target_organization.id
      session.delete(:return_organization)
    end
    
    target_organization
  end
  
  # 현재 컨텍스트 정보를 해시로 반환
  def context_info
    {
      subdomain: @subdomain,
      organization: @organization&.as_json(only: [:id, :name, :subdomain, :plan]),
      user_role: user_role,
      user_membership: user_membership&.as_json(only: [:id, :role, :active]),
      tenant_set: tenant_set?,
      accessible_organizations_count: accessible_organizations.count
    }
  end
  
  # 디버깅 정보 반환
  def debug_info
    {
      request_host: @request.host,
      request_subdomain: @request.subdomain,
      extracted_subdomain: @subdomain,
      organization_found: @organization.present?,
      organization_id: @organization&.id,
      acts_as_tenant_current: ActsAsTenant.current_tenant&.id,
      user_present: @user.present?,
      user_can_access: user_can_access?,
      user_role: user_role
    }
  end
  
  class << self
    # 편의 메서드: 요청에 대한 테넌트 컨텍스트를 빠르게 설정
    def setup_for_request!(request, user = nil)
      service = new(request, user)
      service.setup_tenant_context!
      service
    end
    
    # 편의 메서드: 현재 테넌트 정보 반환
    def current_info
      tenant = ActsAsTenant.current_tenant
      return nil unless tenant
      
      {
        id: tenant.id,
        name: tenant.name,
        subdomain: tenant.subdomain,
        plan: tenant.plan
      }
    end
    
    # 편의 메서드: 테넌트 컨텍스트 클리어
    def clear!
      ActsAsTenant.current_tenant = nil
    end
  end
  
  private
  
  # 테넌트 설정을 건너뛸지 확인
  def skip_tenant_setup?
    @subdomain.blank? || DomainService.reserved_subdomain?(@subdomain)
  end
  
  # 조직을 찾고 유효성을 검증합니다.
  def find_and_validate_organization!
    organization = Organization.find_by(subdomain: @subdomain)
    
    unless organization
      raise TenantNotFound, "조직을 찾을 수 없습니다: #{@subdomain}"
    end
    
    unless organization.active?
      raise InvalidTenant, "비활성화된 조직입니다: #{@subdomain}"
    end
    
    organization
  end
  
  # 사용자의 조직 접근 권한을 확인합니다.
  def verify_user_access!
    unless user_can_access?
      raise AccessDenied, "조직에 접근할 권한이 없습니다: #{@subdomain}"
    end
  end
end
