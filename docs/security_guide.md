# 🔒 보안 가이드

> **Creatia App 보안 설정 및 체크리스트**  
> 프로덕션 환경에서 안전한 멀티테넌트 애플리케이션 운영을 위한 포괄적인 보안 가이드

## 📋 목차

- [🔐 인증 보안](#-인증-보안)
- [🌐 네트워크 보안](#-네트워크-보안)
- [🗄️ 데이터베이스 보안](#️-데이터베이스-보안)
- [📝 로그 보안](#-로그-보안)
- [🔑 환경변수 보안](#-환경변수-보안)
- [🛡️ 보안 검사 도구](#️-보안-검사-도구)
- [🚨 보안 인시던트 대응](#-보안-인시던트-대응)

## 🔐 인증 보안

### ✅ 체크리스트

- [ ] **JWT 시크릿 키가 충분히 복잡한지 확인**
  - 최소 32자 이상의 랜덤 문자열
  - 영문 대소문자, 숫자, 특수문자 포함
  - 정기적으로 로테이션 (월 1회 권장)

- [ ] **OAuth 클라이언트 시크릿이 안전하게 보관되는지 확인**
  - 환경변수로만 관리, 코드에 하드코딩 금지
  - CI/CD 파이프라인에서 마스킹 처리
  - 개발/스테이징/프로덕션 환경별 분리

- [ ] **세션 타임아웃이 적절히 설정되었는지 확인**
  - 일반 사용자: 8시간 (480분)
  - 관리자: 4시간 (240분)
  - API 토큰: 24시간

- [ ] **비밀번호 정책이 강력한지 확인**
  - 최소 8자 이상
  - 영문 대소문자, 숫자, 특수문자 포함
  - 이전 5개 비밀번호와 중복 방지
  - 90일마다 변경 권장

### 🔧 설정 방법

#### JWT 설정

```ruby
# config/initializers/jwt.rb
JWT_SECRET = Rails.application.credentials.jwt_secret || ENV['JWT_SECRET']
JWT_EXPIRATION = 24.hours

# JWT 토큰 생성 시 추가 보안
def generate_jwt(user, organization)
  payload = {
    user_id: user.id,
    organization_id: organization.id,
    exp: JWT_EXPIRATION.from_now.to_i,
    iat: Time.current.to_i,
    jti: SecureRandom.uuid,  # JWT ID for revocation
    aud: organization.subdomain,  # Audience claim
    iss: 'creatia-app'  # Issuer claim
  }
  
  JWT.encode(payload, JWT_SECRET, 'HS256')
end
```

#### Devise 보안 설정

```ruby
# config/initializers/devise.rb
Devise.setup do |config|
  # 세션 타임아웃
  config.timeout_in = 8.hours
  
  # 비밀번호 복잡성
  config.password_length = 8..128
  
  # 로그인 시도 제한
  config.maximum_attempts = 5
  config.unlock_in = 1.hour
  
  # 이메일 확인 필수
  config.confirm_within = 3.days
  
  # 비밀번호 재설정 링크 유효시간
  config.reset_password_within = 6.hours
end
```

## 🌐 네트워크 보안

### ✅ 체크리스트

- [ ] **HTTPS 사용 (프로덕션 환경)**
  - SSL/TLS 인증서 설정
  - HTTP → HTTPS 리다이렉트
  - HSTS (HTTP Strict Transport Security) 헤더
  - 안전한 쿠키 설정 (Secure, HttpOnly, SameSite)

- [ ] **CORS 설정이 올바른지 확인**
  - 허용된 도메인만 명시적 설정
  - 와일드카드(*) 사용 금지
  - 크리덴셜 포함 요청 제한

- [ ] **API Rate Limiting 설정**
  - IP별 요청 제한: 1000회/시간
  - 사용자별 요청 제한: 5000회/시간
  - 엔드포인트별 세부 제한

- [ ] **서브도메인별 접근 제어 확인**
  - 각 서브도메인의 역할 명확히 분리
  - 크로스 서브도메인 요청 제한
  - 와일드카드 서브도메인 보안

### 🔧 설정 방법

#### HTTPS 및 보안 헤더

```ruby
# config/application.rb
config.force_ssl = true if Rails.env.production?

# config/initializers/security_headers.rb
Rails.application.config.middleware.use Rack::Attack

# 보안 헤더 설정
class SecurityHeaders
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)
    
    headers['X-Frame-Options'] = 'DENY'
    headers['X-Content-Type-Options'] = 'nosniff'
    headers['X-XSS-Protection'] = '1; mode=block'
    headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    headers['Content-Security-Policy'] = csp_header
    
    if Rails.env.production?
      headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains; preload'
    end
    
    [status, headers, response]
  end
  
  private
  
  def csp_header
    "default-src 'self'; " \
    "script-src 'self' 'unsafe-inline' https://unpkg.com; " \
    "style-src 'self' 'unsafe-inline'; " \
    "img-src 'self' data: https:; " \
    "font-src 'self' https://fonts.gstatic.com; " \
    "connect-src 'self' ws: wss:;"
  end
end

Rails.application.config.middleware.use SecurityHeaders
```

#### Rate Limiting

```ruby
# config/initializers/rack_attack.rb
class Rack::Attack
  # IP별 제한
  throttle('req/ip', limit: 1000, period: 1.hour) do |req|
    req.ip
  end
  
  # 로그인 시도 제한
  throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
    if req.path == '/auth/login' && req.post?
      req.ip
    end
  end
  
  # API 제한
  throttle('api/user', limit: 5000, period: 1.hour) do |req|
    if req.path.start_with?('/api/')
      user_id = extract_user_id_from_token(req)
      "api:user:#{user_id}" if user_id
    end
  end
end
```

## 🗄️ 데이터베이스 보안

### ✅ 체크리스트

- [ ] **PostgreSQL 접속 계정에 최소 권한 부여**
  - 애플리케이션용 전용 계정 생성
  - 필요한 테이블/스키마만 접근 허용
  - 관리자 계정과 분리

- [ ] **MongoDB 인증 활성화**
  - 사용자 인증 활성화
  - 역할 기반 접근 제어 (RBAC)
  - 네트워크 접근 제한

- [ ] **데이터베이스 연결 암호화 (SSL/TLS)**
  - PostgreSQL SSL 연결
  - MongoDB TLS 연결
  - 인증서 검증

- [ ] **백업 데이터 암호화**
  - 백업 파일 암호화
  - 안전한 저장소 사용
  - 복구 절차 문서화

### 🔧 설정 방법

#### PostgreSQL 보안 설정

```yaml
# config/database.yml
production:
  adapter: postgresql
  host: <%= ENV['DATABASE_HOST'] %>
  port: <%= ENV['DATABASE_PORT'] %>
  database: <%= ENV['DATABASE_NAME'] %>
  username: <%= ENV['DATABASE_USERNAME'] %>
  password: <%= ENV['DATABASE_PASSWORD'] %>
  sslmode: require
  sslrootcert: config/ssl/postgresql-ca-cert.crt
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000
```

#### MongoDB 보안 설정

```yaml
# config/mongoid.yml
production:
  clients:
    default:
      uri: <%= ENV['MONGODB_URI'] %>
      options:
        ssl: true
        ssl_verify: true
        ssl_ca_cert: config/ssl/mongodb-ca-cert.crt
        auth_source: admin
        connect_timeout: 5
        socket_timeout: 5
        server_selection_timeout: 5
```

#### 데이터베이스 사용자 권한 설정

```sql
-- PostgreSQL
CREATE ROLE creatia_app WITH LOGIN PASSWORD 'secure_password';
GRANT CONNECT ON DATABASE creatia_production TO creatia_app;
GRANT USAGE ON SCHEMA public TO creatia_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO creatia_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO creatia_app;

-- MongoDB
use creatia_logs;
db.createUser({
  user: "creatia_app",
  pwd: "secure_password",
  roles: [
    { role: "readWrite", db: "creatia_logs" },
    { role: "dbAdmin", db: "creatia_logs" }
  ]
});
```

## 📝 로그 보안

### ✅ 체크리스트

- [ ] **민감한 정보가 로그에 기록되지 않는지 확인**
  - 비밀번호, 토큰, 개인정보 마스킹
  - 신용카드 정보, 주민등록번호 제외
  - 파라미터 필터링 설정

- [ ] **로그 접근 권한 제한**
  - 관리자만 로그 파일 접근 가능
  - 로그 뷰어 접근 권한 분리
  - 감사 로그 별도 관리

- [ ] **로그 로테이션 설정**
  - 일별/주별 로그 파일 분할
  - 오래된 로그 자동 삭제
  - 압축 저장으로 용량 절약

### 🔧 설정 방법

#### 파라미터 필터링

```ruby
# config/initializers/filter_parameter_logging.rb
Rails.application.config.filter_parameters += [
  :password, :password_confirmation, :token, :secret, :key,
  :credit_card, :ssn, :phone, :email, :address,
  /jwt/, /oauth/, /auth/, /secret/, /token/, /key/, /password/
]

# 커스텀 필터 추가
Rails.application.config.filter_parameters << lambda do |k, v|
  v.replace("[FILTERED]") if k.to_s.downcase.include?("sensitive")
end
```

#### 로그 레벨 및 포맷

```ruby
# config/environments/production.rb
config.log_level = :info
config.log_tags = [:request_id, :subdomain]

# 구조화된 로그 포맷
config.logger = ActiveSupport::Logger.new(STDOUT)
config.logger.formatter = proc do |severity, datetime, progname, msg|
  {
    timestamp: datetime.iso8601,
    level: severity,
    message: msg,
    request_id: Thread.current[:request_id],
    user_id: Current.user&.id,
    organization_id: Current.organization&.id
  }.to_json + "\n"
end
```

## 🔑 환경변수 보안

### 보안 환경변수 템플릿

```bash
# ===========================================
# 보안 설정 (중요! - 프로덕션에서 반드시 변경)
# ===========================================

# Rails 시크릿 (config/master.key 또는 환경변수 사용)
SECRET_KEY_BASE=<64자 이상의 랜덤 문자열>

# JWT 시크릿 (32자 이상 권장)
JWT_SECRET=<32자 이상의 복잡한 랜덤 문자열>

# 데이터베이스 비밀번호 (복잡한 비밀번호 필수)
DATABASE_PASSWORD=<복잡한_비밀번호>
MONGODB_PASSWORD=<복잡한_비밀번호>

# OAuth 시크릿 (각 제공자에서 발급)
GOOGLE_OAUTH_CLIENT_SECRET=<google_client_secret>
GITHUB_OAUTH_CLIENT_SECRET=<github_client_secret>

# 웹훅 시크릿
GITHUB_WEBHOOK_SECRET=<webhook_secret>

# SMTP 비밀번호
SMTP_PASSWORD=<smtp_password>

# 암호화 키 (백업, 파일 저장용)
ENCRYPTION_KEY=<32바이트_암호화_키>

# ===========================================
# 보안 정책 설정
# ===========================================

# 세션 만료 시간 (분)
SESSION_TIMEOUT=480

# JWT 토큰 만료 시간
JWT_EXPIRATION=24h

# 비밀번호 최소 길이
PASSWORD_MIN_LENGTH=8

# 로그인 시도 제한
MAX_LOGIN_ATTEMPTS=5

# Rate Limiting
RATE_LIMIT_PER_HOUR=1000
API_RATE_LIMIT_PER_HOUR=5000
```

### 환경변수 보안 관리

```bash
# 개발환경 - .env.development
cp .env.example .env.development
# 약한 시크릿 사용 가능 (실제 서비스와 구분)

# 스테이징환경 - .env.staging  
# 프로덕션과 유사하지만 별도 시크릿 사용

# 프로덕션환경 - .env.production
# 강력한 시크릿 필수, 정기적 로테이션

# 시크릿 생성 도구
openssl rand -hex 64  # SECRET_KEY_BASE용
openssl rand -hex 32  # JWT_SECRET용
openssl rand -base64 32  # 일반 비밀번호용
```

## 🛡️ 보안 검사 도구

### 정적 보안 분석

```bash
# Brakeman - Rails 보안 취약점 검사
bundle exec brakeman

# Bundle Audit - Gem 보안 취약점 검사
bundle exec bundle audit

# RuboCop Security - 코드 보안 규칙 검사
bundle exec rubocop --only Security/

# 종합 보안 검사 스크립트
bin/security_check
```

### 동적 보안 테스트

```bash
# 침투 테스트 (개발환경에서만)
# OWASP ZAP, Burp Suite 등 사용

# SQL Injection 테스트
sqlmap -u "http://localhost:3000/api/v1/tasks?id=1" --cookie="session=..."

# XSS 테스트  
# XSSer, BeEF 등 도구 사용

# 포트 스캔
nmap -sS -O localhost
```

### 보안 모니터링

```ruby
# config/initializers/security_monitoring.rb
class SecurityMonitoring
  def self.log_suspicious_activity(event, details = {})
    Rails.logger.warn({
      security_event: event,
      timestamp: Time.current.iso8601,
      details: details,
      request_id: Thread.current[:request_id],
      user_id: Current.user&.id,
      ip_address: Thread.current[:client_ip]
    }.to_json)
    
    # 심각한 경우 알림 발송
    if critical_events.include?(event)
      SecurityAlertService.notify(event, details)
    end
  end
  
  private
  
  def self.critical_events
    ['sql_injection_attempt', 'xss_attempt', 'brute_force_attack']
  end
end
```

## 🚨 보안 인시던트 대응

### 인시던트 대응 절차

1. **탐지 및 초기 대응 (0-15분)**
   ```bash
   # 즉시 수행
   - 로그 확인 및 범위 파악
   - 공격 IP 차단
   - 영향받은 계정 임시 잠금
   ```

2. **격리 및 차단 (15분-1시간)**
   ```bash
   # 공격 벡터 차단
   - 취약한 엔드포인트 비활성화
   - 네트워크 레벨에서 IP 차단
   - 의심스러운 세션 모두 무효화
   ```

3. **조사 및 분석 (1-24시간)**
   ```bash
   # 포렌식 분석
   - 로그 수집 및 보존
   - 공격 경로 추적
   - 피해 범위 확정
   ```

4. **복구 및 재발 방지 (24-72시간)**
   ```bash
   # 시스템 복구
   - 취약점 패치
   - 보안 정책 강화
   - 모니터링 규칙 업데이트
   ```

### 비상 연락처 및 절차

```yaml
# 보안 인시던트 연락처
security_contacts:
  primary: security@creatia.com
  backup: admin@creatia.com
  escalation: ceo@creatia.com

# 외부 지원
external_support:
  - 보안 컨설팅: security-firm@example.com
  - 클라우드 지원: cloud-support@provider.com
  - 법무팀: legal@creatia.com
```

### 정기 보안 점검

```bash
# 주간 보안 점검 (매주 월요일)
- 로그 분석 및 이상 징후 확인
- 시스템 업데이트 확인
- 백업 상태 점검

# 월간 보안 점검 (매월 첫째 주)
- 전체 보안 스캔 실행
- 접근 권한 검토
- 비밀번호 정책 준수 확인

# 분기별 보안 점검 (분기별)
- 침투 테스트 실행
- 보안 정책 업데이트
- 직원 보안 교육
```

---

## 📚 관련 문서

- [API 사용 가이드](api_usage_guide.md)
- [개발환경 설정](development_setup_guide.md)
- [데이터베이스 아키텍처](database_architecture.md)
- [메인 README](../README.md)
