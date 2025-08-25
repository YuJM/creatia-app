# 🏗️ Creatia SSO 멀티테넌트 구축 전략

## 📋 개요

Apartment + Devise + Pundit을 활용한 중앙 집중식 SSO 인증과 조직별 멀티테넌트 아키텍처 구현 전략입니다.

---

## Apartment 설치

## 🔐 SSO 인증 아키텍처

### 1. 중앙 인증 도메인 구조

```
주 도메인: auth.creatia.io (인증 전용)
테넌트: {org}.creatia.io (조직별 워크스페이스)
```

### 2. Devise 설정 (중앙 인증)

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # 인증은 메인 도메인에서만
  constraints subdomain: 'auth' do
    devise_for :users, controllers: {
      omniauth_callbacks: 'users/omniauth_callbacks',
      sessions: 'users/sessions'
    }
  end

  # 조직별 라우팅
  constraints subdomain: /(?!auth|www)/ do
    scope :module => 'tenant' do
      resources :projects
      resources :tasks
      resources :sprints
    end
  end
end
```

### 3. 사용자 모델 (Global Schema)

```ruby
# app/models/user.rb
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:github, :google_oauth2]

  has_many :organization_memberships, dependent: :destroy
  has_many :organizations, through: :organization_memberships

  def current_organization(subdomain)
    organizations.find_by(subdomain: subdomain)
  end

  def member_of?(organization)
    organizations.include?(organization)
  end
end
```

### 4. 조직 멤버십 관리

```ruby
# app/models/organization_membership.rb
class OrganizationMembership < ApplicationRecord
  belongs_to :user
  belongs_to :organization

  ROLES = %w[owner admin member viewer].freeze

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :organization_id }

  scope :active, -> { where(active: true) }
end
```

---

## 🏢 Apartment 멀티테넌트 설정

### 1. Apartment 초기화

```ruby
# config/initializers/apartment.rb
require 'apartment/elevators/subdomain'

Apartment.configure do |config|
  # 스키마 기반 멀티테넌트
  config.use_schemas = true

  # 공용 테이블 (전역 데이터)
  config.excluded_models = %w{
    User
    Organization
    OrganizationMembership
    BillingPlan
    GlobalSetting
  }

  # 영구 스키마
  config.persistent_schemas = %w{ shared_extensions public }

  # 테넌트 목록 동적 로딩
  config.tenant_names = -> {
    Organization.pluck(:subdomain)
  }

  # 자동 스키마 생성
  config.database_schema_file = nil
end

# Elevator 설정 (서브도메인 기반)
Rails.application.config.middleware.use Apartment::Elevators::Subdomain
```

### 2. 커스텀 Elevator (SSO 호환)

```ruby
# app/middleware/sso_tenant_elevator.rb
class SsoTenantElevator < Apartment::Elevators::Subdomain
  def parse_tenant_name(request)
    subdomain = request.subdomain

    # auth 서브도메인은 테넌트 전환하지 않음
    return nil if subdomain == 'auth' || subdomain.blank?

    # 조직 존재 여부 확인
    organization = Organization.find_by(subdomain: subdomain)
    return nil unless organization

    # 현재 사용자가 해당 조직 멤버인지 확인
    if current_user_has_access?(request, organization)
      subdomain
    else
      redirect_to_auth_with_error(request, organization)
      nil
    end
  end

  private

  def current_user_has_access?(request, organization)
    user_id = request.session[:user_id]
    return false unless user_id

    OrganizationMembership.exists?(
      user_id: user_id,
      organization_id: organization.id,
      active: true
    )
  end

  def redirect_to_auth_with_error(request, organization)
    redirect_url = "https://auth.creatia.io/access_denied?org=#{organization.subdomain}"
    request.env['apartment.redirect_url'] = redirect_url
  end
end
```

---

## 🔑 SSO 플로우 구현

### 1. 로그인 컨트롤러

```ruby
# app/controllers/users/sessions_controller.rb
class Users::SessionsController < Devise::SessionsController
  before_action :check_subdomain

  def create
    super do |user|
      if user.persisted?
        redirect_to_intended_organization(user)
        return
      end
    end
  end

  private

  def check_subdomain
    # auth 서브도메인이 아니면 리다이렉트
    unless request.subdomain == 'auth'
      intended_org = request.subdomain
      redirect_to "https://auth.creatia.io/users/sign_in?return_to=#{intended_org}"
    end
  end

  def redirect_to_intended_organization(user)
    return_to = params[:return_to]

    if return_to.present?
      organization = user.organizations.find_by(subdomain: return_to)
      if organization
        redirect_to "https://#{return_to}.creatia.io/dashboard"
        return
      end
    end

    # 기본: 첫 번째 조직으로 이동
    first_org = user.organizations.first
    if first_org
      redirect_to "https://#{first_org.subdomain}.creatia.io/dashboard"
    else
      redirect_to new_organization_path
    end
  end
