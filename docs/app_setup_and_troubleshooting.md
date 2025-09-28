# 앱 설치 및 실행 가이드

> **작업 일자**: 2025년 8월 26일  
> **목적**: Rails 앱 초기 설정 및 발생한 문제들 해결 과정 문서화

## 📋 설치 과정

### 1. 의존성 설치
```bash
# JavaScript 패키지 설치
npm install

# Ruby gem 설치  
bundle install
```

### 2. 데이터베이스 설정
원래는 PostgreSQL을 사용하도록 설정되어 있었지만, 개발 편의를 위해 SQLite로 변경했습니다.

#### 변경 사항:
**`config/database.yml`**:
```yaml
# 변경 전 (PostgreSQL)
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  host: <%= ENV.fetch("DATABASE_HOST", "localhost") %>
  port: <%= ENV.fetch("DATABASE_PORT", 5432) %>
  username: <%= ENV["DATABASE_USERNAME"] %>
  password: <%= ENV["DATABASE_PASSWORD"] %>

# 변경 후 (SQLite)
default: &default
  adapter: sqlite3
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000

development:
  <<: *default
  database: db/development.sqlite3

test:
  <<: *default
  database: db/test.sqlite3
```

**`Gemfile`**:
```ruby
# 변경 전
gem "pg", "~> 1.1"

# 변경 후  
gem "sqlite3", ">= 1.4"
```

### 3. 앱 실행
```bash
bin/rails server
```

## 🚨 발생한 문제들 및 해결 과정

### 1. 라우팅 중복 오류
**오류 메시지**:
```
ArgumentError: Invalid route name, already in use: 'new_user_session'
```

**원인**: 
`config/routes.rb`에서 `devise_for :users`가 여러 서브도메인에서 중복 정의됨

**해결 방법**:
각 서브도메인별로 고유한 `as` 옵션 추가

```ruby
# 메인 도메인
constraints subdomain: /^(www)?$/ do
  devise_for :users, as: :main_user, controllers: { 
    omniauth_callbacks: 'users/omniauth_callbacks'
  }
end

# 인증 서브도메인  
constraints subdomain: 'auth' do
  devise_for :users, as: :auth_user, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks',
    sessions: 'users/sessions'
  }
end
```

### 2. Root 라우트 중복 오류
**원인**: 여러 서브도메인에서 `root` 라우트가 중복 정의됨

**해결 방법**:
각 서브도메인별로 고유한 `as` 옵션 추가

```ruby
# 메인 도메인
root "pages#home"  # 기본

# 인증 서브도메인
root "pages#home", as: :auth_root

# 조직 테넌트 
root "organizations#dashboard", as: :tenant_root

# 관리자
namespace :admin do
  root "dashboard#index", as: :admin_root
end
```

### 3. current_user 메서드 오류
**오류 메시지**:
```
NameError: undefined local variable or method 'current_user' for an instance of PagesController
```

**원인**: 
ApplicationController에서 Devise 헬퍼 메서드가 자동으로 포함되지 않음

**해결 방법**:
ApplicationController에 Devise 헬퍼 명시적 포함

```ruby
class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Devise::Controllers::Helpers  # 추가
  
  # 멀티테넌트 설정에서 current_user가 nil일 수 있는 경우 처리
  def set_current_tenant
    user = respond_to?(:current_user) ? current_user : nil
    @tenant_context = TenantContextService.new(request, user)
    # ...
  end
end
```

### 4. PostgreSQL 연결 오류
**오류 메시지**:
```
FATAL: role "yujongmyeong" does not exist
```

**원인**: PostgreSQL 사용자가 생성되지 않음

**해결 방법**: 
개발 편의를 위해 SQLite로 변경 (위의 데이터베이스 설정 참조)

## 🎯 최종 설정

### 환경 정보
- **Ruby**: 3.4.5
- **Rails**: 8.0.2
- **Database**: SQLite3 (개발/테스트), PostgreSQL (프로덕션)
- **Node.js**: npm 패키지 관리

### 성공적인 실행 확인
1. ✅ npm install 완료
2. ✅ bundle install 완료  
3. ✅ 라우팅 오류 수정
4. ✅ 인증 오류 수정
5. ✅ Rails 서버 실행 성공
6. ✅ http://127.0.0.1:3000 접속 가능

## 🚀 멀티테넌트 아키텍처 이해

이 앱은 **멀티테넌트 구조**로 설계되어 있어 여러 서브도메인을 지원합니다:

