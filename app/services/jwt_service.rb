# frozen_string_literal: true

# JWT 토큰 생성 및 검증을 담당하는 서비스
# 크로스 도메인 SSO 인증을 위한 안전한 토큰 관리
class JwtService
  class << self
    # JWT 시크릿 키 (환경변수에서 가져오거나 기본값 사용)
    def secret_key
      @secret_key ||= ENV.fetch('JWT_SECRET_KEY') { Rails.application.credentials.secret_key_base }
    end

    # JWT 토큰 생성
    # @param payload [Hash] 토큰에 포함될 데이터
    # @param exp [Time] 만료 시간 (기본값: 8시간 후)
    # @return [String] 인코딩된 JWT 토큰
    def encode(payload, exp = 8.hours.from_now)
      payload = payload.dup
      payload[:exp] = exp.to_i
      payload[:iat] = Time.current.to_i
      payload[:iss] = 'creatia-sso'
      
      JWT.encode(payload, secret_key, 'HS256')
    end

    # JWT 토큰 디코딩 및 검증
    # @param token [String] JWT 토큰
    # @return [HashWithIndifferentAccess, nil] 디코딩된 데이터 또는 nil
    def decode(token)
      return nil if token.blank?
      
      decoded = JWT.decode(
        token, 
        secret_key, 
        true, 
        { 
          algorithm: 'HS256',
          verify_iat: true,
          verify_iss: true,
          iss: 'creatia-sso'
        }
      )
      
      HashWithIndifferentAccess.new(decoded[0])
    rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::InvalidIatError, JWT::InvalidIssuerError => e
      Rails.logger.error "JWT Decode Error: #{e.message}"
      nil
    end

    # 사용자용 SSO 토큰 생성
    # @param user [User] 사용자 객체
    # @param organization [Organization, nil] 선택적 조직 정보
    # @return [String] SSO용 JWT 토큰
    def generate_sso_token(user, organization = nil)
      payload = {
        user_id: user.id,
        email: user.email,
        name: user.name,
        organization_id: organization&.id,
        organization_subdomain: organization&.subdomain,
        roles: user.organization_memberships.active.pluck(:role)
      }
      
      encode(payload)
    end

    # SSO 토큰 검증 및 사용자 정보 추출
    # @param token [String] JWT 토큰
    # @return [Hash, nil] 사용자 정보 또는 nil
    def verify_sso_token(token)
      payload = decode(token)
      return nil unless payload
      
      # 추가 검증: 사용자가 실제로 존재하는지 확인
      user = User.cached_find( payload[:user_id])
      return nil unless user
      
      payload.merge(user: user)
    end

    # 리프레시 토큰 생성 (장기 유지용)
    # @param user [User] 사용자 객체
    # @return [String] 리프레시용 JWT 토큰
    def generate_refresh_token(user)
      payload = {
        user_id: user.id,
        type: 'refresh',
        jti: SecureRandom.uuid # JWT ID for revocation tracking
      }
      
      encode(payload, 30.days.from_now)
    end

    # 액세스 토큰 재발급
    # @param refresh_token [String] 리프레시 토큰
    # @return [String, nil] 새로운 액세스 토큰 또는 nil
    def refresh_access_token(refresh_token)
      payload = decode(refresh_token)
      return nil unless payload && payload[:type] == 'refresh'
      
      user = User.cached_find( payload[:user_id])
      return nil unless user
      
      generate_sso_token(user)
    end

    # 토큰 블랙리스트 확인 (선택적 구현)
    # @param jti [String] JWT ID
    # @return [Boolean] 블랙리스트 여부
    def blacklisted?(jti)
      return false if jti.blank?
      
      # Redis 또는 DB를 사용한 블랙리스트 구현
      # Rails.cache.exist?("jwt_blacklist:#{jti}")
      false
    end

    # 토큰 무효화 (로그아웃 시)
    # @param token [String] JWT 토큰
    def revoke_token(token)
      payload = decode(token)
      return unless payload && payload[:jti]
      
      # Redis 또는 DB를 사용한 블랙리스트 추가
      # Rails.cache.write("jwt_blacklist:#{payload[:jti]}", true, expires_in: 30.days)
    end
  end
end