end
```

### 2. OAuth 콜백 처리

```ruby
# app/controllers/users/omniauth_callbacks_controller.rb
class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def github
    handle_oauth_callback('GitHub')
  end

  def google_oauth2
    handle_oauth_callback('Google')
  end

  private

  def handle_oauth_callback(provider)
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      sign_in_and_redirect @user, event: :authentication
      set_flash_message(:notice, :success, kind: provider) if is_navigational_format?
    else
      session["devise.#{provider.downcase}_data"] = request.env["omniauth.auth"].except(:extra)
      redirect_to new_user_registration_url
    end
  end
end
```

### 3. User 모델 OAuth 확장

```ruby
# app/models/user.rb 추가
class User < ApplicationRecord
  # ... 기존 코드 ...

  def self.from_omniauth(auth)
    where(email: auth.info.email).first_or_create do |user|
      user.email = auth.info.email
      user.password = Devise.friendly_token[0, 20]
      user.name = auth.info.name
      user.github_username = auth.info.nickname if auth.provider == 'github'
      user.google_id = auth.uid if auth.provider == 'google_oauth2'
    end
  end
end
```

---

## 🛡️ Pundit 권한 관리

### 1. 기본 Policy

```ruby
# app/policies/application_policy.rb
class ApplicationPolicy
  attr_reader :user, :record, :organization

  def initialize(user, record)
    @user = user
    @record = record
    @organization = current_organization
  end

  def index?
    member?
  end

  def show?
    member?
  end

  def create?
    member?
  end

  def update?
    owner_or_admin?
  end

  def destroy?
    owner_or_admin?
  end

  private

  def current_organization
    Organization.find_by(subdomain: Apartment::Tenant.current)
  end

  def membership
    @membership ||= OrganizationMembership.find_by(
      user: user,
      organization: organization
    )
  end

  def member?
    membership&.active?
  end

  def admin?
    membership&.role.in?(%w[admin owner])
  end

  def owner?
    membership&.role == 'owner'
  end

  def owner_or_admin?
    admin?
  end
end
```

### 2. Task Policy 예시

```ruby
# app/policies/task_policy.rb
class TaskPolicy < ApplicationPolicy
  def show?
    member?
  end

  def create?
    member?
  end

  def update?
    assigned_to_me? || admin?
  end

  def destroy?
    admin?
  end

  def assign?
    admin?
  end

  private

  def assigned_to_me?
    record.assigned_user_id == user.id
  end
end
```

---

## 🔄 테넌트 전환 시스템

### 1. 조직 선택 컨트롤러

```ruby
# app/controllers/organization_switcher_controller.rb
class OrganizationSwitcherController < ApplicationController
  before_action :authenticate_user!

  def show
    @organizations = current_user.organizations.includes(:organization_memberships)
  end

  def switch
    organization = current_user.organizations.find_by(subdomain: params[:subdomain])

    if organization
      redirect_to "https://#{organization.subdomain}.creatia.io/dashboard"
    else
      flash[:error] = "접근 권한이 없습니다."
      redirect_back(fallback_location: root_path)
    end
  end
end
```

### 2. 테넌트별 베이스 컨트롤러

```ruby
# app/controllers/tenant/base_controller.rb
class Tenant::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_access
  before_action :set_current_organization

  private

  def ensure_organization_access
    unless current_user.member_of?(current_organization)
      redirect_to "https://auth.creatia.io/access_denied?org=#{request.subdomain}"
    end
  end

  def current_organization
    @current_organization ||= Organization.find_by!(subdomain: request.subdomain)
  end

  def set_current_organization
    @current_organization = current_organization
  end

  def current_membership
    @current_membership ||= OrganizationMembership.find_by(
      user: current_user,
      organization: current_organization
    )
  end
end
```

---

## 🚀 배포 및 DNS 설정

### 1. 와일드카드 도메인 설정

```yaml
# config/cable.yml
production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" } %>
  channel_prefix: creatia_production_<%= Apartment::Tenant.current || 'public' %>
