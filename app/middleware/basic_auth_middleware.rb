# frozen_string_literal: true

# BasicAuthMiddleware - 개발/테스트 환경에서 HTTP Basic Authentication 지원
# Devise와 함께 동작하여 사용자가 Basic Auth로 인증할 수 있게 해줍니다.
class BasicAuthMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    # 개발 또는 테스트 환경에서만 활성화
    if Rails.env.development? || Rails.env.test?
      request = Rack::Request.new(env)
      
      # Basic Auth 헤더가 있는 경우 처리
      if auth_header = request.env['HTTP_AUTHORIZATION']
        if auth_header.start_with?('Basic ')
          handle_basic_auth(env, auth_header)
        end
      end
    end

    @app.call(env)
  end

  private

  def handle_basic_auth(env, auth_header)
    # Basic Auth 디코딩
    credentials = Base64.decode64(auth_header.sub('Basic ', '')).split(':', 2)
    return unless credentials.length == 2
    
    email, password = credentials
    return if email.blank? || password.blank?

    # 사용자 인증 시도
    user = User.find_by(email: email)
    if user&.valid_password?(password)
      # Warden에 사용자 설정
      env['warden']&.set_user(user, scope: :user)
      
      # 세션에도 설정 (Devise 호환성)
      if session = env['rack.session']
        # Devise의 표준 직렬화 형식 사용
        serialized = User.serialize_into_session(user)
        session['warden.user.user.key'] = serialized
      end
      
      Rails.logger.info "Basic Auth successful for user: #{user.email}"
    else
      Rails.logger.info "Basic Auth failed for email: #{email}"
    end
  rescue => e
    Rails.logger.error "Basic Auth error: #{e.message}"
  end
end