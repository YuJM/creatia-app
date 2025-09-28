# 🚀 Creatia App

> **멀티테넌트 조직 관리 및 태스크 관리 플랫폼**

[![Ruby](https://img.shields.io/badge/Ruby-3.4.5+-red.svg)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-8.0.2+-red.svg)](https://rubyonrails.org/)
[![Node.js](https://img.shields.io/badge/Node.js-18+-green.svg)](https://nodejs.org/)
[![License](https://img.shields.io/badge/License-ISC-blue.svg)](LICENSE)

## 📋 목차

- [🚀 빠른 시작](#-빠른-시작)
- [📦 요구사항](#-요구사항)
- [⚡ 5분 만에 시작하기](#-5분-만에-시작하기)
- [🏗️ 아키텍처](#️-아키텍처)
- [🛠️ 상세 설치 가이드](#️-상세-설치-가이드)
- [🔧 개발 환경 설정](#-개발-환경-설정)
- [🧪 테스트](#-테스트)
- [🚀 배포](#-배포)
- [📚 문서](#-문서)
- [🤝 기여하기](#-기여하기)
- [🆘 문제 해결](#-문제-해결)

## 🚀 빠른 시작

### 📦 요구사항

| 구성요소       | 버전   | 용도                 |
| -------------- | ------ | -------------------- |
| **Ruby**       | 3.4.5+ | 백엔드 언어          |
| **Rails**      | 8.0.2+ | 웹 프레임워크        |
| **Node.js**    | 18+    | 프론트엔드 빌드 도구 |
| **PostgreSQL** | 14+    | 메인 데이터베이스    |
| **MongoDB**    | 6.0+   | 로그 데이터베이스    |
| **Git**        | 2.0+   | 버전 관리            |

### ⚡ 5분 만에 시작하기

```bash
# 1️⃣ 저장소 클론
git clone https://github.com/YuJM/creatia-app.git
cd creatia-app

# 2️⃣ 환경변수 설정
cp env.example .env

# 3️⃣ 의존성 설치
bundle install && npm install

# 4️⃣ 데이터베이스 설정
bin/rails db:create db:migrate db:seed

# 5️⃣ MongoDB 시작 (새 터미널에서)
cd docker/mongodb && make up

# 6️⃣ 서버 실행
bin/rails server
```

🎉 **완료!** <http://localhost:3000> 에서 앱을 확인하세요!

### 🔍 첫 실행 확인사항

서버가 정상적으로 실행되었는지 확인:

```bash
# 헬스체크
curl http://localhost:3000/up

# 응답: {"status":"ok","timestamp":"2025-01-XX..."}
```

### 📱 기본 계정으로 로그인

시드 데이터로 생성된 기본 계정:

- **이메일**: `admin@creatia.local`
- **비밀번호**: `password123`
- **조직**: `demo` (<http://demo.creatia.local:3000>)

## 🏗️ 아키텍처

### 🌐 멀티테넌트 서브도메인 구조

| 서브도메인 | URL                        | 용도                         |
| ---------- | -------------------------- | ---------------------------- |
| **메인**   | `localhost:3000`           | 랜딩 페이지, 사용자 등록     |
| **인증**   | `auth.creatia.local:3000`  | SSO, 로그인/로그아웃         |
| **조직**   | `{org}.creatia.local:3000` | 조직별 대시보드, 태스크 관리 |
| **API**    | `api.creatia.local:3000`   | REST API 엔드포인트          |
| **관리자** | `admin.creatia.local:3000` | 시스템 관리                  |

### ⚡ 핵심 기능

- 🏢 **멀티테넌트 조직 관리**: 완전한 데이터 격리
- 👥 **사용자 관리**: Devise 기반 인증, 역할 기반 권한 (RBAC)
- 📋 **태스크 관리**: 조직별 태스크 생성, 할당, 추적
- 🔐 **보안**: CanCanCan 권한 시스템, CSRF 보호
- 🌐 **RESTful API**: Alba 직렬화로 깔끔한 JSON API
- 📊 **로깅**: MongoDB 기반 활동/에러/API 로그 수집 및 분석
- 🔄 **실시간 업데이트**: Hotwire Turbo로 SPA 경험
- 🎨 **모던 UI**: Tailwind CSS 기반 반응형 디자인

### 🏗️ 이중 데이터베이스 아키텍처

| 데이터베이스   | 용도                                      | 저장 데이터                           |
| -------------- | ----------------------------------------- | ------------------------------------- |
| **PostgreSQL** | 메타데이터, 관계형 데이터                 | 사용자, 조직, 권한, 설정             |
| **MongoDB**    | 실행 데이터, 로그, 실시간 협업 데이터     | 태스크, 스프린트, 활동로그, 성능지표 |

### 🎯 핵심 도메인 모델

#### 📋 태스크 관리
- **Task**: MongoDB 기반 실행 데이터, 스냅샷 기반 성능 최적화
- **Sprint**: 애자일 스프린트 관리, 번다운 차트
- **Milestone**: 프로젝트 마일스톤 추적

#### 🏢 조직 관리
- **Organization**: 멀티테넌트 컨테이너, 서브도메인 기반
- **User**: Devise 인증, OAuth 지원 (Google, GitHub)
- **Team**: 팀 기반 협업, 권한 위임

#### 🔐 권한 시스템
- **Role**: 동적 역할 생성, 시스템/커스텀 역할
- **Permission**: 세분화된 권한 제어
- **PermissionAuditLog**: 권한 변경 추적

## 🛠️ 상세 설치 가이드

### 1️⃣ 시스템 요구사항 설치

#### macOS (Homebrew 사용)

```bash
# Ruby 설치 (rbenv 권장)
brew install rbenv ruby-build
rbenv install 3.4.5
rbenv global 3.4.5

# Node.js 설치
brew install node@18

# PostgreSQL 설치
brew install postgresql@14
brew services start postgresql@14

# Podman 설치 (MongoDB용)
brew install podman podman-compose
podman machine init && podman machine start
```

#### Ubuntu/Debian

```bash
# Ruby 설치
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
rbenv install 3.4.5 && rbenv global 3.4.5

# Node.js 설치
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# PostgreSQL 설치
sudo apt-get install postgresql postgresql-contrib

# Docker 설치 (MongoDB용)
sudo apt-get install docker.io docker-compose
```

### 2️⃣ 프로젝트 설정

```bash
# 저장소 클론
git clone https://github.com/YuJM/creatia-app.git
cd creatia-app

# 환경변수 설정
cp env.example .env
```

**중요**: `.env` 파일에서 다음 설정을 확인하세요:

```bash
# 데이터베이스 설정
DATABASE_HOST=localhost
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=your_password

# MongoDB 설정
MONGODB_URI=mongodb://creatia_user:creatia_pass@localhost:27017/creatia_logs

# 도메인 설정
BASE_DOMAIN=creatia.local
```

### 3️⃣ 의존성 설치

```bash
# Ruby gems 설치
bundle install

# Node.js 패키지 설치
npm install

# Rails 자산 컴파일
bin/rails assets:precompile
```

### 4️⃣ 데이터베이스 설정

```bash
# PostgreSQL 데이터베이스 생성 및 마이그레이션
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed

# MongoDB 컨테이너 시작
cd docker/mongodb
make up

# MongoDB 연결 테스트
cd ../..
bin/rails mongoid:test_connection
```

### 5️⃣ 서버 실행

```bash
# 개발 서버 시작
bin/rails server

# 또는 백그라운드에서 실행
bin/rails server -d
```

### 6️⃣ 서브도메인 설정 (선택사항)

완전한 멀티테넌트 기능을 위해 서브도메인 설정:

```bash
# hosts 파일에 추가 (macOS/Linux)
sudo vim /etc/hosts

# 다음 라인들 추가:
127.0.0.1 creatia.local
127.0.0.1 auth.creatia.local
127.0.0.1 api.creatia.local
127.0.0.1 admin.creatia.local
127.0.0.1 demo.creatia.local
```

## 🔧 개발 환경 설정

### 🛠️ 개발 도구

```bash
# 개발 서버 (Hot Reload 포함)
bin/dev

# 또는 개별 프로세스
bin/rails server          # 웹 서버
bin/rails tailwindcss:watch  # CSS 컴파일
bin/caddy                 # 리버스 프록시 (서브도메인용)
```

### 🔧 IDE 설정 권장사항

#### VS Code 확장 프로그램
```json
// .vscode/extensions.json
{
  "recommendations": [
    "shopify.ruby-lsp",
    "bradlc.vscode-tailwindcss",
    "ms-vscode.vscode-typescript-next",
    "esbenp.prettier-vscode",
    "streetsidesoftware.code-spell-checker"
  ]
}
```

#### VS Code 설정
```json
// .vscode/settings.json
{
  "ruby.lsp.enabledFeatures": {
    "diagnostics": true,
    "formatting": true,
    "codeActions": true
  },
  "tailwindCSS.includeLanguages": {
    "erb": "html"
  },
  "emmet.includeLanguages": {
    "erb": "html"
  }
}
```

### 🔍 디버깅 도구

```bash
# Rails 콘솔에서 디버깅
bin/rails console
> Rails.logger.level = :debug

# 브라우저 디버깅 (개발환경)
# 코드에 추가:
# binding.pry    # pry gem 사용 시
# debugger       # debug gem 사용 시

# 성능 프로파일링
bin/rails console
> require 'benchmark'
> Benchmark.measure { Task.includes(:assignee).limit(100).to_a }

# 메모리 사용량 확인
> ObjectSpace.each_object.group_by(&:class).transform_values(&:count)
```

### 📊 유용한 명령어

```bash
# 데이터베이스 관리
bin/rails db:reset        # DB 초기화
bin/rails db:seed         # 시드 데이터 로드
bin/rails console         # Rails 콘솔

# MongoDB 관리
bin/rails mongoid:stats           # 로그 통계
bin/rails mongoid:create_sample_logs  # 샘플 로그 생성
bin/rails mongoid:clear_logs      # 모든 로그 삭제

# 코드 품질
bundle exec rubocop       # 코드 스타일 검사
bundle exec brakeman      # 보안 검사
bundle exec rspec         # 테스트 실행
```

### 🌍 환경변수 설정

`.env` 파일에서 주요 설정:

```bash
# ===========================================
# 기본 애플리케이션 설정
# ===========================================
RAILS_ENV=development
APP_DOMAIN=localhost:3000
BASE_DOMAIN=creatia.local
USE_HTTPS=false

# ===========================================
# PostgreSQL 데이터베이스 (메타데이터)
# ===========================================
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=your_password
DATABASE_NAME=creatia_development

# ===========================================
# MongoDB (실행 데이터, 로그)
# ===========================================
MONGODB_URI=mongodb://creatia_user:creatia_pass@localhost:27017/creatia_logs
MONGODB_HOST=localhost
MONGODB_PORT=27017
MONGODB_DATABASE=creatia_logs
MONGODB_USERNAME=creatia_user
MONGODB_PASSWORD=creatia_pass

# ===========================================
# 인증 및 보안
# ===========================================
# JWT 시크릿 (SSO용)
JWT_SECRET=your_jwt_secret_key

# Devise 시크릿
SECRET_KEY_BASE=your_rails_secret_key

# OAuth 제공자 (선택사항)
GOOGLE_OAUTH_CLIENT_ID=your_google_client_id
GOOGLE_OAUTH_CLIENT_SECRET=your_google_client_secret
GITHUB_OAUTH_CLIENT_ID=your_github_client_id
GITHUB_OAUTH_CLIENT_SECRET=your_github_client_secret

# ===========================================
# 외부 서비스 통합
# ===========================================
# GitHub 웹훅 (선택사항)
GITHUB_WEBHOOK_SECRET=your_webhook_secret

# 알림 서비스 (선택사항)
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=your_smtp_user
SMTP_PASSWORD=your_smtp_password

# ===========================================
# 보안 설정 (중요!)
# ===========================================
# 프로덕션에서는 반드시 강력한 비밀번호 사용
# 개발환경에서도 실제 서비스와 구별되는 값 사용

# Rails Master Key (config/master.key에서 자동 생성)
# RAILS_MASTER_KEY=your_master_key_here

# CORS 설정 (API 서브도메인용)
CORS_ORIGINS=https://creatia.local,https://app.creatia.local

# 로그 레벨 설정
LOG_LEVEL=info  # debug, info, warn, error

# 세션 만료 시간 (분)
SESSION_TIMEOUT=480  # 8시간

# JWT 토큰 만료 시간
JWT_EXPIRATION=24h  # 24시간
```

### 🔒 보안 체크리스트

#### 🔐 인증 보안
- [ ] JWT 시크릿 키가 충분히 복잡한지 확인
- [ ] OAuth 클라이언트 시크릿이 안전하게 보관되는지 확인
- [ ] 세션 타임아웃이 적절히 설정되었는지 확인
- [ ] 비밀번호 정책이 강력한지 확인 (Devise 설정)

#### 🌐 네트워크 보안
- [ ] HTTPS 사용 (프로덕션 환경)
- [ ] CORS 설정이 올바른지 확인
- [ ] API Rate Limiting 설정
- [ ] 서브도메인별 접근 제어 확인

#### 🗄️ 데이터베이스 보안
- [ ] PostgreSQL 접속 계정에 최소 권한 부여
- [ ] MongoDB 인증 활성화
- [ ] 데이터베이스 연결 암호화 (SSL/TLS)
- [ ] 백업 데이터 암호화

#### 📝 로그 보안
- [ ] 민감한 정보가 로그에 기록되지 않는지 확인
- [ ] 로그 접근 권한 제한
- [ ] 로그 로테이션 설정

```bash
# 보안 취약점 검사
bundle exec brakeman

# 의존성 보안 검사
bundle audit

# 코드 품질 검사
bundle exec rubocop --only Security/

# MongoDB 보안 설정 확인
bin/rails runner "puts Mongoid.default_client.cluster.servers.first.address"
```

## 🧪 테스트

### 🚀 테스트 실행

```bash
# 전체 테스트 실행
bundle exec rspec

# 시스템 통합 테스트 (권장)
bundle exec rspec spec/system/

# CI용 핵심 테스트
bundle exec rspec spec/system/ci_integration_spec.rb

# E2E 테스트 (Playwright)
npm run e2e
npm run e2e:headed    # 브라우저에서 확인
npm run e2e:debug     # 디버그 모드

# 커버리지 확인
open coverage/index.html
```

### 📊 테스트 구조

| 테스트 타입           | 위치                              | 용도                   |
| --------------------- | --------------------------------- | ---------------------- |
| **Unit Tests**        | `spec/models/`, `spec/services/`  | 개별 컴포넌트 테스트   |
| **Integration Tests** | `spec/requests/`, `spec/routing/` | API 엔드포인트 테스트  |
| **System Tests**      | `spec/system/`                    | 전체 사용자 플로우     |
| **Feature Tests**     | `spec/features/`                  | BDD 스타일 기능 테스트 |
| **E2E Tests**         | `e2e/`                            | 브라우저 자동화 테스트 |

### 🔍 테스트 데이터

```bash
# 테스트 데이터 생성
bundle exec rails db:seed RAILS_ENV=test

# 팩토리 데이터 확인
bundle exec rails console -e test
> FactoryBot.create(:user)
> FactoryBot.create(:organization)
```

## 🚀 배포

### 🐳 Docker 배포 (권장)

```bash
# Docker 이미지 빌드
docker build -t creatia-app .

# 컨테이너 실행
docker run -p 3000:3000 \
  -e DATABASE_URL=postgresql://user:pass@host:5432/db \
  -e MONGODB_URI=mongodb://user:pass@host:27017/logs \
  creatia-app
```

### ☁️ 클라우드 배포

#### Heroku

```bash
# Heroku CLI 설치
brew install heroku/brew/heroku

# 앱 생성 및 배포
heroku create your-app-name
heroku addons:create heroku-postgresql:hobby-dev
heroku addons:create mongolab:sandbox
git push heroku main
```

#### DigitalOcean App Platform

```yaml
# .do/app.yaml
name: creatia-app
services:
  - name: web
    source_dir: /
    github:
      repo: YuJM/creatia-app
      branch: main
    run_command: bundle exec rails server -p $PORT
    environment_slug: ruby
    instance_count: 1
    instance_size_slug: basic-xxs
    envs:
      - key: RAILS_ENV
        value: production
      - key: DATABASE_URL
        value: ${db.DATABASE_URL}
```

### 🔧 Kamal 배포 (Rails 8 기본)

```bash
# Kamal 설정
kamal setup

# 배포 실행
kamal deploy

# 롤백
kamal rollback
```

## 🆘 문제 해결

### 🚨 자주 발생하는 문제

#### 1. 포트 3000 사용 중

```bash
# 포트 사용 프로세스 확인
lsof -i :3000

# 프로세스 종료
kill -9 $(lsof -ti:3000)
```

#### 2. Bundle 설치 실패

```bash
# Gem 캐시 정리
bundle clean --force
rm -rf vendor/bundle
bundle install
```

#### 3. Node.js 패키지 오류

```bash
# node_modules 재설치
rm -rf node_modules package-lock.json
npm install
```

#### 4. 데이터베이스 연결 오류

```bash
# PostgreSQL 서비스 확인 (macOS)
brew services list | grep postgresql

# PostgreSQL 재시작
brew services restart postgresql@14

# 데이터베이스 재생성
bin/rails db:drop db:create db:migrate db:seed
```

#### 5. MongoDB 연결 오류

```bash
# MongoDB 컨테이너 상태 확인
cd docker/mongodb
make status

# MongoDB 재시작
make down && make up

# 연결 테스트
bin/rails mongoid:test_connection
```

### 📋 로그 확인

```bash
# 개발 로그 실시간 확인
tail -f log/development.log

# 에러 로그만 확인
tail -f log/development.log | grep ERROR

# 테스트 로그
tail -f log/test.log

# Rails 콘솔에서 로그 확인
bin/rails console
> Rails.logger.info "테스트 메시지"
```

### 🔧 디버깅 도구

```bash
# Rails 콘솔
bin/rails console

# 데이터베이스 콘솔
bin/rails dbconsole

# Rails 환경 확인
bin/rails runner "puts Rails.env"

# 의존성 확인
bundle exec rails runner "puts Rails.version"
```

### 📞 추가 도움

- 📚 [상세 문서](docs/) - 프로젝트 내 상세 가이드
- 🐛 [Issues](https://github.com/YuJM/creatia-app/issues) - 버그 리포트
- 💬 [Discussions](https://github.com/YuJM/creatia-app/discussions) - 질문 및 토론

## 📖 프로젝트 사용법

### 🏢 조직 관리

#### 새 조직 생성

```bash
# Rails 콘솔에서
bin/rails console

# 새 조직 생성
org = Organization.create!(
  name: "새로운 조직",
  subdomain: "neworg",
  owner: User.first
)
```

#### 조직별 사용자 관리

```bash
# 조직에 사용자 추가
user = User.create!(email: "user@example.com", password: "password123")
org.users << user

# 사용자에게 역할 부여
user.add_role(:member, org)
```

### 📋 태스크 관리

#### 태스크 생성 및 할당

```bash
# 새 태스크 생성
task = Task.create!(
  title: "새로운 태스크",
  description: "태스크 설명",
  organization: org,
  assignee: user,
  status: "todo"
)
```

#### 태스크 상태 변경

```bash
# 태스크 진행 상태 업데이트
task.update!(status: "in_progress")
task.update!(status: "completed")
```

### 🔐 인증 및 권한

#### API 인증 (HTTP Basic Auth)

```bash
# 개발/테스트 환경에서 API 호출
curl -u "user@example.com:password123" \
  http://localhost:3000/api/v1/tasks
```

#### 역할 기반 권한 확인

```bash
# 사용자 권한 확인
user.can?(:read, Task)
user.can?(:create, Task)
user.can?(:manage, org)
```

### 📊 로깅 및 모니터링

#### 활동 로그 확인

```bash
# MongoDB에서 로그 조회
bin/rails console
> ActivityLog.where(action: "task.created").limit(10)

# 로그 통계
bin/rails mongoid:stats
```

#### API 로그 분석

```bash
# API 호출 로그 확인
> ApiLog.where(endpoint: "/api/v1/tasks").count
> ApiLog.where(created_at: 1.day.ago..Time.current).count
```

## 🚀 API 사용법

### 🔑 인증 방법

#### 1. HTTP Basic Auth (개발/테스트용)

```bash
# 기본 인증으로 API 호출
curl -u "user@example.com:password123" \
  http://api.creatia.local:3000/api/v1/tasks
```

#### 2. JWT 토큰 인증 (프로덕션용)

```bash
# 1. 로그인으로 토큰 발급
curl -X POST http://api.creatia.local:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123",
    "organization_subdomain": "demo"
  }'

# 응답 예시:
# {
#   "token": "eyJhbGciOiJIUzI1NiIs...",
#   "user": { "id": "123", "email": "user@example.com" },
#   "organization": { "id": "456", "name": "Demo Org" }
# }

# 2. 토큰을 사용해 API 호출
curl -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIs..." \
  http://api.creatia.local:3000/api/v1/tasks
```

### 📋 태스크 API 예제

```bash
# 태스크 목록 조회
GET /api/v1/tasks

# 응답 예시:
{
  "tasks": [
    {
      "id": "task_001",
      "title": "새로운 기능 개발",
      "description": "사용자 대시보드 개선",
      "status": "in_progress",
      "priority": "high",
      "assignee": {
        "id": "user_123",
        "name": "김개발",
        "email": "dev@example.com"
      },
      "estimated_hours": 8.0,
      "actual_hours": 3.5,
      "due_date": "2025-10-01",
      "created_at": "2025-09-28T10:00:00Z",
      "updated_at": "2025-09-28T14:30:00Z"
    }
  ],
  "meta": {
    "total": 25,
    "page": 1,
    "per_page": 10
  }
}

# 새 태스크 생성
POST /api/v1/tasks
Content-Type: application/json

{
  "task": {
    "title": "새로운 태스크",
    "description": "태스크 설명",
    "priority": "medium",
    "assignee_id": "user_123",
    "due_date": "2025-10-15",
    "estimated_hours": 4.0
  }
}

# 태스크 상태 변경
PATCH /api/v1/tasks/:id/status
Content-Type: application/json

{
  "status": "completed"
}

# 태스크 할당
PATCH /api/v1/tasks/:id/assign
Content-Type: application/json

{
  "assignee_id": "user_456"
}
```

### 🏢 조직 API 예제

```bash
# 조직 정보 조회
GET /api/v1/organizations/current

# 응답:
{
  "organization": {
    "id": "org_123",
    "name": "Demo 조직",
    "subdomain": "demo",
    "plan": "team",
    "active": true,
    "member_count": 15,
    "task_count": 142,
    "created_at": "2025-01-15T09:00:00Z"
  }
}

# 조직 멤버 조회
GET /api/v1/members

# 응답:
{
  "members": [
    {
      "id": "member_001",
      "user": {
        "id": "user_123",
        "name": "김개발",
        "email": "dev@example.com"
      },
      "role": "admin",
      "active": true,
      "joined_at": "2025-01-20T10:00:00Z"
    }
  ]
}

# 멤버 초대
POST /api/v1/members/invite
Content-Type: application/json

{
  "email": "newuser@example.com",
  "role": "member",
  "message": "조직에 오신 것을 환영합니다!"
}
```

### 📈 대시보드 API 예제

```bash
# 태스크 통계
GET /api/v1/tasks/stats

# 응답:
{
  "stats": {
    "total": 142,
    "by_status": {
      "todo": 45,
      "in_progress": 23,
      "review": 8,
      "done": 66
    },
    "by_priority": {
      "low": 32,
      "medium": 78,
      "high": 25,
      "urgent": 7
    },
    "completion_rate": 46.5,
    "avg_completion_time": 3.2
  }
}

# 알림 내역
GET /api/v1/notifications?unread_only=true

# 응답:
{
  "notifications": [
    {
      "id": "notif_001",
      "type": "task_assigned",
      "title": "새 태스크가 할당되었습니다",
      "message": "'새로운 기능 개발' 태스크가 할당되었습니다.",
      "read": false,
      "created_at": "2025-09-28T15:30:00Z"
    }
  ],
  "unread_count": 3
}
```

### 👨‍💻 개발자 도구

```bash
# API 테스트 도구
bin/rails console

# 토큰 생성 테스트
> user = User.first
> org = Organization.first
> token = JwtService.encode(user_id: user.id, organization_id: org.id)
> puts token

# API 엔드포인트 테스트
> response = HTTP.auth("Bearer #{token}")
>               .get("http://api.creatia.local:3000/api/v1/tasks")
> puts response.body

# API 상태 확인
curl http://api.creatia.local:3000/api/v1/health/status
```

## 📚 문서

### 📖 상세 가이드

| 문서                                                              | 설명                        |
| ----------------------------------------------------------------- | --------------------------- |
| [**앱 설치 및 문제 해결**](docs/app_setup_and_troubleshooting.md) | 설치 과정 및 트러블슈팅     |
| [**시스템 통합 테스트**](docs/system_integration_tests.md)        | 포괄적인 테스트 스위트 구현 |
| [**멀티테넌트 가이드**](docs/multi.md)                            | 멀티테넌트 아키텍처 설명    |
| [**디자인 시스템**](docs/design_system.md)                        | UI 컴포넌트 가이드          |
| [**API 문서**](docs/api.md)                                       | REST API 엔드포인트         |

### 🏗️ 아키텍처 문서

| 문서                                                     | 설명                  |
| -------------------------------------------------------- | --------------------- |
| [**프로젝트 구조**](docs/project_hierarchy_structure.md) | 디렉토리 구조 및 책임 |
| [**역할 및 권한**](docs/ROLE_HIERARCHY.md)               | RBAC 시스템 설명      |
| [**시간 추적 시스템**](docs/time_tracking_system.md)     | 시간 관리 기능        |

## 🛠️ 기술 스택

### 🔧 Backend

| 기술             | 버전   | 용도              |
| ---------------- | ------ | ----------------- |
| **Ruby**         | 3.4.5+ | 프로그래밍 언어   |
| **Rails**        | 8.0.2+ | 웹 프레임워크     |
| **PostgreSQL**   | 14+    | 메인 데이터베이스 |
| **MongoDB**      | 6.0+   | 로그 데이터베이스 |
| **Devise**       | 4.9+   | 인증 시스템       |
| **CanCanCan**    | 3.6+   | 권한 관리         |
| **ActsAsTenant** | 1.0+   | 멀티테넌트        |
| **Alba**         | 3.5+   | JSON 직렬화       |

### 🎨 Frontend

| 기술              | 버전  | 용도                  |
| ----------------- | ----- | --------------------- |
| **Hotwire**       | 8.0+  | SPA 경험              |
| **Tailwind CSS**  | 4.1+  | 스타일링              |
| **Stimulus**      | 3.0+  | JavaScript 프레임워크 |
| **ViewComponent** | 3.20+ | 컴포넌트 시스템       |

### 🧪 Testing & Quality

| 기술            | 용도              |
| --------------- | ----------------- |
| **RSpec**       | 테스트 프레임워크 |
| **Factory Bot** | 테스트 데이터     |
| **Capybara**    | 통합 테스트       |
| **Playwright**  | E2E 테스트        |
| **SimpleCov**   | 코드 커버리지     |
| **Rubocop**     | 코드 스타일       |
| **Brakeman**    | 보안 검사         |

## 🤝 기여하기

### 🔄 개발 워크플로우

```bash
# 1. 저장소 포크 및 클론
git clone https://github.com/YOUR_USERNAME/creatia-app.git
cd creatia-app

# 2. 기능 브랜치 생성
git checkout -b feature/your-feature-name

# 3. 개발 및 테스트
# ... 코드 작성 ...
bundle exec rspec
npm run e2e

# 4. 커밋 및 푸시
git add .
git commit -m "feat: 새로운 기능 추가"
git push origin feature/your-feature-name

# 5. Pull Request 생성
# GitHub에서 Pull Request 생성
```

### 📝 코드 스타일

```bash
# 코드 스타일 검사
bundle exec rubocop

# 자동 수정
bundle exec rubocop -A

# 보안 검사
bundle exec brakeman

# 테스트 실행
bundle exec rspec spec/system/ci_integration_spec.rb
```

### 🏷️ 커밋 메시지 규칙

```text
feat: 새로운 기능 추가
fix: 버그 수정
docs: 문서 수정
style: 코드 스타일 변경
refactor: 코드 리팩토링
test: 테스트 추가/수정
chore: 빌드 프로세스 또는 도구 변경
```

## 📊 모니터링

### 📈 성능 기준선

| 지표                  | 목표          | 모니터링 |
| --------------------- | ------------- | -------- |
| **페이지 로드 시간**  | < 3초         | ✅       |
| **데이터베이스 쿼리** | < 15개/페이지 | ✅       |
| **메모리 사용량**     | 모니터링 중   | 🔄       |
| **API 응답 시간**     | < 500ms       | ✅       |

### 🔍 헬스체크

```bash
# 앱 상태 확인
curl http://localhost:3000/up
# 응답: {"status":"ok","timestamp":"..."}

# 데이터베이스 연결 확인
curl http://localhost:3000/health/database

# MongoDB 연결 확인
curl http://localhost:3000/health/mongodb
```

## 📈 프로젝트 현황

### ✅ 최근 완료 작업 (2025.09)

- 🚀 **앱 설치 및 실행 환경 구축**
- 🔧 **라우팅 중복 문제 해결** (devise_for, root 라우트)
- 🔐 **인증 오류 수정** (current_user 메서드 문제)
- 🧪 **시스템 레벨 통합 테스트 구현**
  - 애플리케이션 부팅 검증
  - HTTP 요청 플로우 테스트
  - 서브도메인별 기능 테스트
  - 인증 플로우 통합 테스트
  - CI/CD용 핵심 테스트
- 📊 **성능 및 보안 기준선 설정**
- 📚 **포괄적인 문서화**

### 🎯 주요 성과

- ✅ **18개 시스템 테스트 중 17개 통과**
- 🔍 **설정 오류 조기 발견 시스템 구축**
- 🚀 **CI/CD 파이프라인 품질 보장**
- 💪 **개발 효율성 및 안정성 향상**

### 🗺️ 로드맵

- [ ] 🔄 **실시간 알림 시스템**
- [ ] 📱 **모바일 앱 API**
- [ ] 🔍 **고급 검색 기능**
- [ ] 📊 **대시보드 분석**
- [ ] 🌐 **다국어 지원**

---

## 📄 라이선스

이 프로젝트는 [ISC License](LICENSE) 하에 배포됩니다.

## 🙏 감사의 말

- **Rails Community** - 훌륭한 프레임워크 제공
- **Contributors** - 프로젝트에 기여해주신 모든 분들
- **Open Source** - 오픈소스 생태계에 감사드립니다

---

**🚀 Creatia App**: 안정적이고 확장 가능한 멀티테넌트 플랫폼을 구축하고 있습니다.

_문서가 도움이 되었다면 ⭐ 스타를 눌러주세요!_