### 서브도메인 구조
```
메인 도메인:     localhost:3000 (또는 creatia.local:3000)
인증 도메인:     auth.creatia.local:3000
API 도메인:      api.creatia.local:3000  
관리자 도메인:   admin.creatia.local:3000
조직별 도메인:   {org}.creatia.local:3000
```

### 도메인 설정 (선택사항)
개발 환경에서 서브도메인 기능을 테스트하려면 `/etc/hosts` 파일에 추가:

```bash
# /etc/hosts 파일에 추가
127.0.0.1 creatia.local
127.0.0.1 auth.creatia.local
127.0.0.1 api.creatia.local
127.0.0.1 admin.creatia.local
127.0.0.1 demo.creatia.local
127.0.0.1 test.creatia.local
```

### 기능별 도메인 역할
- **메인** (`localhost:3000`): 랜딩 페이지, 사용자 등록
- **인증** (`auth.creatia.local:3000`): SSO, 로그인/로그아웃  
- **조직** (`{org}.creatia.local:3000`): 조직별 대시보드, 태스크 관리
- **API** (`api.creatia.local:3000`): REST API 엔드포인트
- **관리자** (`admin.creatia.local:3000`): 시스템 관리

## 🔧 개발 환경 권장 사항

### 1. IDE 설정
- **RubyMine** 또는 **VS Code** 권장
- Ruby LSP, Rails 플러그인 설치
- Tailwind CSS IntelliSense 설치

### 2. 필수 도구
```bash
# Ruby 버전 관리
rbenv install 3.4.5
rbenv local 3.4.5

# Node.js 버전 관리  
nvm install 18
nvm use 18

# 데이터베이스 도구
brew install sqlite3  # macOS
```

### 3. 개발 서버 실행
```bash
# Rails 서버 (백그라운드)
bin/rails server

# 또는 개발용 Procfile 사용
bin/dev  # foreman 필요시
```

### 4. 테스트 실행
```bash
# 전체 테스트
bundle exec rspec

# 시스템 테스트만
bundle exec rspec spec/system/

# CI 테스트만  
bundle exec rspec spec/system/ci_integration_spec.rb
```

## 📊 성능 최적화 팁

### 1. 개발 환경 최적화
```ruby
# config/environments/development.rb
config.cache_classes = false
config.eager_load = false
config.consider_all_requests_local = true
```

### 2. 데이터베이스 최적화
```bash
# SQLite 성능 향상
echo "PRAGMA journal_mode=WAL;" | sqlite3 db/development.sqlite3
echo "PRAGMA synchronous=NORMAL;" | sqlite3 db/development.sqlite3
```

### 3. Asset 파이프라인
```bash
# 개발 중 assets 프리컴파일 (필요시)
bin/rails assets:precompile
```

## 🚨 트러블슈팅 가이드

### 자주 발생하는 문제들

#### 1. 포트 이미 사용 중
```bash
# 3000 포트 사용 중인 프로세스 찾기
lsof -ti:3000

# 프로세스 종료
kill -9 $(lsof -ti:3000)
```

#### 2. bundle install 실패
```bash
# gem 캐시 정리
bundle clean --force

# 새로 설치
bundle install
```

#### 3. npm install 실패
```bash
# node_modules 정리
rm -rf node_modules package-lock.json

# 새로 설치
npm install
```

#### 4. 데이터베이스 초기화
```bash
# 데이터베이스 재생성
bin/rails db:drop db:create db:migrate db:seed
```

### 로그 확인
```bash
# Rails 로그
tail -f log/development.log

# 테스트 로그
tail -f log/test.log
```

## 📝 다음 단계

1. **기능 개발**: 새로운 비즈니스 로직 구현
2. **테스트 확장**: 더 많은 엣지 케이스 커버
3. **성능 최적화**: 쿼리 최적화, 캐싱 전략
4. **배포 설정**: Docker, CI/CD 파이프라인 구성
5. **모니터링**: APM, 에러 트래킹 도구 연동

## 🎉 성공 지표

앱이 정상적으로 설정되고 실행되면:

- ✅ http://127.0.0.1:3000 접속 가능
- ✅ 로그인/로그아웃 기능 동작
- ✅ 조직 생성 및 관리 가능
- ✅ 태스크 관리 기능 동작
- ✅ 멀티테넌트 기능 동작
- ✅ API 엔드포인트 응답
- ✅ 시스템 테스트 통과

이제 안정적인 개발 환경에서 새로운 기능을 개발할 수 있습니다! 🚀