```

### 2. SSL 인증서 (Let's Encrypt)

```bash
# 와일드카드 SSL 인증서 발급
certbot certonly --dns-route53 -d "*.creatia.io" -d "creatia.io"
```

### 3. Nginx 설정

```nginx
# /etc/nginx/sites-available/creatia
server {
    listen 443 ssl http2;
    server_name *.creatia.io creatia.io;

    ssl_certificate /etc/letsencrypt/live/creatia.io/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/creatia.io/privkey.pem;

    location / {
        proxy_pass http://rails_app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## 🔧 개발 환경 설정

### 1. 로컬 개발용 호스트 설정

```bash
# /etc/hosts 추가
127.0.0.1 creatia.local
127.0.0.1 auth.creatia.local
127.0.0.1 acme.creatia.local
127.0.0.1 demo.creatia.local
```

### 2. 개발용 시드 데이터

```ruby
# db/seeds.rb
# 테스트 조직 생성
demo_org = Organization.create!(
  name: "Demo Organization",
  subdomain: "demo",
  plan: "team"
)

# 테스트 사용자
admin_user = User.create!(
  email: "admin@demo.com",
  password: "password",
  name: "Admin User"
)

# 멤버십 생성
OrganizationMembership.create!(
  user: admin_user,
  organization: demo_org,
  role: "owner"
)

# 테넌트 스키마 생성 및 시드 데이터
Apartment::Tenant.switch('demo') do
  # 서비스 생성
  service = Service.create!(
    name: "Main Application",
    prefix: "MAIN"
  )

  # 스프린트 생성
  sprint = Sprint.create!(
    service: service,
    name: "Sprint 1",
    start_date: Date.current,
    end_date: 2.weeks.from_now
  )

  # 샘플 태스크
  Task.create!([
    {
      task_id: "MAIN-1",
      title: "Setup authentication system",
      status: "in_progress",
      service: service,
      sprint: sprint,
      assigned_user_id: admin_user.id
    },
    {
      task_id: "MAIN-2",
      title: "Create dashboard UI",
      status: "todo",
      dependencies: ["MAIN-1"],
      service: service,
      sprint: sprint
    }
  ])
end
```

---

## 📊 모니터링 및 관리

### 1. 테넌트 관리 대시보드

```ruby
# app/controllers/admin/tenants_controller.rb
class Admin::TenantsController < ApplicationController
  before_action :ensure_super_admin

  def index
    @organizations = Organization.includes(:users, :organization_memberships)
  end

  def show
    @organization = Organization.find(params[:id])

    # 테넌트별 통계
    Apartment::Tenant.switch(@organization.subdomain) do
      @stats = {
        tasks_count: Task.count,
        active_sprints: Sprint.active.count,
        services_count: Service.count
      }
    end
  end

  def create_schema
    organization = Organization.find(params[:id])
    Apartment::Tenant.create(organization.subdomain)
    redirect_back(fallback_location: admin_tenants_path)
  end

  def drop_schema
    organization = Organization.find(params[:id])
    Apartment::Tenant.drop(organization.subdomain)
    redirect_back(fallback_location: admin_tenants_path)
  end
end
```

### 2. 테넌트별 사용량 추적

```ruby
# app/models/usage_tracking.rb
class UsageTracking
  def self.track_tenant_activity(organization)
    Apartment::Tenant.switch(organization.subdomain) do
      {
        tasks_created_today: Task.where(created_at: Date.current.all_day).count,
        active_users_today: Task.where(updated_at: Date.current.all_day).distinct.count(:assigned_user_id),
        total_tasks: Task.count,
        storage_usage: calculate_storage_usage
      }
    end
  end

  private

  def self.calculate_storage_usage
    # 파일 업로드, 로그 등의 용량 계산
  end
end
```

---

## 🔐 보안 고려사항

### 1. 테넌트 격리 보안

```ruby
# app/controllers/concerns/tenant_security.rb
module TenantSecurity
  extend ActiveSupport::Concern

  included do
    before_action :verify_tenant_access
    after_action :clear_tenant_data
  end

  private

  def verify_tenant_access
    # SQL Injection 방지를 위한 서브도메인 검증
    subdomain = request.subdomain
    unless subdomain.match?(/\A[a-z0-9\-]{1,63}\z/)
      raise ActionController::BadRequest, "Invalid subdomain"
    end

    # 존재하지 않는 테넌트 접근 차단
    unless Organization.exists?(subdomain: subdomain)
      raise ActionController::RoutingError, "Tenant not found"
    end
  end

  def clear_tenant_data
    # 요청 종료 후 메모리 정리
    Apartment::Tenant.reset
  end
end
```

### 2. 크로스 테넌트 데이터 접근 방지

```ruby
# config/initializers/apartment_security.rb
# 개발환경에서 크로스 테넌트 접근 감지
if Rails.env.development?
  module Apartment
    module Adapters
      class AbstractAdapter
        alias_method :original_switch, :switch

        def switch(tenant = nil)
          Rails.logger.info "[APARTMENT] Switching to tenant: #{tenant}"
          original_switch(tenant)
        end
      end
    end
  end
end
```

---

이 전략을 통해 완전히 격리된 멀티테넌트 환경에서 중앙 집중식 SSO 인증을 구현할 수 있으며, 각 조직은 독립적인 데이터와 워크스페이스를 가지면서도 사용자는 하나의 계정으로 모든 조직에 접근할 수 있습니다.
