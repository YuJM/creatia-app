# Devise Cross-Domain SSO Configuration
# 크로스 도메인 SSO를 위한 Devise 설정

Rails.application.config.to_prepare do
  # 1. Warden 세션 스토어 설정
  Warden::Manager.after_set_user do |user, auth, opts|
    scope = opts[:scope]
    
    # 사용자 객체에서 ID 추출 (배열이나 해시인 경우 처리)
    user_id = case user
              when Array
                user.first.respond_to?(:id) ? user.first.id : user.first
              when Hash
                user['id'] || user[:id]
              else
                user.respond_to?(:id) ? user.id : user
              end
    
    auth.cookies.signed["#{scope}_id"] = {
      value: user_id,
      domain: Rails.env.production? ? ".creatia.io" : ".creatia.local",
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax
    }
  end

  # 2. 로그아웃 시 쿠키 정리
  Warden::Manager.before_logout do |user, auth, opts|
    scope = opts[:scope]
    auth.cookies.delete("#{scope}_id", 
      domain: Rails.env.production? ? ".creatia.io" : ".creatia.local"
    )
  end
end

# 4. Devise 설정 확장
Devise.setup do |config|
  # 크로스 도메인 리다이렉트 허용
  config.navigational_formats = ['*/*', :html, :turbo_stream]
  
  # 세션 타임아웃 설정 (모든 서브도메인에 적용)
  config.timeout_in = 8.hours
  
  # Remember me 기능 활성화
  config.remember_for = 2.weeks
  
  # 크로스 도메인 sign out 설정
  config.sign_out_all_scopes = false
  
  # Warden 설정
  config.warden do |manager|
    manager.default_strategies(scope: :user).unshift :jwt_authenticatable
  end
end

# 5. JWT Authenticatable Strategy
module Devise
  module Strategies
    class JwtAuthenticatable < Authenticatable
      def valid?
        jwt_token.present?
      end
      
      def authenticate!
        token_data = JwtService.verify_sso_token(jwt_token)
        
        if token_data && token_data[:user]
          success!(token_data[:user])
        else
          # 토큰이 유효하지 않으면 리프레시 토큰으로 시도
          if refresh_token.present?
            new_access_token = JwtService.refresh_access_token(refresh_token)
            if new_access_token
              token_data = JwtService.verify_sso_token(new_access_token)
              success!(token_data[:user]) if token_data && token_data[:user]
            else
              fail!
            end
          else
            fail!
          end
        end
      end
      
      private
      
      def jwt_token
        cookies[:jwt_access_token]
      end
      
      def refresh_token
        cookies[:jwt_refresh_token]
      end
      
      def cookies
        request.cookie_jar
      end
    end
  end
end

Warden::Strategies.add(:jwt_authenticatable, Devise::Strategies::JwtAuthenticatable)