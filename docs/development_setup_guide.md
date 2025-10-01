# 🔧 개발환경 설정 가이드

> **Creatia App 개발환경 완전 설정 가이드**  
> 효율적인 개발을 위한 통합 개발환경, 도구, 디버깅 방법 안내

## 📋 목차

- [🛠️ IDE 설정](#️-ide-설정)
- [🔍 디버깅 도구](#-디버깅-도구)
- [📊 개발 도구](#-개발-도구)
- [🧪 테스트 환경](#-테스트-환경)
- [⚡ 성능 최적화](#-성능-최적화)
- [🔄 Git 워크플로우](#-git-워크플로우)

## 🛠️ IDE 설정

### VS Code (권장)

#### 필수 확장 프로그램

```json
// .vscode/extensions.json
{
  "recommendations": [
    "shopify.ruby-lsp", // Ruby LSP (언어 서버)
    "bradlc.vscode-tailwindcss", // Tailwind CSS 지원
    "ms-vscode.vscode-typescript-next", // TypeScript 지원
    "esbenp.prettier-vscode", // 코드 포맷터
    "streetsidesoftware.code-spell-checker", // 스펠 체커
    "ms-vscode.vscode-json", // JSON 지원
    "yzhang.markdown-all-in-one", // Markdown 지원
    "ms-vscode.hexeditor", // 바이너리 편집기
    "humao.rest-client", // REST API 테스트
    "formulahendry.auto-rename-tag", // HTML 태그 자동 이름 변경
    "christian-kohler.path-intellisense", // 경로 자동완성
    "ms-vscode.vscode-todo-highlight" // TODO 하이라이트
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
    "codeActions": true,
    "documentSymbols": true,
    "foldingRanges": true,
    "selectionRanges": true,
    "semanticHighlighting": true
  },
  "ruby.lsp.rubyVersionManager": "rbenv",
  "ruby.lsp.bundleGemfile": "Gemfile",

  "tailwindCSS.includeLanguages": {
    "erb": "html",
    "ruby": "html"
  },
  "tailwindCSS.experimental.classRegex": [
    "class:\\s*['\"]([^'\"]*)['\"]",
    "className:\\s*['\"]([^'\"]*)['\"]"
  ],

  "emmet.includeLanguages": {
    "erb": "html"
  },

  "files.associations": {
    "*.html.erb": "erb",
    "*.js.erb": "javascript",
    "*.css.erb": "css",
    "Gemfile": "ruby",
    "Rakefile": "ruby",
    "*.ru": "ruby",
    "*.thor": "ruby"
  },

  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll": true,
    "source.organizeImports": true
  },

  "prettier.configPath": ".prettierrc",
  "prettier.ignorePath": ".prettierignore",

  "[ruby]": {
    "editor.defaultFormatter": "shopify.ruby-lsp",
    "editor.formatOnSave": true,
    "editor.tabSize": 2,
    "editor.insertSpaces": true
  },

  "[erb]": {
    "editor.defaultFormatter": "shopify.ruby-lsp",
    "editor.formatOnSave": true
  },

  "[javascript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },

  "[typescript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },

  "[json]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },

  "search.exclude": {
    "**/node_modules": true,
    "**/vendor": true,
    "**/tmp": true,
    "**/log": true,
    "**/coverage": true,
    "**/.git": true
  },

  "files.watcherExclude": {
    "**/tmp/**": true,
    "**/log/**": true,
    "**/node_modules/**": true,
    "**/vendor/**": true
  }
}
```

#### 작업 영역 설정

```json
// .vscode/tasks.json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Rails Server",
      "type": "shell",
      "command": "bin/rails server",
      "group": "build",
      "presentation": {
        "echo": true,
        "reveal": "always",
        "focus": false,
        "panel": "new"
      },
      "runOptions": {
        "runOn": "folderOpen"
      }
    },
    {
      "label": "Run Tests",
      "type": "shell",
      "command": "bundle exec rspec",
      "group": "test",
      "presentation": {
        "echo": true,
        "reveal": "always",
        "focus": false,
        "panel": "new"
      }
    },
    {
      "label": "Rails Console",
      "type": "shell",
      "command": "bin/rails console",
      "group": "build",
      "presentation": {
        "echo": true,
        "reveal": "always",
        "focus": true,
        "panel": "new"
      }
    },
    {
      "label": "Tailwind Watch",
      "type": "shell",
      "command": "bin/rails tailwindcss:watch",
      "group": "build",
      "isBackground": true,
      "presentation": {
        "echo": true,
        "reveal": "silent",
        "focus": false,
        "panel": "new"
      }
    }
  ]
}
```

#### 디버그 설정

```json
// .vscode/launch.json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Rails Server",
      "type": "ruby",
      "request": "launch",
      "program": "bin/rails",
      "args": ["server"],
      "cwd": "${workspaceFolder}",
      "env": {
        "RAILS_ENV": "development"
      }
    },
    {
      "name": "RSpec Tests",
      "type": "ruby",
      "request": "launch",
      "program": "bundle",
      "args": ["exec", "rspec", "${file}"],
      "cwd": "${workspaceFolder}",
      "env": {
        "RAILS_ENV": "test"
      }
    },
    {
      "name": "Rails Console",
      "type": "ruby",
      "request": "launch",
      "program": "bin/rails",
      "args": ["console"],
      "cwd": "${workspaceFolder}"
    }
  ]
}
```

### RubyMine 설정 (대안)

#### 필수 플러그인

- Ruby/Rails
- Database Tools
- Git Integration
- REST Client
- Markdown
- .env files support

#### 설정 팁

```ruby
# 코드 스타일 설정
# Settings > Editor > Code Style > Ruby
- Indent: 2 spaces
- Continuation indent: 2 spaces
- Use tab character: false
- Smart tabs: true

# 데이터베이스 연결
# Database Tools > + > PostgreSQL/MongoDB
# Connection 설정 후 테이블 스키마 확인 가능
```

## 🔍 디버깅 도구

### 기본 디버깅

#### debug gem (Rails 8 기본)

```ruby
# 코드에 디버그 포인트 추가
def some_method
  debugger  # 또는 binding.debug
  # 코드 실행이 여기서 멈춤

  puts "변수 확인: #{variable}"
end

# 디버그 명령어
# n (next) - 다음 줄
# s (step) - 메서드 안으로 들어가기
# c (continue) - 계속 실행
# l (list) - 현재 코드 보기
# p variable - 변수 값 출력
# pp variable - 예쁘게 출력
# bt (backtrace) - 스택 트레이스
# q (quit) - 디버거 종료
```

#### pry gem (고급 디버깅)

```ruby
# Gemfile에 추가
group :development, :test do
  gem 'pry-rails'
  gem 'pry-byebug'
  gem 'pry-doc'
end

# 사용법
binding.pry  # 디버그 포인트

# pry 명령어
# ls - 현재 객체의 메서드/변수 목록
# cd object - 객체 안으로 이동
# show-method method_name - 메서드 소스 보기
# edit method_name - 메서드 편집
# whereami - 현재 위치 표시
# hist - 명령어 히스토리
```

### Rails 콘솔 디버깅

```bash
# Rails 콘솔 시작
bin/rails console

# 로그 레벨 변경
Rails.logger.level = :debug

# SQL 쿼리 확인
ActiveRecord::Base.logger = Logger.new(STDOUT)

# 캐시 비활성화 (개발 중)
Rails.cache.clear
Rails.application.config.cache_classes = false

# 메모리 사용량 확인
ObjectSpace.each_object.group_by(&:class).transform_values(&:count)

# 느린 쿼리 찾기
ActiveRecord::Base.connection.instance_variable_get(:@logger).instance_variable_set(:@level, 0)
```

### 성능 프로파일링

```ruby
# Benchmark 사용
require 'benchmark'

result = Benchmark.measure do
  # 측정할 코드
  Task.includes(:assignee).limit(100).to_a
end

puts result
# =>   0.010000   0.000000   0.010000 (  0.012345)
#     사용자CPU   시스템CPU    총CPU시간  (실제시간)

# 메모리 프로파일링
require 'memory_profiler'

report = MemoryProfiler.report do
  # 메모리 사용량을 측정할 코드
  1000.times { Task.new(title: "Test") }
end

report.pretty_print

# 쿼리 분석
def analyze_queries
  queries = []
  subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
    queries << {
      sql: payload[:sql],
      duration: finish - start,
      binds: payload[:binds]
    }
  end

  yield

  queries.sort_by { |q| -q[:duration] }.first(10)
ensure
  ActiveSupport::Notifications.unsubscribe(subscriber)
end

# 사용법
slow_queries = analyze_queries do
  # 분석할 코드
  Organization.includes(:users, :tasks).limit(50).to_a
end

slow_queries.each do |query|
  puts "Duration: #{query[:duration]}ms"
  puts "SQL: #{query[:sql]}"
  puts "---"
end
```

## 📊 개발 도구

### 유용한 Rails 명령어

```bash
# 개발 서버 관리
bin/dev                    # 모든 서비스 시작 (포어맨 사용)
bin/rails server          # Rails 서버만 시작
bin/rails server -d       # 백그라운드에서 실행
bin/rails server -p 4000  # 다른 포트에서 실행

# 데이터베이스 관리
bin/rails db:create        # 데이터베이스 생성
bin/rails db:migrate       # 마이그레이션 실행
bin/rails db:rollback      # 마지막 마이그레이션 되돌리기
bin/rails db:reset         # DB 삭제 후 재생성
bin/rails db:seed          # 시드 데이터 로드
bin/rails db:setup         # DB 생성 + 마이그레이션 + 시드

# MongoDB 관리
bin/rails mongoid:create_indexes    # 인덱스 생성
bin/rails mongoid:remove_indexes    # 인덱스 삭제
bin/rails mongoid:create_sample_logs # 샘플 로그 생성
bin/rails mongoid:stats             # 통계 확인

# 캐시 관리
bin/rails cache:clear      # Rails 캐시 삭제
bin/rails tmp:clear        # 임시 파일 삭제
bin/rails log:clear        # 로그 파일 삭제

# 에셋 관리
bin/rails assets:precompile    # 에셋 컴파일
bin/rails assets:clean         # 오래된 에셋 삭제
bin/rails tailwindcss:build   # Tailwind CSS 빌드
bin/rails tailwindcss:watch   # Tailwind CSS 감시 모드

# 코드 품질
bundle exec rubocop           # 코드 스타일 검사
bundle exec rubocop -A        # 자동 수정
bundle exec brakeman          # 보안 검사
bundle exec rspec             # 테스트 실행
```

### 개발 서버 설정

#### Procfile.dev 설정

```yaml
# Procfile.dev
web: bin/rails server -p 3000
css: bin/rails tailwindcss:watch
js: yarn build --watch
mongodb: cd docker/mongodb && make up
caddy: bin/caddy run --config Caddyfile.dev
```

#### 환경변수 관리

```bash
# .env.development
# 개발 환경 전용 설정
RAILS_ENV=development
APP_DOMAIN=localhost:3000
BASE_DOMAIN=creatia.local

# 개발용 약한 시크릿 (보안 중요하지 않음)
SECRET_KEY_BASE=development_secret_key
JWT_SECRET=development_jwt_secret

# 개발용 데이터베이스
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=postgres
DATABASE_NAME=creatia_development

# MongoDB 개발 설정
MONGODB_URI=mongodb://localhost:27017/creatia_logs_development

# 디버그 설정
LOG_LEVEL=debug
RAILS_LOG_LEVEL=debug
ACTIVE_RECORD_VERBOSE_QUERY_LOGS=true

# Hot reload 설정
HOTWIRE_LIVERELOAD_ENABLED=true
```

### Git Hooks 설정

```bash
# .git/hooks/pre-commit
#!/bin/sh

echo "Running pre-commit checks..."

# 코드 스타일 검사
bundle exec rubocop --parallel
if [ $? -ne 0 ]; then
  echo "❌ RuboCop failed. Please fix style issues."
  exit 1
fi

# 보안 검사
bundle exec brakeman -q
if [ $? -ne 0 ]; then
  echo "❌ Brakeman found security issues."
  exit 1
fi

# 테스트 실행 (빠른 테스트만)
bundle exec rspec spec/models/ spec/services/
if [ $? -ne 0 ]; then
  echo "❌ Tests failed."
  exit 1
fi

echo "✅ Pre-commit checks passed!"
```

## 🧪 테스트 환경

### RSpec 설정

```ruby
# spec/spec_helper.rb
RSpec.configure do |config|
  # 출력 포맷
  config.formatter = :documentation

  # 실패한 테스트만 재실행
  config.example_status_persistence_file_path = "spec/examples.txt"

  # 랜덤 순서로 테스트 실행
  config.order = :random
  Kernel.srand config.seed

  # 프로파일링 활성화
  config.profile_examples = 10

  # 테스트 태그 필터링
  config.filter_run_when_matching :focus
  config.filter_run_excluding :slow unless ENV['RUN_SLOW_TESTS']
end
```

### Factory Bot 설정

```ruby
# spec/support/factory_bot.rb
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  # Factory 유효성 검사
  config.before(:suite) do
    FactoryBot.find_definitions
    FactoryBot.lint
  end
end

# 효율적인 팩토리 사용
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    name { Faker::Name.name }

    # 트레이트 사용
    trait :admin do
      role { 'admin' }
    end

    trait :with_organization do
      after(:create) do |user|
        organization = create(:organization)
        create(:organization_membership, user: user, organization: organization)
      end
    end
  end
end
```

### 테스트 데이터베이스 관리

```bash
# 테스트 DB 초기화
RAILS_ENV=test bin/rails db:create
RAILS_ENV=test bin/rails db:migrate
RAILS_ENV=test bin/rails db:seed

# 병렬 테스트 설정
# spec/rails_helper.rb
if ENV['PARALLEL_WORKERS']
  require 'parallel_tests'

  RSpec.configure do |config|
    config.before(:suite) do
      ParallelTests.first_process? and TestProf::FactoryBot.init
    end
  end
end

# 실행
bundle exec parallel_rspec spec/
```

## ⚡ 성능 최적화

### 개발 환경 최적화

```ruby
# config/environments/development.rb
Rails.application.configure do
  # 캐시 활성화 (필요시)
  config.cache_classes = false
  config.action_controller.perform_caching = true
  config.cache_store = :memory_store

  # 에셋 최적화
  config.assets.debug = false  # 개별 파일 대신 번들 사용
  config.assets.quiet = true   # 에셋 로그 줄이기

  # SQL 쿼리 최적화
  config.active_record.verbose_query_logs = true
  config.active_record.query_log_tags_enabled = true

  # 메일러 최적화
  config.action_mailer.perform_deliveries = false

  # 파일 감시 최적화
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker
end
```

### 데이터베이스 최적화

```ruby
# 인덱스 확인
def check_missing_indexes
  ActiveRecord::Base.connection.tables.each do |table|
    model = table.classify.constantize rescue next

    model.reflect_on_all_associations.each do |association|
      foreign_key = association.foreign_key

      unless has_index?(table, foreign_key)
        puts "Missing index: #{table}.#{foreign_key}"
      end
    end
  end
end

# N+1 쿼리 감지
config.after_initialize do
  Bullet.enable = true
  Bullet.bullet_logger = true
  Bullet.console = true
  Bullet.rails_logger = true
end
```

## 🔄 Git 워크플로우

### 브랜치 전략

```bash
# 기능 개발 워크플로우
git checkout main
git pull origin main
git checkout -b feature/새로운-기능

# 작업 후
git add .
git commit -m "feat: 새로운 기능 추가"
git push origin feature/새로운-기능

# Pull Request 생성 후 머지

# 핫픽스 워크플로우
git checkout main
git pull origin main
git checkout -b hotfix/버그수정
# 수정 후
git commit -m "fix: 치명적 버그 수정"
git push origin hotfix/버그수정
```

### 커밋 메시지 규칙

```bash
# 커밋 타입
feat:     새로운 기능 추가
fix:      버그 수정
docs:     문서 수정
style:    코드 스타일 변경 (세미콜론, 들여쓰기 등)
refactor: 코드 리팩토링
test:     테스트 추가/수정
chore:    빌드 프로세스나 도구 변경

# 예시
feat: 사용자 인증 시스템 추가
fix: 로그인 버튼 클릭 시 오류 수정
docs: API 문서 업데이트
refactor: 사용자 서비스 클래스 분리
test: 태스크 모델 테스트 추가
```

### Git 설정 최적화

```bash
# ~/.gitconfig
[user]
    name = Your Name
    email = your.email@example.com

[core]
    editor = code --wait
    autocrlf = input
    excludesfile = ~/.gitignore_global

[alias]
    co = checkout
    br = branch
    ci = commit
    st = status
    unstage = reset HEAD --
    last = log -1 HEAD
    visual = !gitk
    tree = log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit

[push]
    default = simple

[pull]
    rebase = true
```

---

## 📚 관련 문서

- [API 사용 가이드](api_usage_guide.md)
- [보안 가이드](security_guide.md)
- [데이터베이스 아키텍처](database_architecture.md)
- [메인 README](../README.md)




