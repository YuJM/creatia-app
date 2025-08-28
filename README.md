# Creatia App

> 멀티테넌트 조직 관리 및 태스크 관리 플랫폼

## 🚀 빠른 시작

### 요구사항
- **Ruby**: 3.4.5+
- **Rails**: 8.0.2+
- **Node.js**: 18+
- **SQLite3**: 개발/테스트용
- **PostgreSQL**: 프로덕션용

### 설치 및 실행

```bash
# 저장소 클론
git clone <repository-url>
cd creatia-app

# 의존성 설치
npm install
bundle install

# 데이터베이스 설정
bin/rails db:create db:migrate db:seed

# 서버 실행
bin/rails server
```

앱이 http://127.0.0.1:3000 에서 실행됩니다.

## 🏗️ 아키텍처

### 멀티테넌트 서브도메인 구조
- **메인**: `localhost:3000` - 랜딩 페이지, 사용자 등록
- **인증**: `auth.creatia.local:3000` - SSO, 로그인/로그아웃
- **조직**: `{org}.creatia.local:3000` - 조직별 대시보드, 태스크 관리
- **API**: `api.creatia.local:3000` - REST API 엔드포인트
- **관리자**: `admin.creatia.local:3000` - 시스템 관리

### 핵심 기능
- 🏢 **조직 관리**: 멀티테넌트 조직별 격리
- 👥 **사용자 관리**: Devise 기반 인증, 역할 기반 권한
- 📋 **태스크 관리**: 조직별 태스크 생성 및 관리
- 🔐 **보안**: Pundit 권한 시스템, CSRF 보호
- 🌐 **API**: RESTful API with Alba 직렬화

## 🧪 테스트

### 테스트 실행
```bash
# 전체 테스트
bundle exec rspec

# 시스템 통합 테스트
bundle exec rspec spec/system/

# CI용 핵심 테스트
bundle exec rspec spec/system/ci_integration_spec.rb

# 커버리지 확인
open coverage/index.html
```

### 테스트 구조
- **Unit Tests**: 모델, 컨트롤러, 헬퍼, 서비스
- **Integration Tests**: 요청 스펙, 라우팅
- **System Tests**: 전체 사용자 플로우, 브라우저 테스트
- **Feature Tests**: BDD 스타일 기능 테스트

## 📚 문서

- [**앱 설치 및 문제 해결**](docs/app_setup_and_troubleshooting.md) - 설치 과정 및 트러블슈팅
- [**시스템 통합 테스트**](docs/system_integration_tests.md) - 포괄적인 테스트 스위트 구현
- [**Caddy 로컬 개발 환경**](docs/caddy_setup.md) - 서브도메인 개발 환경 구축
- [**멀티테넌트 가이드**](docs/multi.md) - 멀티테넌트 아키텍처 설명
- [**GitHub JWT 개선사항**](docs/github_jwt_state_improvement.md) - JWT 상태 관리 개선

## 🛠️ 기술 스택

### Backend
- **Ruby on Rails 8.0.2** - 웹 프레임워크
- **PostgreSQL** - 메인 데이터베이스
- **SQLite3** - 개발/테스트 데이터베이스
- **Devise** - 인증
- **Pundit** - 권한 관리
- **ActsAsTenant** - 멀티테넌트
- **Alba** - JSON 직렬화

### Frontend
- **Hotwire (Turbo + Stimulus)** - 모던 SPA 경험
- **Tailwind CSS** - 유틸리티 우선 CSS
- **JavaScript ES6+** - 모던 JavaScript

### Testing
- **RSpec** - 테스트 프레임워크
- **Factory Bot** - 테스트 데이터 생성
- **Capybara** - 통합 테스트
- **SimpleCov** - 코드 커버리지
- **Database Cleaner** - 테스트 DB 정리

### Development
- **Faker** - 더미 데이터 생성
- **Rubocop** - 코드 스타일 검사
- **Brakeman** - 보안 검사
- **Caddy** - 로컬 개발용 리버스 프록시

## 🔧 개발 환경 설정

