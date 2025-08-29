# frozen_string_literal: true

# Users::SessionsController - SSO 중앙 인증을 처리하는 커스텀 Devise 컨트롤러
class Users::SessionsController < Devise::SessionsController
  layout 'auth', only: [:new, :create]
  layout 'public', only: [:organization_selection, :access_denied]
  before_action :check_auth_domain, except: [:destroy]
  before_action :store_return_organization, only: [:new, :create]
  
  # GET /users/sign_in
  def new
    # 이미 로그인되어 있으면 조직 선택 페이지로
    if user_signed_in?
      redirect_to_organization_selection
      return
    end
    
    super
  end
  
  # POST /users/sign_in
  def create
    # 로그인 시도 전 이메일 기록
    attempted_email = params.dig(:user, :email)
    
    super do |user|
      if user.persisted?
        # 로그인 성공 감사 로그
        SecurityAuditService.log_login_success(user, request)
        handle_successful_login(user)
        return
      else
        # 로그인 실패 감사 로그
        SecurityAuditService.log_login_failure(
          attempted_email, 
          request, 
          user.errors.full_messages.join(', ')
        )
      end
    end
  end
  
  # DELETE /users/sign_out
  def destroy
    # 로그아웃 후 메인 도메인으로 리다이렉트
    super do
      store_location_for(:user, DomainService.main_url)
    end
  end
  
  # GET /organization_selection
  # 로그인 후 조직 선택 페이지
  def organization_selection
    unless user_signed_in?
      redirect_to new_user_session_path
      return
    end
    
    @organizations = current_user.organizations.active.includes(:organization_memberships)
    @return_organization = session[:return_organization]
    
    respond_to do |format|
      format.html # organization_selection.html.erb
      format.json do
        render_serialized(SessionResponseSerializer, {
          success: true,
          user: UserSerializer.new(
            current_user, 
            params: { include_organizations: true }
          ).serializable_hash,
          organizations: OrganizationSerializer.new(
            @organizations,
            params: { current_user: current_user }
          ).serializable_hash,
          return_organization: @return_organization
        })
      end
    end
  end
  
  # POST /switch_to_organization
  # 선택된 조직으로 이동
  def switch_to_organization
    unless user_signed_in?
      render_serialized(SessionResponseSerializer, { success: false, error: "로그인이 필요합니다." }, status: :unauthorized)
      return
    end
    
    organization_subdomain = params[:subdomain]
    organization = current_user.organizations.find_by(subdomain: organization_subdomain)
    
    unless organization
      render_serialized(SessionResponseSerializer, { success: false, error: "해당 조직에 접근할 권한이 없습니다." }, status: :forbidden)
      return
    end
    
    unless current_user.can_access?(organization)
      render_serialized(SessionResponseSerializer, { success: false, error: "비활성화된 조직이거나 접근할 수 없습니다." }, status: :forbidden)
      return
    end
    
    # 세션에 현재 조직 저장
    session[:current_organization_id] = organization.id
    session.delete(:return_organization)
    
    organization_url = DomainService.organization_url(organization.subdomain, 'dashboard')
    
    respond_to do |format|
      format.html { redirect_to organization_url }
      format.json do
        render_serialized(SessionResponseSerializer, {
          success: true,
          message: "#{organization.display_name}으로 이동합니다.",
          redirect_url: organization_url,
          organization: OrganizationSerializer.new(
            organization,
            params: { current_user: current_user }
          ).serializable_hash
        })
      end
    end
  end
  
  # GET /access_denied
  # 조직 접근이 거부되었을 때의 페이지
  def access_denied
    @organization_subdomain = params[:org]
    @organization = Organization.find_by(subdomain: @organization_subdomain) if @organization_subdomain
    
    respond_to do |format|
      format.html # access_denied.html.erb
      format.json do
        render_serialized(SessionResponseSerializer, {
          success: false,
          error: "조직에 접근할 권한이 없습니다.",
          organization: @organization_subdomain,
          organizations: current_user&.organizations&.active&.pluck(:subdomain, :name) || []
        }, status: :forbidden)
      end
    end
  end
  
  private
  
  # auth 서브도메인에서만 접근 가능하도록 확인
  def check_auth_domain
    unless DomainService.auth_domain?(request)
      # auth 도메인이 아니면 auth 도메인으로 리다이렉트
      intended_org = DomainService.extract_subdomain(request)
      return_param = intended_org.present? ? "?return_to=#{intended_org}" : ""
      redirect_to DomainService.auth_url("login#{return_param}"), allow_other_host: true
    end
  end
  
  # return_to 파라미터에서 조직 정보 저장
  def store_return_organization
    return_org = params[:return_to] || params[:org]
    session[:return_organization] = return_org if return_org.present?
  end
  
  # 로그인 성공 후 처리
  def handle_successful_login(user)
    # 크로스 도메인 세션 쿠키 설정
    set_cross_domain_session(user)
    
    return_org = session[:return_organization]
    
    if return_org.present?
      # 특정 조직으로 돌아가려는 경우
      organization = user.organizations.find_by(subdomain: return_org)
      
      if organization && user.can_access?(organization)
        # 직접 조직으로 이동
        session[:current_organization_id] = organization.id
        session.delete(:return_organization)
        redirect_to DomainService.organization_url(organization.subdomain, 'dashboard'), allow_other_host: true
        return
      else
        # 권한이 없거나 조직이 없으면 액세스 거부 페이지로
        redirect_to access_denied_path(org: return_org)
        return
      end
    end
    
    # 기본 플로우: 조직 선택 또는 첫 번째 조직으로
    user_organizations = user.organizations.active
    
    case user_organizations.count
    when 0
      # 조직이 없으면 메인 페이지로 (조직 생성 안내)
      redirect_to DomainService.main_url, allow_other_host: true
    when 1
      # 조직이 하나뿐이면 바로 이동
      organization = user_organizations.first
      session[:current_organization_id] = organization.id
      redirect_to DomainService.organization_url(organization.subdomain, 'dashboard'), allow_other_host: true
    else
      # 여러 조직이 있으면 선택 페이지로
      redirect_to organization_selection_path
    end
  end
  
  # 조직 선택 페이지로 리다이렉트
  def redirect_to_organization_selection
    redirect_to organization_selection_path
  end
  
  protected
  
  # Devise 기본 after_sign_in_path 오버라이드
  def after_sign_in_path_for(resource)
    # 이미 handle_successful_login에서 처리되므로 기본값 반환
    DomainService.auth_url
  end
  
  # Devise 기본 after_sign_out_path 오버라이드  
  def after_sign_out_path_for(resource_or_scope)
    # 크로스 도메인 세션 쿠키 삭제
    clear_cross_domain_session
    DomainService.main_url
  end
  
  # JWT 기반 크로스 도메인 세션 설정
  def set_cross_domain_session(user)
    # JWT 액세스 토큰 생성
    access_token = JwtService.generate_sso_token(user, session[:current_organization])
    refresh_token = JwtService.generate_refresh_token(user)
    
    # HttpOnly 쿠키로 안전하게 저장 (크로스 도메인)
    domain = Rails.env.production? ? ".creatia.io" : ".creatia.local"
    
    # 액세스 토큰 (짧은 수명)
    cookies[:jwt_access_token] = {
      value: access_token,
      domain: domain,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax,
      expires: 8.hours.from_now
    }
    
    # 리프레시 토큰 (긴 수명)
    cookies[:jwt_refresh_token] = {
      value: refresh_token,
      domain: domain,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :strict,
      expires: 30.days.from_now
    }
    
    # 추가 보안: CSRF 토큰 생성
    session[:jwt_csrf] = SecureRandom.hex(16)
  end
  
  # JWT 기반 크로스 도메인 세션 삭제
  def clear_cross_domain_session
    domain = Rails.env.production? ? ".creatia.io" : ".creatia.local"
    
    # JWT 토큰 무효화 (블랙리스트 추가)
    if cookies[:jwt_access_token]
      JwtService.revoke_token(cookies[:jwt_access_token])
    end
    
    # 쿠키 삭제
    cookies.delete(:jwt_access_token, domain: domain)
    cookies.delete(:jwt_refresh_token, domain: domain)
    
    # CSRF 토큰 삭제
    session.delete(:jwt_csrf)
  end
end
