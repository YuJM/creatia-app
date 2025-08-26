# GitHub App 설치 JWT State 관리 개선

## 🎯 개선 목표
기존의 단순한 문자열 기반 GitHub App state 관리를 JWT 토큰 기반으로 개선하여 보안성과 신뢰성을 높입니다.

## 🔧 구현된 개선사항

### 1. JWT State Manager 클래스 (`app/services/github/state_manager.rb`)
- **싱글톤 패턴** 적용으로 애플리케이션 전체에서 일관된 JWT 관리
- **자동 만료**: 10분 후 자동 만료로 보안 강화
- **표준 JWT 클레임** 지원 (iss, aud, iat, exp, sub)
- **추가 데이터 지원**: IP 주소, User Agent 등 검증용 정보 포함 가능
- **에러 핸들링**: 만료, 변조, 형식 오류 등 다양한 JWT 오류 상황 처리

### 2. GitHub 설치 URL 생성 개선 (`app/controllers/tenant/settings/githubs_controller.rb`)
```ruby
# 기존: 단순 문자열
state: current_organization.subdomain

# 개선: JWT 토큰
jwt_state = Github::StateManager.instance.generate_state(
  subdomain: current_organization.subdomain,
  user_id: current_user.id,
  additional_data: {
    timestamp: Time.current.to_i,
    ip_address: request.remote_ip,
    user_agent: request.user_agent&.first(100)
  }
)
```

### 3. 콜백 처리 강화 (`app/controllers/github/setup_controller.rb`)
```ruby
# JWT state 파싱 및 검증
if params[:state].present?
  state_data = Github::StateManager.instance.parse_state(params[:state])
  
  if state_data
    # 검증된 조직 정보로 연결
    organization = Organization.find_by(subdomain: state_data[:subdomain])
    Rails.logger.info "GitHub 설치: JWT state로 조직 찾음 - #{state_data[:subdomain]} (사용자: #{state_data[:user_id]})"
  else
    Rails.logger.warn "GitHub 설치: JWT state 파싱 실패 - 토큰이 만료되었거나 잘못됨"
  end
end
```

## 🛡️ 보안 개선사항

### 1. **변조 방지**
- HMAC-SHA256 서명으로 토큰 무결성 보장
- 토큰 변조 시 자동으로 검증 실패

### 2. **자동 만료**
- 10분 후 자동 만료로 악용 위험 최소화
- `exp` 클레임으로 표준 JWT 만료 처리

### 3. **추가 검증 정보**
- IP 주소, User Agent 등 요청 컨텍스트 정보 포함
- 필요시 추가적인 검증 로직 구현 가능

### 4. **에러 로깅**
- JWT 검증 실패 시 상세한 로그 기록
- 보안 이벤트 모니터링 가능

## 📊 기능 특징

### JWT State Manager 메서드
```ruby
# 토큰 생성
generate_state(subdomain:, user_id:, additional_data: {})

# 토큰 파싱 (검증 포함)
parse_state(state_token)

# 토큰 내용 확인 (검증 없이)
peek_state(state_token)

# 만료 임박 확인 (2분 이내)
expiring_soon?(state_data)

# 토큰 유효성 확인
valid_state?(state_token)
```

### JWT 클레임 구조
```json
{
  "sub": "organization-subdomain",  // 조직 서브도메인
  "uid": "user-id",                // 사용자 ID
  "iat": 1691234567,               // 발급시간
  "exp": 1691235167,               // 만료시간 (10분 후)
  "iss": "creatia.io",             // 발급자
  "aud": "github-app",             // 대상
  "timestamp": 1691234567,         // 추가: 타임스탬프
  "ip_address": "192.168.1.1",     // 추가: IP 주소
  "user_agent": "Mozilla/5.0..."   // 추가: User Agent
}
```

## 🧪 테스트 커버리지

### 구현된 테스트 (`test/services/github/state_manager_test.rb`)
- ✅ JWT 토큰 생성 및 파싱
- ✅ 만료된 토큰 검증 실패
- ✅ 잘못된 토큰 검증 실패
- ✅ 추가 데이터 포함 및 파싱
- ✅ Peek 기능 (검증 없이 내용 확인)
- ✅ 만료 임박 토큰 감지
- ✅ 토큰 유효성 검사
- ✅ JWT 클레임 정확성
- ✅ 싱글톤 패턴 동작

### 테스트 실행 결과
```
9 runs, 36 assertions, 0 failures, 0 errors, 0 skips
```

## 🔄 비교: 기존 vs 개선

| 항목 | 기존 방식 | JWT 개선 방식 |
|------|----------|--------------|
| **보안성** | 단순 문자열 (변조 가능) | HMAC-SHA256 서명 (변조 불가) |
| **만료** | 없음 (무한 유효) | 10분 자동 만료 |
| **검증** | 기본 문자열 매칭 | 표준 JWT 검증 |
| **정보량** | 서브도메인만 | 사용자 ID, IP, User Agent 등 |
| **로깅** | 제한적 | 상세한 보안 이벤트 로깅 |
| **확장성** | 제한적 | 추가 데이터 쉽게 확장 가능 |

## 🚀 실제 동작 확인

```ruby
# JWT State Manager 테스트 성공
state_manager = Github::StateManager.instance
token = state_manager.generate_state(subdomain: "test-org", user_id: 123)
# => "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0ZXN0LW9yZyI..."

parsed_data = state_manager.parse_state(token)
# => {
#      subdomain: "test-org",
#      user_id: 123,
#      issued_at: 2025-08-10 19:27:34 +0900,
#      expires_at: 2025-08-10 19:37:34 +0900,
#      additional_data: {...}
#    }
```

## 📝 다음 단계 권장사항

### 1. **환경별 설정**
```ruby
# config/environments/production.rb
# JWT 만료시간을 더 짧게 (5분)
TOKEN_EXPIRY = 5.minutes

# 추가 보안 헤더 검증
config.force_ssl = true
```

### 2. **모니터링 강화**
```ruby
# JWT 검증 실패 알림
if parsed_data.nil?
  SecurityAlertService.notify("JWT state validation failed", {
    token: params[:state]&.first(50),
    ip: request.remote_ip,
    user_agent: request.user_agent
  })
end
```

### 3. **선택적 기능**
```ruby
# IP 주소 검증 (선택사항)
if state_data[:additional_data]["ip_address"] != request.remote_ip
  Rails.logger.warn "IP address mismatch in JWT state"
  # 필요시 추가 검증 로직
end
```

## ✅ 결론

JWT 기반 GitHub state 관리로 전환하여:
- **보안성** 대폭 강화 (변조 방지, 자동 만료)
- **추적 가능성** 향상 (사용자 ID, IP 등 정보 포함)
- **신뢰성** 개선 (표준 JWT 검증)
- **확장성** 확보 (추가 데이터 포함 가능)

모든 테스트가 통과하고 실제 동작이 확인되어 안전하게 운영환경에 적용할 수 있습니다.