### 환경 변수
```bash
# .env 파일 생성 (env.example 참조)
cp env.example .env

# 주요 환경 변수
DATABASE_HOST=localhost
DATABASE_PORT=5432
APP_DOMAIN=localhost:3000
GITHUB_OAUTH_CLIENT_ID=your_client_id
GITHUB_OAUTH_CLIENT_SECRET=your_client_secret
```

### 서브도메인 개발 (Caddy 권장)

#### 방법 1: Caddy 리버스 프록시 (권장)
완전한 멀티테넌트 서브도메인 기능을 위해 Caddy를 사용:

```bash
# Caddy 설치
brew install caddy

# hosts 파일 설정 및 Caddy 실행
# 자세한 내용은 docs/caddy_setup.md 참조
```

#### 방법 2: 간단한 hosts 설정
기본적인 서브도메인 테스트만 필요한 경우:

```bash
# /etc/hosts 파일에 추가
sudo vim /etc/hosts

# 다음 라인들 추가:
127.0.0.1 creatia.local
127.0.0.1 auth.creatia.local
127.0.0.1 api.creatia.local
127.0.0.1 admin.creatia.local
127.0.0.1 demo.creatia.local
```

## 🚀 배포

### Docker (권장)
```bash
# Docker 이미지 빌드
docker build -t creatia-app .

# 컨테이너 실행
docker run -p 3000:3000 creatia-app
```

### Kamal (Rails 8 기본)
```bash
# 배포 설정
kamal setup

# 배포 실행
kamal deploy
```

## 🤝 기여 가이드

### 개발 워크플로우
1. **Feature 브랜치 생성**: `git checkout -b feature/your-feature`
2. **개발 및 테스트**: 기능 구현 후 테스트 작성
3. **시스템 테스트 실행**: `bundle exec rspec spec/system/ci_integration_spec.rb`
4. **Pull Request 생성**: 코드 리뷰 요청
5. **CI 통과 확인**: 모든 테스트 통과 확인
6. **배포**: 메인 브랜치 머지 후 자동 배포

### 코드 스타일
```bash
# Rubocop 실행
bundle exec rubocop

# 자동 수정
bundle exec rubocop -A
```

### 보안 검사
```bash
# Brakeman 보안 검사
bundle exec brakeman
```

## 📊 모니터링

### 성능 기준선
- **페이지 로드 시간**: 3초 이내
- **데이터베이스 쿼리**: 페이지당 15개 이내
- **메모리 사용량**: 모니터링 중

### 헬스체크
- **앱 상태**: `/up`
- **데이터베이스**: 자동 연결 확인
- **의존성**: 자동 gem 로드 확인

## 🆘 지원 및 문제 해결

### 자주 발생하는 문제
1. **포트 3000 사용 중**: `kill -9 $(lsof -ti:3000)`
2. **Bundle 설치 실패**: `bundle clean --force && bundle install`
3. **npm 설치 실패**: `rm -rf node_modules && npm install`
4. **데이터베이스 오류**: `bin/rails db:reset`

### 로그 확인
```bash
# 개발 로그
tail -f log/development.log

# 테스트 로그  
tail -f log/test.log
```

### 디버깅
```bash
# Rails 콘솔
bin/rails console

# 데이터베이스 콘솔
bin/rails dbconsole
```

## 📈 최근 업데이트 (2025.08.26)

### ✅ 완료된 작업
- **앱 설치 및 실행 환경 구축**
- **라우팅 중복 문제 해결** (devise_for, root 라우트)
- **인증 오류 수정** (current_user 메서드 문제)
- **시스템 레벨 통합 테스트 구현**
  - 애플리케이션 부팅 검증
  - HTTP 요청 플로우 테스트  
  - 서브도메인별 기능 테스트
  - 인증 플로우 통합 테스트
  - CI/CD용 핵심 테스트
- **성능 및 보안 기준선 설정**
- **포괄적인 문서화**

### 🎯 주요 성과
- **18개 시스템 테스트 중 17개 통과** ✅
- **설정 오류 조기 발견 시스템 구축** 🔍
- **CI/CD 파이프라인 품질 보장** 🚀
- **개발 효율성 및 안정성 향상** 💪

---

**개발팀**: 안정적이고 확장 가능한 멀티테넌트 플랫폼을 구축하고 있습니다. 🚀
