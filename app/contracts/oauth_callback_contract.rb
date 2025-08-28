# frozen_string_literal: true

require 'dry/validation'

# OAuth 콜백 검증을 위한 Contract (GitHub, Google 등)
class OauthCallbackContract < Dry::Validation::Contract
  params do
    # OAuth 공통 필드
    optional(:code).filled(:string)
    optional(:state).filled(:string)
    optional(:error).filled(:string)
    optional(:error_description).filled(:string)
    
    # Omniauth에서 제공하는 정보
    optional(:uid).filled(:string)
    optional(:provider).filled(:string)
    
    # 사용자 정보
    optional(:info).hash do
      optional(:email).filled(:string)
      optional(:name).filled(:string)
      optional(:nickname).filled(:string)
      optional(:image).filled(:string)
      optional(:urls).hash
    end
    
    # 추가 정보
    optional(:credentials).hash do
      optional(:token).filled(:string)
      optional(:secret).filled(:string)
      optional(:refresh_token).filled(:string)
      optional(:expires_at).filled(:integer)
    end
    
    # GitHub 특화 정보
    optional(:extra).hash do
      optional(:raw_info).hash do
        optional(:login).filled(:string)
        optional(:id).filled(:integer)
        optional(:avatar_url).filled(:string)
        optional(:company).filled(:string)
        optional(:blog).filled(:string)
        optional(:location).filled(:string)
        optional(:bio).filled(:string)
        optional(:public_repos).filled(:integer)
        optional(:followers).filled(:integer)
        optional(:following).filled(:integer)
      end
    end
  end
  
  # 에러가 있는 경우 검증
  rule(:error) do
    if value.present?
      case value
      when 'access_denied'
        key.failure('사용자가 OAuth 인증을 거부했습니다')
      when 'invalid_request'
        key.failure('잘못된 OAuth 요청입니다')
      when 'unauthorized_client'
        key.failure('인증되지 않은 클라이언트입니다')
      when 'unsupported_response_type'
        key.failure('지원하지 않는 응답 타입입니다')
      when 'invalid_scope'
        key.failure('유효하지 않은 스코프입니다')
      when 'server_error'
        key.failure('OAuth 서버 오류가 발생했습니다')
      when 'temporarily_unavailable'
        key.failure('OAuth 서비스가 일시적으로 사용할 수 없습니다')
      else
        key.failure("OAuth 오류: #{value}")
      end
    end
  end
  
  # 이메일 검증
  rule(:info, :email) do
    email = values.dig(:info, :email)
    next unless email
    
    # 이메일 형식 검증
    unless email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
      key([:info, :email]).failure('유효하지 않은 이메일 형식입니다')
    end
    
    # 이메일 길이 제한
    if email.length > 254
      key([:info, :email]).failure('이메일이 너무 깁니다')
    end
    
    # 허용되지 않은 도메인 차단 (필요시)
    blocked_domains = %w[tempmail.com 10minutemail.com]
    domain = email.split('@').last&.downcase
    if blocked_domains.include?(domain)
      key([:info, :email]).failure('임시 이메일 주소는 사용할 수 없습니다')
    end
  end
  
  # 사용자명 검증
  rule(:info, :name) do
    name = values.dig(:info, :name)
    next unless name
    
    # 이름 길이 제한
    if name.length > 100
      key([:info, :name]).failure('이름이 너무 깁니다 (최대 100자)')
    end
    
    # 특수문자 제한
    if name.match?(/[<>"\{\}\\]/)
      key([:info, :name]).failure('이름에 허용되지 않은 문자가 포함되어 있습니다')
    end
  end
  
  # provider 검증
  rule(:provider) do
    next unless value
    
    allowed_providers = %w[github google_oauth2]
    unless allowed_providers.include?(value)
      key.failure("지원하지 않는 OAuth 제공자입니다: #{value}")
    end
  end
  
  # state 매개변수 검증 (CSRF 방지)
  rule(:state) do
    next unless value
    
    # state 길이 제한
    if value.length > 500
      key.failure('State 매개변수가 너무 깁니다')
    end
    
    # JWT 형식 검증 (JWT를 사용하는 경우)
    if value.count('.') == 2
      begin
        # JWT 디코딩 시도 (실제 검증은 JWT 라이브러리에서)
        parts = value.split('.')
        unless parts.all? { |part| part.match?(/\A[A-Za-z0-9_-]+\z/) }
          key.failure('유효하지 않은 JWT 형식입니다')
        end
      rescue
        key.failure('JWT 파싱 중 오류가 발생했습니다')
      end
    end
  end
  
  # 토큰 검증
  rule(:credentials, :token) do
    token = values.dig(:credentials, :token)
    next unless token
    
    # 토큰 길이 제한
    if token.length > 1000
      key([:credentials, :token]).failure('액세스 토큰이 너무 깁니다')
    end
    
    # 토큰 형식 기본 검증
    unless token.match?(/\A[A-Za-z0-9._-]+\z/)
      key([:credentials, :token]).failure('유효하지 않은 토큰 형식입니다')
    end
  end
  
  # 전체 검증
  rule do
    # 에러가 있으면 다른 필드는 무시
    if values[:error].present?
      next
    end
    
    # 성공적인 OAuth의 경우 필수 필드 확인
    required_for_success = [:uid, :provider, :info]
    missing_fields = required_for_success.select { |field| values[field].blank? }
    
    if missing_fields.any?
      key.failure("OAuth 성공 시 필수 필드가 누락되었습니다: #{missing_fields.join(', ')}")
    end
    
    # 이메일은 필수
    if values.dig(:info, :email).blank?
      key([:info, :email]).failure('이메일 정보가 필요합니다')
    end
  end
end
