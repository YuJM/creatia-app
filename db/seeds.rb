# frozen_string_literal: true

# 멀티테넌트 Creatia 시드 데이터
# 이 파일은 개발 및 테스트 환경에서 사용할 수 있는 샘플 데이터를 생성합니다.

# BASE_DOMAIN 환경변수 사용 (기본값: creatia.local)
base_domain = ENV.fetch('BASE_DOMAIN', 'creatia.local')

puts "\n🌱 Creatia 멀티테넌트 시드 데이터 생성 중..."
puts "=" * 60

# ============================================================================
# 1. 사용자 생성
# ============================================================================
puts "\n👥 사용자 생성 중..."

users = [
  {
    email: "admin@#{base_domain}",
    password: "password123",
    name: "관리자",
    role: "admin",
    username: "admin"
  },
  {
    email: "john@#{base_domain}", 
    password: "password123",
    name: "John Doe",
    role: "user",
    username: "johndoe"
  },
  {
    email: "jane@#{base_domain}",
    password: "password123", 
    name: "Jane Smith",
    role: "user",
    username: "janesmith"
  },
  {
    email: "mike@#{base_domain}",
    password: "password123",
    name: "Mike Johnson", 
    role: "user",
    username: "mikejohnson"
  },
  {
    email: "sarah@#{base_domain}",
    password: "password123",
    name: "Sarah Wilson",
    role: "user", 
    username: "sarahwilson"
  }
]

created_users = []
users.each do |user_attrs|
  user = User.find_or_create_by(email: user_attrs[:email]) do |u|
    u.password = user_attrs[:password]
    u.password_confirmation = user_attrs[:password]
    u.name = user_attrs[:name]
    u.role = user_attrs[:role]
    u.username = user_attrs[:username]
  end
  
  if user.persisted?
    created_users << user
    puts "  ✓ #{user.name} (#{user.email})"
  else
    puts "  ✗ #{user_attrs[:email]} 생성 실패: #{user.errors.full_messages.join(', ')}"
  end
end

# ============================================================================
# 2. 조직 생성
# ============================================================================
puts "\n🏢 조직 생성 중..."

organizations_data = [
  {
    name: "Creatia Demo",
    subdomain: "demo", 
    description: "데모용 조직입니다. 멀티테넌트 시스템을 체험해보세요.",
    plan: "team",
    owner_email: "admin@#{base_domain}"
  },
  {
    name: "Acme Corporation",
    subdomain: "acme",
    description: "Acme Corporation의 프로젝트 관리 워크스페이스",
    plan: "pro", 
    owner_email: "john@#{base_domain}"
  },
  {
    name: "Startup Inc",
    subdomain: "startup",
    description: "빠르게 성장하는 스타트업을 위한 협업 공간",
    plan: "team",
    owner_email: "jane@#{base_domain}"
  },
  {
    name: "Test Organization",
    subdomain: "test",
    description: "테스트용 조직",
    plan: "free",
    owner_email: "mike@#{base_domain}"
  }
]

created_organizations = []
organizations_data.each do |org_data|
  owner = created_users.find { |u| u.email == org_data[:owner_email] }
  next unless owner
  
  organization = Organization.find_or_create_by(subdomain: org_data[:subdomain]) do |org|
    org.name = org_data[:name]
    org.description = org_data[:description] 
    org.plan = org_data[:plan]
    org.active = true
  end
  
  if organization.persisted?
    created_organizations << organization
    puts "  ✓ #{organization.name} (#{organization.subdomain})"
    
    # 소유자 멤버십 생성
    membership = OrganizationMembership.find_or_create_by(
      user: owner,
      organization: organization
    ) do |m|
      m.role = 'owner'
      m.active = true
    end
    
    puts "    → #{owner.name}을(를) 소유자로 설정"
  else
    puts "  ✗ #{org_data[:name]} 생성 실패: #{organization.errors.full_messages.join(', ')}"
  end
end

# ============================================================================
# 3. 조직 멤버십 생성 (추가 멤버들)
# ============================================================================
puts "\n👨‍👩‍👧‍👦 조직 멤버십 생성 중..."

# Demo 조직에 모든 사용자 추가
demo_org = created_organizations.find { |org| org.subdomain == "demo" }
if demo_org
  created_users.each do |user|
    next if user.email == "admin@#{base_domain}" # 이미 소유자로 설정됨
    
    role = case user.email
           when "john@#{base_domain}" then "admin"
           when "jane@#{base_domain}" then "admin" 
           else "member"
           end
    
    membership = OrganizationMembership.find_or_create_by(
      user: user,
      organization: demo_org
    ) do |m|
      m.role = role
      m.active = true
    end
    
    puts "  ✓ #{user.name} → Demo (#{role})"
  end
