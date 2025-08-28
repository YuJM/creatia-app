# frozen_string_literal: true

# 멀티테넌트 Creatia 시드 데이터
# 이 파일은 개발 및 테스트 환경에서 사용할 수 있는 샘플 데이터를 생성합니다.

puts "\n🌱 Creatia 멀티테넌트 시드 데이터 생성 중..."
puts "=" * 60

# ============================================================================
# 1. 사용자 생성
# ============================================================================
puts "\n👥 사용자 생성 중..."

users = [
  {
    email: "admin@creatia.local",
    password: "password123",
    name: "관리자",
    role: "admin",
    username: "admin"
  },
  {
    email: "john@creatia.local", 
    password: "password123",
    name: "John Doe",
    role: "user",
    username: "johndoe"
  },
  {
    email: "jane@creatia.local",
    password: "password123", 
    name: "Jane Smith",
    role: "user",
    username: "janesmith"
  },
  {
    email: "mike@creatia.local",
    password: "password123",
    name: "Mike Johnson", 
    role: "user",
    username: "mikejohnson"
  },
  {
    email: "sarah@creatia.local",
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
    owner_email: "admin@creatia.local"
  },
  {
    name: "Acme Corporation",
    subdomain: "acme",
    description: "Acme Corporation의 프로젝트 관리 워크스페이스",
    plan: "pro", 
    owner_email: "john@creatia.local"
  },
  {
    name: "Startup Inc",
    subdomain: "startup",
    description: "빠르게 성장하는 스타트업을 위한 협업 공간",
    plan: "team",
    owner_email: "jane@creatia.local"
  },
  {
    name: "Test Organization",
    subdomain: "test",
    description: "테스트용 조직",
    plan: "free",
    owner_email: "mike@creatia.local"
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
    next if user.email == "admin@creatia.local" # 이미 소유자로 설정됨
    
    role = case user.email
           when "john@creatia.local" then "admin"
           when "jane@creatia.local" then "admin" 
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
    { email: "jane@creatia.local", role: "admin" },
    { email: "mike@creatia.local", role: "member" },
    { email: "sarah@creatia.local", role: "member" }
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
  
  # 샘플 태스크 데이터
  tasks_data = [
    {
      title: "프로젝트 초기 설정",
      description: "새로운 프로젝트를 위한 기본 설정을 완료합니다.",
      status: "done",
      priority: "high",
      position: 1
    },
    {
      title: "사용자 인터페이스 디자인",
      description: "메인 페이지와 대시보드의 UI/UX 디자인을 완성합니다.",
      status: "in_progress", 
      priority: "high",
      position: 2,
      due_date: 1.week.from_now
    },
    {
      title: "백엔드 API 개발",
      description: "RESTful API 엔드포인트를 개발하고 테스트합니다.",
      status: "in_progress",
      priority: "urgent",
      position: 3,
      due_date: 5.days.from_now
    },
    {
      title: "데이터베이스 스키마 최적화",
      description: "성능 향상을 위한 데이터베이스 인덱스 및 쿼리 최적화",
      status: "todo",
      priority: "medium", 
      position: 4,
      due_date: 2.weeks.from_now
    },
    {
      title: "보안 검토 및 테스트",
      description: "애플리케이션 보안 취약점을 점검하고 보완합니다.",
      status: "todo",
      priority: "high",
      position: 5
    },
    {
      title: "문서화 작업",
      description: "API 문서 및 사용자 가이드를 작성합니다.",
      status: "todo", 
      priority: "low",
      position: 6
    },
    {
      title: "배포 환경 구축",
      description: "프로덕션 환경 설정 및 CI/CD 파이프라인 구축",
      status: "review",
      priority: "medium",
      position: 7
    }
  ]
  
  tasks_data.each_with_index do |task_data, index|
    # 랜덤하게 멤버에게 할당 (50% 확률)
    assigned_user = members.sample if rand < 0.5
    
    task = Task.find_or_create_by(
      title: task_data[:title],
      organization: organization
    ) do |t|
      t.description = task_data[:description]
      t.status = task_data[:status]
      t.priority = task_data[:priority] 
      t.position = task_data[:position]
      t.due_date = task_data[:due_date]
      t.assigned_user = assigned_user
    end
    
    if task.persisted?
      assigned_info = assigned_user ? " (→ #{assigned_user.name})" : " (미할당)"
      puts "    ✓ #{task.title}#{assigned_info}"
    else
      puts "    ✗ #{task_data[:title]} 생성 실패: #{task.errors.full_messages.join(', ')}"
    end
  end
  
  # acts_as_tenant 컨텍스트 초기화
  ActsAsTenant.current_tenant = nil
end

# ============================================================================
# 데모 데이터 로드 (옵션)
# ============================================================================
if ENV['LOAD_DEMO_DATA'] == 'true' || ENV['LOAD_ADVANCED_DEMO'] == 'true'
  puts "\n🚀 데모 데이터 로드 중..."
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
puts "  • 태스크: #{Task.count}개"

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
