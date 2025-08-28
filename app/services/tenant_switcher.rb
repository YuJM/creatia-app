# frozen_string_literal: true

# TenantSwitcher - 조직 간 전환을 처리하는 서비스
# 
# 이 서비스는 다음을 제공합니다:
# - 안전한 조직 전환
# - 전환 가능한 조직 목록 제공
# - 전환 이력 관리
# - UI에서 사용할 전환 정보 제공
class TenantSwitcher
  prepend MemoWise
  include Dry::Monads[:result]
  
  class SwitchError < StandardError; end
  class UnauthorizedSwitch < SwitchError; end
  class InvalidTarget < SwitchError; end
  
  attr_reader :user, :session, :current_organization
  
  def initialize(user, session = nil)
    @user = user
    @session = session
    @current_organization = ActsAsTenant.current_tenant
  end
  
  # 사용자가 전환할 수 있는 조직 목록을 반환합니다. (메모이제이션 적용)
  memo_wise def available_organizations
    return Organization.none unless @user
    
    @user.organizations.active
         .includes(:organization_memberships)
         .order(:name)
  end
  
  # 조직 전환을 수행합니다. (Result 패턴 적용)
  def switch_to!(target_subdomain_or_org, options = {})
    target_organization = resolve_target_organization(target_subdomain_or_org)
    
    # 유효성 검증
    case validate_switch(target_organization)
    in Success()
      # 전환 수행
      perform_switch!(target_organization, options)
      
      # 전환 이력 기록 (옵션)
      record_switch_history(target_organization) if options[:record_history]
      
      Success({
        organization: organization_info(target_organization),
        redirect_url: DomainService.organization_url(target_organization.subdomain),
        message: "#{target_organization.display_name}으로 전환되었습니다."
      })
    in Failure(error)
      Failure({
        error: error,
        current_organization: @current_organization ? organization_info(@current_organization) : nil
      })
    end
  rescue SwitchError => e
    Failure({
      error: e.message,
      current_organization: @current_organization ? organization_info(@current_organization) : nil
    })
  end
  
  # 조직 전환이 가능한지 확인합니다.
  def can_switch_to?(target_subdomain_or_org)
    target_organization = resolve_target_organization(target_subdomain_or_org)
    return false unless target_organization
    
    @user.can_access?(target_organization)
  rescue StandardError
    false
  end
  
  # 현재 조직에서 나가기 (로그아웃하지는 않고 테넌트 컨텍스트만 클리어)
  def leave_current_organization!
    if @current_organization
      ActsAsTenant.current_tenant = nil
      @session&.delete(:current_organization_id)
      
      {
        success: true,
        message: "#{@current_organization.display_name}에서 나왔습니다.",
        redirect_url: DomainService.auth_url('organization_selection')
      }
    else
      {
        success: false,
        error: "현재 조직이 설정되지 않았습니다."
      }
    end
  end
  
  # 조직 전환 UI에서 사용할 정보를 반환합니다.
  def switcher_data
    organizations = available_organizations.map do |org|
      membership = @user.organization_memberships.find_by(organization: org, active: true)
      
      {
        id: org.id,
        name: org.name,
        subdomain: org.subdomain,
        display_name: org.display_name,
        plan: org.plan,
        role: membership&.role,
        is_current: org == @current_organization,
        url: DomainService.organization_url(org.subdomain),
        member_count: org.organization_memberships.active.count,
        last_accessed: get_last_accessed_time(org)
      }
    end
    
    {
      current_organization: @current_organization ? organization_info(@current_organization) : nil,
      available_organizations: organizations,
      total_organizations: organizations.length,
      switch_history: recent_switch_history
    }
  end
  
  # 최근 전환 이력을 반환합니다.
  def recent_switch_history(limit = 5)
    return [] unless @session && @session[:organization_switch_history]
    
    history = @session[:organization_switch_history] || []
    history.last(limit).map do |entry|
      {
        subdomain: entry['subdomain'],
        name: entry['name'],
        switched_at: Time.parse(entry['switched_at']),
        url: DomainService.organization_url(entry['subdomain'])
      }
    end
  rescue StandardError
    []
  end
  
  # 즐겨찾기 조직 목록을 반환합니다.
  def favorite_organizations
    # 향후 구현: 사용자별 즐겨찾기 조직 설정 기능
    # 현재는 가장 최근에 접근한 조직들을 반환
    recent_switch_history(3)
  end
  
  # 조직 전환 통계를 반환합니다.
  def switch_statistics
    {
      total_organizations: available_organizations.count,
      owned_organizations: @user.owned_organizations.count,
      administered_organizations: @user.administered_organizations.count,
      recent_switches: recent_switch_history.count,
      current_role: @current_organization ? @user.role_in(@current_organization) : nil
    }
  end
  
  # 빠른 전환 (자주 사용하는 조직들)
  def quick_switch_options
    organizations = available_organizations.limit(5)
    
    organizations.map do |org|
      {
        subdomain: org.subdomain,
        name: org.name,
        display_name: org.display_name,
        role: @user.role_in(org),
        is_current: org == @current_organization,
        url: DomainService.organization_url(org.subdomain)
      }
    end
  end
  
  private
  
  # 대상 조직을 확인합니다.
  def resolve_target_organization(target)
    case target
    when Organization
      target
    when String
      Organization.find_by(subdomain: target)
    else
      raise InvalidTarget, "유효하지 않은 조직 식별자입니다."
    end
  end
  
  # 전환 유효성을 검증합니다. (Result 패턴 적용)
  def validate_switch(target_organization)
    return Failure("조직을 찾을 수 없습니다.") unless target_organization
    return Failure("비활성화된 조직입니다.") unless target_organization.active?
    return Failure("해당 조직에 접근할 권한이 없습니다.") unless @user.can_access?(target_organization)
    return Failure("이미 현재 조직입니다.") if target_organization == @current_organization
    
    Success()
  end
  
  # 실제 전환을 수행합니다.
  def perform_switch!(target_organization, options = {})
    # acts_as_tenant 컨텍스트 변경
    ActsAsTenant.current_tenant = target_organization
    @current_organization = target_organization
    
    # 세션에 현재 조직 정보 저장
    if @session
      @session[:current_organization_id] = target_organization.id
      @session.delete(:return_organization)
      
      # 최근 접근 시간 업데이트
      update_last_accessed_time(target_organization)
    end
    
    Rails.logger.info "[TENANT_SWITCHER] User #{@user.id} switched to organization #{target_organization.subdomain}"
  end
  
  # 전환 이력을 기록합니다.
  def record_switch_history(organization)
    return unless @session
    
    history = @session[:organization_switch_history] ||= []
    
    # 기존 항목 제거 (중복 방지)
    history.reject! { |entry| entry['subdomain'] == organization.subdomain }
    
    # 새 항목 추가
    history << {
      'subdomain' => organization.subdomain,
      'name' => organization.name,
      'switched_at' => Time.current.iso8601
    }
    
    # 최대 10개까지만 유지
    @session[:organization_switch_history] = history.last(10)
  end
  
  # 조직 정보를 해시로 반환합니다.
  def organization_info(organization)
    {
      id: organization.id,
      name: organization.name,
      subdomain: organization.subdomain,
      display_name: organization.display_name,
      plan: organization.plan,
      user_role: @user.role_in(organization),
      member_count: organization.organization_memberships.active.count
    }
  end
  
  # 마지막 접근 시간을 업데이트합니다.
  def update_last_accessed_time(organization)
    return unless @session
    
    last_accessed = @session[:last_accessed_organizations] ||= {}
    last_accessed[organization.subdomain.to_s] = Time.current.iso8601
    
    # 최대 20개 조직의 접근 시간만 유지
    if last_accessed.size > 20
      sorted_times = last_accessed.sort_by { |_, time| Time.parse(time) }
      @session[:last_accessed_organizations] = sorted_times.last(20).to_h
    end
  end
  
  # 마지막 접근 시간을 가져옵니다.
  def get_last_accessed_time(organization)
    return nil unless @session && @session[:last_accessed_organizations]
    
    time_str = @session[:last_accessed_organizations][organization.subdomain.to_s]
    time_str ? Time.parse(time_str) : nil
  rescue StandardError
    nil
  end
end
