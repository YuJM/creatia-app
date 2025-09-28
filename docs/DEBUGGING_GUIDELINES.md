# 🐛 디버깅 가이드라인

## 목차
1. [핵심 디버깅 원칙](#핵심-디버깅-원칙)
2. [권한 관련 디버깅](#권한-관련-디버깅)
3. [멀티테넌트 시스템 디버깅](#멀티테넌트-시스템-디버깅)
4. [일반적인 문제와 해결방법](#일반적인-문제와-해결방법)
5. [디버깅 도구 및 명령어](#디버깅-도구-및-명령어)
6. [로깅 전략](#로깅-전략)

## 핵심 디버깅 원칙

### 🎯 우선순위
1. **서버 로그 확인** - 항상 최우선
2. **데이터 상태 검증** - DB 실제 데이터 확인
3. **컨텍스트 확인** - 현재 tenant, user, session 상태
4. **권한 체인 추적** - 정책 실행 경로 확인

### ⚠️ 주의사항
- **가정하지 말 것**: "당연히 되겠지"는 없다
- **증거 기반**: 로그와 데이터로 확인
- **컨텍스트 인식**: 멀티테넌트 환경 특성 이해

## 권한 관련 디버깅

### 1. Pundit 권한 오류 디버깅

#### 증상
```
Pundit::NotAuthorizedError
```

#### 디버깅 체크리스트
```ruby
# 1. 현재 사용자 확인
Rails.logger.debug "Current user: #{current_user.inspect}"
Rails.logger.debug "User role: #{current_user.role_for(organization)}"

# 2. 현재 조직 확인
Rails.logger.debug "Current organization: #{ActsAsTenant.current_tenant.inspect}"
Rails.logger.debug "User membership: #{organization.membership_for(current_user).inspect}"

# 3. 정책 실행 추적
Rails.logger.debug "Policy: #{policy.class.name}"
Rails.logger.debug "Action: #{action_name}"
Rails.logger.debug "Authorized?: #{policy.send("#{action_name}?")}"
```

#### Rails Console에서 테스트
```ruby
# 권한 테스트
user = User.find(1)
org = Organization.find(1)
ActsAsTenant.current_tenant = org

# 정책 직접 테스트
policy = OrganizationPolicy.new(user, org)
policy.update?  # => true/false

# 멤버십 확인
org.member?(user)
org.role_for(user)
user.organizations.pluck(:id, :name)
```

### 2. 역할 계층 문제

#### Owner가 멤버로 인식 안 됨
```ruby
# 문제 코드
def member?
  role == 'member'  # Owner 제외됨!
end

# 올바른 코드
def member?
  %w[owner admin member contributor].include?(role)
end
```

#### Admin이 Owner 권한 행사
```ruby
# 컨트롤러에 추가
before_action :check_owner_protection

def check_owner_protection
  if params[:role] == 'owner' && !current_user_owner?
    raise Pundit::NotAuthorizedError
  end
end
```

## 멀티테넌트 시스템 디버깅

### 1. Tenant 컨텍스트 문제

#### 증상
- 데이터가 보이지 않음
- 잘못된 조직의 데이터 표시
- 권한이 있는데도 거부됨

#### 디버깅 방법
```ruby
# 현재 tenant 확인
Rails.logger.debug "Current tenant: #{ActsAsTenant.current_tenant&.id}"

# 모든 tenant 무시하고 확인
ActsAsTenant.without_tenant do
  Task.where(id: task_id).first
end

# Tenant 강제 설정
ActsAsTenant.with_tenant(organization) do
  # 작업 수행
end
```

### 2. 서브도메인 라우팅 문제

#### 로컬 개발 환경 설정
```bash
# /etc/hosts 파일에 추가
127.0.0.1 test-org.lvh.me
127.0.0.1 another-org.lvh.me
```

#### 디버깅 코드
```ruby
# 컨트롤러에서
Rails.logger.debug "Subdomain: #{request.subdomain}"
Rails.logger.debug "Host: #{request.host}"
Rails.logger.debug "Domain: #{request.domain}"
```

## 일반적인 문제와 해결방법

### 1. N+1 쿼리 문제

#### 탐지
```ruby
# config/environments/development.rb
config.after_initialize do
  Bullet.enable = true
  Bullet.rails_logger = true
end
```

#### 해결
```ruby
# 문제 코드
@tasks = Task.all
@tasks.each { |t| t.assignee.name }  # N+1!

# 해결 코드
@tasks = Task.includes(:assignee)
```

### 2. 캐시 관련 문제

#### 캐시 초기화
```bash
bin/rails cache:clear
bin/rails tmp:clear
```

#### 캐시 디버깅
```ruby
Rails.logger.debug "Cache key: #{cache_key}"
Rails.logger.debug "Cached?: #{Rails.cache.exist?(cache_key)}"
Rails.logger.debug "Cache value: #{Rails.cache.read(cache_key)}"
```

### 3. 세션 문제

#### 세션 디버깅
```ruby
# 컨트롤러에서
Rails.logger.debug "Session: #{session.to_hash}"
Rails.logger.debug "Session ID: #{session.id}"
```

#### 세션 초기화
```ruby
reset_session  # 컨트롤러에서
```

## 디버깅 도구 및 명령어

### Rails 명령어
```bash
# 로그 실시간 확인
tail -f log/development.log

# Rails 콘솔
bin/rails console

# 특정 환경 콘솔
RAILS_ENV=test bin/rails console

# DB 콘솔
bin/rails dbconsole
```

### 유용한 Gem들
```ruby
# Gemfile
group :development do
  gem 'pry-rails'      # 더 나은 콘솔
  gem 'better_errors'  # 더 나은 에러 페이지
  gem 'binding_of_caller'  # 에러 페이지에서 REPL
  gem 'bullet'         # N+1 쿼리 탐지
  gem 'rack-mini-profiler'  # 성능 프로파일링
end
```

### Pry 사용법
```ruby
# 코드에 breakpoint 추가
binding.pry

# Pry 콘솔에서
ls         # 현재 컨텍스트의 메서드 목록
cd object  # 객체 내부로 이동
show-method method_name  # 메서드 소스 보기
whereami   # 현재 위치 확인
continue   # 계속 실행
```

## 로깅 전략

### 1. 구조화된 로깅

```ruby
# app/services/base_service.rb
class BaseService
  def log_info(message, **context)
    Rails.logger.info({
      service: self.class.name,
      message: message,
      timestamp: Time.current,
      **context
    }.to_json)
  end
  
  def log_error(error, **context)
    Rails.logger.error({
      service: self.class.name,
      error: error.message,
      backtrace: error.backtrace[0..5],
      timestamp: Time.current,
      **context
    }.to_json)
  end
end
```

### 2. 권한 로깅

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  after_action :log_authorization
  
  private
  
  def log_authorization
    if @_pundit_policy_authorized
      Rails.logger.info({
        event: 'authorization',
        user_id: current_user&.id,
        action: "#{controller_name}##{action_name}",
        authorized: true,
        organization_id: ActsAsTenant.current_tenant&.id
      }.to_json)
    end
  end
end
```

### 3. 성능 로깅

```ruby
# 느린 쿼리 로깅
ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  if event.duration > 100  # 100ms 이상
    Rails.logger.warn({
      event: 'slow_query',
      duration: event.duration,
      sql: event.payload[:sql],
      name: event.payload[:name]
    }.to_json)
  end
end
```

## 테스트 환경 디버깅

### RSpec 디버깅
```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  # 실패한 테스트만 재실행
  config.example_status_persistence_file_path = ".rspec_status"
  
  # 느린 테스트 프로파일링
  config.profile_examples = 10
end

# 테스트 중 디버깅
it 'does something' do
  save_and_open_page  # Capybara: 현재 페이지 저장
  binding.pry         # 중단점
  pp user.attributes  # Pretty print
end
```

### 테스트 DB 문제
```bash
# 테스트 DB 재설정
RAILS_ENV=test bin/rails db:drop db:create db:schema:load

# 특정 테스트만 실행
bin/rspec spec/policies/organization_policy_spec.rb:42
```

## 프로덕션 디버깅 (주의!)

### 안전한 디버깅
```ruby
# Rails 콘솔에서 (읽기 전용)
ActiveRecord::Base.connection.execute("SET TRANSACTION READ ONLY")

# 특정 사용자로 테스트
ActsAsTenant.with_tenant(Organization.find(1)) do
  user = User.find(1)
  # 테스트 수행 (변경 사항은 롤백됨)
end
```

### 로그 수준 임시 변경
```ruby
# Rails 콘솔에서
Rails.logger.level = Logger::DEBUG
# 작업 수행
Rails.logger.level = Logger::INFO  # 원복
```

## 체크리스트 템플릿

### 🔍 권한 문제 디버깅 체크리스트
- [ ] 서버 로그 확인 (`tail -f log/development.log`)
- [ ] 현재 사용자 확인 (`current_user`)
- [ ] 현재 조직 확인 (`ActsAsTenant.current_tenant`)
- [ ] 멤버십 상태 확인 (`organization.membership_for(user)`)
- [ ] 역할 확인 (`user.role_for(organization)`)
- [ ] 정책 직접 테스트 (`policy.action?`)
- [ ] 데이터베이스 직접 확인
- [ ] 캐시 초기화 시도
- [ ] 테스트 작성하여 재현

### 🔍 성능 문제 디버깅 체크리스트
- [ ] Bullet으로 N+1 쿼리 확인
- [ ] 서버 로그에서 느린 쿼리 확인
- [ ] `rack-mini-profiler`로 프로파일링
- [ ] DB 인덱스 확인
- [ ] 캐시 활용도 확인
- [ ] 백그라운드 작업 큐 상태 확인

## 추가 리소스

- [Rails 디버깅 가이드](https://guides.rubyonrails.org/debugging_rails_applications.html)
- [Pundit 문서](https://github.com/varvet/pundit)
- [ActsAsTenant 문서](https://github.com/ErwinM/acts_as_tenant)
- [Better Errors](https://github.com/BetterErrors/better_errors)
- [Pry 문서](https://github.com/pry/pry)