end

# Acme 조직에 일부 멤버 추가
acme_org = created_organizations.find { |org| org.subdomain == "acme" }
if acme_org
  [
    { email: "jane@#{base_domain}", role: "admin" },
    { email: "mike@#{base_domain}", role: "member" },
    { email: "sarah@#{base_domain}", role: "member" }
  ].each do |member_data|
    user = created_users.find { |u| u.email == member_data[:email] }
    next unless user
    
    membership = OrganizationMembership.find_or_create_by(
      user: user,
      organization: acme_org
    ) do |m|
      m.role = member_data[:role]
      m.active = true
    end
    
    puts "  ✓ #{user.name} → Acme (#{member_data[:role]})"
  end
end

# ============================================================================
# 4. 태스크 생성 (각 조직별)
# ============================================================================
puts "\n📋 태스크 생성 중..."

created_organizations.each do |organization|
  puts "\n  #{organization.name} 조직의 태스크:"
  
  # acts_as_tenant 컨텍스트 설정
  ActsAsTenant.current_tenant = organization
  
  # 조직 멤버들 가져오기
  members = organization.users.includes(:organization_memberships)
  
  # PostgreSQL Task는 더 이상 사용하지 않음
  # MongoDB Task는 mongodb_seeds.rb에서 생성됨
  puts "    PostgreSQL Task 생성 건너뜀 (MongoDB로 이전됨)"
  
  # acts_as_tenant 컨텍스트 초기화
  ActsAsTenant.current_tenant = nil
end

# ============================================================================
# MongoDB 실행 데이터 생성
# ============================================================================
puts "\n🏗️ MongoDB 실행 데이터 생성..."
require_relative 'seeds/mongodb_seeds'

# ============================================================================
# Demo 조직 전용 데이터 생성 (Faker 사용)
# ============================================================================
puts "\n🎯 Demo 조직 전용 데이터 생성..."
# 기본 버전 또는 Faker 버전 선택
if ENV['USE_FAKER'] == 'false'
  require_relative 'seeds/demo_organization_seeds'
else
  require_relative 'seeds/demo_organization_seeds_with_faker'
end

# ============================================================================
# 데모 데이터 로드 (옵션)
# ============================================================================
if ENV['LOAD_DEMO_DATA'] == 'true' || ENV['LOAD_ADVANCED_DEMO'] == 'true'
  puts "\n🚀 추가 데모 데이터 로드 중..."
  require_relative 'seeds/basic_demo_data'
end

# ============================================================================
# 완료 메시지 및 사용 안내
# ============================================================================
puts "\n" + "=" * 60
puts "✅ 시드 데이터 생성 완료!"
puts "=" * 60

puts "\n📊 생성된 데이터 요약:"
puts "  • 사용자: #{created_users.count}명"
puts "  • 조직: #{created_organizations.count}개"
puts "  • 멤버십: #{OrganizationMembership.count}개"
puts "  • PostgreSQL 태스크: 0개 (MongoDB로 이전됨)"

puts "\n🔗 접속 정보:"
puts "  기본 도메인: #{DomainService.base_domain}"

puts "\n  👤 테스트 계정:"
created_users.each do |user|
  puts "    #{user.email} / password123 (#{user.role})"
end

puts "\n  🏢 테스트 조직:"
created_organizations.each do |org|
  owner = org.owner
  url = DomainService.organization_url(org.subdomain)
  puts "    #{org.name}: #{url}"
  puts "      → 소유자: #{owner&.name || '없음'}"
  puts "      → 멤버: #{org.users.count}명"
end

puts "\n🔧 개발환경 설정:"
puts "  다음 도메인들을 /etc/hosts에 추가하세요:"
puts "  127.0.0.1 #{DomainService.base_domain}"
puts "  127.0.0.1 auth.#{DomainService.base_domain}"
created_organizations.each do |org|
  puts "  127.0.0.1 #{org.subdomain}.#{DomainService.base_domain}"
end

puts "\n💡 사용 예시:"
puts "  1. 메인 페이지: #{DomainService.main_url}"
puts "  2. 로그인: #{DomainService.auth_url('login')}"
puts "  3. Demo 조직: #{DomainService.organization_url('demo')}"
puts "  4. API: #{DomainService.api_url('v1')}"

puts "\n" + "=" * 60
puts "🚀 Happy coding with Creatia!"
puts "=" * 60
