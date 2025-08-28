class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  include Dry::Monads[:result]
  
  skip_before_action :verify_authenticity_token, only: [:google_oauth2, :github]
  before_action :store_return_organization, only: [:google_oauth2, :github]
  before_action :validate_oauth_callback, only: [:google_oauth2, :github]

  def google_oauth2
    handle_auth("Google")
  end

  def github
    handle_auth("GitHub")
  end

  def failure
    error_message = params[:message] || "알 수 없는 오류가 발생했습니다."
    
    # OAuth 실패 보안 감사 로그
    SecurityAuditService.log_security_event(:login_failure, {
      event_type: 'oauth_failure',
      provider: params[:strategy],
      error: params[:message],
      error_description: params[:error_description],
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      risk_level: :medium
    })
    
    redirect_to DomainService.auth_url("login"), alert: "인증 실패: #{error_message}"
  end

  private
  
  # OAuth 콜백 데이터 검증
  def validate_oauth_callback
    return if params[:error].present? # 에러 상황은 failure 액션에서 처리
    
    contract = OauthCallbackContract.new
    auth_data = request.env["omniauth.auth"]&.to_h || {}
    
    result = contract.call(auth_data)
    
    case result
    in Success()
      Rails.logger.info "OAuth 검증 성공: #{auth_data[:provider]} - #{auth_data.dig(:info, :email)}"
    in Failure()
      Rails.logger.warn "OAuth 검증 실패: #{result.errors.to_h}"
      
      # 검증 실패 보안 감사 로그
      SecurityAuditService.log_security_event(:invalid_request, {
        event_type: 'oauth_validation_failed',
        provider: auth_data[:provider],
        errors: result.errors.to_h,
        ip_address: request.remote_ip,
        risk_level: :high
      })
      
      redirect_to DomainService.auth_url("login"), 
                  alert: "OAuth 데이터 검증에 실패했습니다. 다시 시도해주세요."
      return
    end
  end

  def handle_auth(kind)
    @user = User.from_omniauth(request.env["omniauth.auth"])
    
    if @user.persisted?
      # 로그인 성공
      sign_in(@user, event: :authentication)
      flash[:notice] = "#{kind}으로 로그인했습니다."
      
      # OAuth 성공 보안 감사 로그
      SecurityAuditService.log_login_success(@user, request, {
        provider: kind.downcase,
        oauth_provider: request.env["omniauth.auth"]&.provider
      })
      
      # SSO 플로우에 따른 리다이렉트 처리
      handle_sso_redirect(@user)
    else
      # 사용자 생성 실패
      session["devise.#{kind.downcase}_data"] = request.env["omniauth.auth"].except(:extra)
      error_messages = @user.errors.full_messages.join(", ")
      
      # 사용자 생성 실패 감사 로그
      SecurityAuditService.log_security_event(:login_failure, {
        event_type: 'oauth_user_creation_failed',
        provider: kind.downcase,
        email: request.env["omniauth.auth"]&.dig(:info, :email),
        errors: error_messages,
        ip_address: request.remote_ip,
        risk_level: :medium
      })
      
      redirect_to new_user_registration_url, alert: "계정 생성 중 오류가 발생했습니다: #{error_messages}"
    end
  end
  
  # return_to 파라미터에서 조직 정보 저장
  def store_return_organization
    # 상태 파라미터나 세션에서 return_to 정보 확인
    return_org = params[:state] || session[:return_organization]
    
    # OAuth state parameter는 보통 JSON이나 쿼리 문자열 형태
    if return_org.present?
      begin
        # state가 JSON 형태인 경우 파싱
        if return_org.start_with?('{')
          state_data = JSON.parse(return_org)
          session[:return_organization] = state_data['return_to'] if state_data['return_to']
        else
          # 단순 문자열인 경우 직접 사용
          session[:return_organization] = return_org
        end
      rescue JSON::ParserError
        # JSON 파싱 실패시 문자열로 처리
        session[:return_organization] = return_org
      end
    end
  end
  
  # SSO 플로우에 따른 리다이렉트 처리
  def handle_sso_redirect(user)
    return_org = session[:return_organization]
    
    # 특정 조직으로 돌아가려는 경우
    if return_org.present?
      organization = user.organizations.find_by(subdomain: return_org)
      
      if organization && user.can_access?(organization)
        # 권한이 있는 조직으로 직접 이동
        session[:current_organization_id] = organization.id
        session.delete(:return_organization)
        redirect_to DomainService.organization_url(organization.subdomain, 'dashboard')
        return
      else
        # 권한이 없거나 조직이 없으면 액세스 거부 페이지로
        redirect_to DomainService.auth_url("access_denied?org=#{return_org}")
        return
      end
    end
    
    # 기본 플로우: 사용자의 조직 수에 따라 처리
    user_organizations = user.organizations.active
    
    case user_organizations.count
    when 0
      # 조직이 없으면 메인 페이지로 (조직 생성 안내)
      redirect_to DomainService.main_url
    when 1
      # 조직이 하나뿐이면 바로 이동
      organization = user_organizations.first
      session[:current_organization_id] = organization.id
      redirect_to DomainService.organization_url(organization.subdomain, 'dashboard')
    else
      # 여러 조직이 있으면 선택 페이지로
      redirect_to DomainService.auth_url('organization_selection')
    end
  end
end