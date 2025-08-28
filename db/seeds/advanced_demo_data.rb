# frozen_string_literal: true

# 고급 기능 데모 데이터 생성
# Sprint, Epic, Milestone, Dashboard 등의 기능을 테스트할 수 있는 데이터

puts "\n🚀 고급 기능 데모 데이터 생성 중..."
puts "=" * 60

# Demo 조직으로 설정
demo_org = Organization.find_by(subdomain: "demo")
unless demo_org
  puts "❌ Demo 조직을 찾을 수 없습니다. 기본 seed를 먼저 실행하세요."
  exit
end

ActsAsTenant.current_tenant = demo_org
puts "🏢 조직: #{demo_org.name}"

# ============================================================================
# 1. Services 생성
# ============================================================================
puts "\n📦 Services 생성 중..."

services = [
  {
    name: "E-Commerce Platform",
    key: "ecommerce",
    task_prefix: "ECOM",
    description: "온라인 쇼핑몰 플랫폼 개발 프로젝트"
  },
  {
    name: "Mobile App",
    key: "mobile",
    task_prefix: "MAPP",
    description: "모바일 애플리케이션 개발 프로젝트"
  },
  {
    name: "Admin Dashboard",
    key: "admin",
    task_prefix: "ADMIN",
    description: "관리자 대시보드 개발 프로젝트"
  }
]

created_services = []
services.each do |service_data|
  service = Service.find_or_create_by(
    key: service_data[:key],
    organization: demo_org
  ) do |s|
    s.name = service_data[:name]
    s.task_prefix = service_data[:task_prefix]
    s.description = service_data[:description]
  end
  
  if service.persisted?
    created_services << service
    puts "  ✓ #{service.name} (#{service.task_prefix})"
  end
end

# ============================================================================
# 2. Milestones 생성
# ============================================================================
puts "\n🎯 Milestones 생성 중..."

ecom_service = created_services.find { |s| s.task_prefix == "ECOM" }
if ecom_service
  milestones = [
    {
      title: "Beta Release",
      description: "베타 버전 출시 - 핵심 기능 구현 완료",
      target_date: 2.months.from_now,
      status: "in_progress",
      progress: 35
    },
    {
      title: "Production Launch",
      description: "정식 서비스 런칭 - 모든 기능 구현 및 안정화",
      target_date: 4.months.from_now,
      status: "planned",
      progress: 0
    },
    {
      title: "MVP Complete",
      description: "최소 기능 제품 완성",
      target_date: 2.weeks.ago,
      status: "completed",
      progress: 100
    }
  ]
  
  milestones.each do |milestone_data|
    milestone = Milestone.find_or_create_by(
      title: milestone_data[:title],
      service: ecom_service
    ) do |m|
      m.description = milestone_data[:description]
      m.target_date = milestone_data[:target_date]
      m.status = milestone_data[:status]
      m.progress = milestone_data[:progress]
      m.organization = demo_org
    end
    
    puts "  ✓ #{milestone.title} (#{milestone.status})"
  end
end

# ============================================================================
# 3. Epic Labels 생성
# ============================================================================
puts "\n🏷️ Epic Labels 생성 중..."

epic_labels = [
  {
    name: "User Authentication",
    color: "#3b82f6",
    description: "사용자 인증 및 권한 관리 시스템",
    is_epic: true
  },
  {
    name: "Shopping Cart",
    color: "#10b981",
    description: "장바구니 및 결제 시스템",
    is_epic: true
  },
  {
    name: "Product Catalog",
    color: "#f59e0b",
    description: "상품 카탈로그 및 검색 시스템",
    is_epic: true
  },
  {
    name: "Order Management",
    color: "#8b5cf6",
    description: "주문 관리 및 배송 추적 시스템",
    is_epic: true
  },
  {
    name: "Analytics Dashboard",
    color: "#ef4444",
    description: "분석 대시보드 및 리포팅",
    is_epic: true
  }
]

created_epic_labels = []
epic_labels.each do |label_data|
  label = Label.find_or_create_by(
    name: label_data[:name],
    organization: demo_org
  ) do |l|
    l.color = label_data[:color]
    l.description = label_data[:description]
    l.is_epic = label_data[:is_epic]
  end
  
  if label.persisted?
    created_epic_labels << label
    puts "  ✓ #{label.name}"
  end
end

# 일반 라벨도 추가
regular_labels = [
  { name: "bug", color: "#ef4444", description: "버그 수정" },
  { name: "enhancement", color: "#10b981", description: "기능 개선" },
  { name: "documentation", color: "#64748b", description: "문서화" },
  { name: "urgent", color: "#dc2626", description: "긴급" },
  { name: "frontend", color: "#06b6d4", description: "프론트엔드" },
  { name: "backend", color: "#7c3aed", description: "백엔드" }
]

regular_labels.each do |label_data|
  Label.find_or_create_by(
    name: label_data[:name],
    organization: demo_org
  ) do |l|
    l.color = label_data[:color]
    l.description = label_data[:description]
    l.is_epic = false
  end
end

# ============================================================================
# 4. Sprints 생성
# ============================================================================
puts "\n⏱️ Sprints 생성 중..."

current_sprint = Sprint.find_or_create_by(
  name: "Sprint 23",
  organization: demo_org
) do |s|
  s.goal = "사용자 인증 시스템 완성 및 장바구니 기능 개발"
  s.start_date = 1.week.ago
  s.end_date = 1.week.from_now
  s.status = "active"
  s.capacity = 120
  s.velocity_target = 35
end
puts "  ✓ #{current_sprint.name} (현재 스프린트)"

previous_sprint = Sprint.find_or_create_by(
  name: "Sprint 22",
  organization: demo_org
) do |s|
  s.goal = "제품 카탈로그 UI 개발"
  s.start_date = 3.weeks.ago
  s.end_date = 1.week.ago
  s.status = "completed"
  s.capacity = 100
  s.velocity_target = 30
  s.actual_velocity = 28
end
puts "  ✓ #{previous_sprint.name} (완료)"

upcoming_sprint = Sprint.find_or_create_by(
  name: "Sprint 24",
  organization: demo_org
) do |s|
  s.goal = "결제 시스템 통합 및 주문 관리"
  s.start_date = 1.week.from_now
  s.end_date = 3.weeks.from_now
  s.status = "planned"
  s.capacity = 110
  s.velocity_target = 32
end
puts "  ✓ #{upcoming_sprint.name} (예정)"

# ============================================================================
# 5. Tasks with Epic Labels 생성
# ============================================================================
puts "\n📋 Epic이 포함된 Tasks 생성 중..."

members = demo_org.users.to_a

# 현재 스프린트의 태스크들
current_sprint_tasks = [
  {
    title: "JWT 토큰 인증 구현",
    epic: "User Authentication",
    status: "done",
    priority: "high",
    story_points: 5,
    assignee: members[0]
  },
  {
    title: "소셜 로그인 통합 (Google, GitHub)",
    epic: "User Authentication",
    status: "in_progress",
    priority: "high",
    story_points: 8,
    assignee: members[1]
  },
  {
    title: "장바구니 추가/삭제 API",
    epic: "Shopping Cart",
    status: "in_progress",
    priority: "urgent",
    story_points: 5,
    assignee: members[2]
  },
  {
    title: "장바구니 UI 컴포넌트",
    epic: "Shopping Cart",
    status: "todo",
    priority: "high",
    story_points: 3,
    assignee: members[1]
  },
  {
    title: "장바구니 수량 업데이트 기능",
    epic: "Shopping Cart",
    status: "todo",
    priority: "medium",
    story_points: 3,
    assignee: nil
  },
  {
    title: "비밀번호 재설정 플로우",
    epic: "User Authentication",
    status: "review",
    priority: "medium",
    story_points: 5,
    assignee: members[3]
  },
  {
    title: "장바구니 로컬 스토리지 동기화",
    epic: "Shopping Cart",
    status: "blocked",
    priority: "low",
    story_points: 2,
    assignee: members[2]
  }
]

current_sprint_tasks.each_with_index do |task_data, index|
  epic_label = created_epic_labels.find { |l| l.name == task_data[:epic] }
  
  task = Task.find_or_create_by(
    title: task_data[:title],
    organization: demo_org
  ) do |t|
    t.description = "#{task_data[:epic]} 에픽의 일부로 구현되는 기능입니다."
    t.status = task_data[:status]
    t.priority = task_data[:priority]
    t.story_points = task_data[:story_points]
    t.assigned_user = task_data[:assignee]
    t.sprint = current_sprint
    t.position = index + 1
    t.due_date = current_sprint.end_date if ["urgent", "high"].include?(task_data[:priority])
  end
  
  # Epic 라벨 연결
  if epic_label && task.persisted?
    TaskLabel.find_or_create_by(task: task, label: epic_label)
  end
  
  # 추가 라벨
  if task.status == "blocked"
    blocked_label = Label.find_by(name: "bug", organization: demo_org)
    TaskLabel.find_or_create_by(task: task, label: blocked_label) if blocked_label
  end
  
  puts "  ✓ #{task.title} (#{task.status})"
end

# ============================================================================
# 6. Comments 생성
# ============================================================================
puts "\n💬 Comments 생성 중..."

tasks_with_comments = Task.where(organization: demo_org).limit(5)
tasks_with_comments.each do |task|
  rand(1..3).times do |i|
    comment = Comment.find_or_create_by(
      task: task,
      user: members.sample,
      content: [
        "이 작업에 대한 진행 상황을 공유합니다.",
        "코드 리뷰 완료했습니다. LGTM! 👍",
        "테스트 중 이슈를 발견했습니다. 확인 부탁드립니다.",
        "문서 업데이트가 필요할 것 같습니다.",
        "성능 최적화를 고려해보면 좋을 것 같아요."
      ].sample
    )
  end
end
puts "  ✓ #{Comment.count}개의 댓글 생성"

# ============================================================================
# 7. Task Dependencies 생성
# ============================================================================
puts "\n🔗 Task Dependencies 생성 중..."

auth_tasks = Task.joins(:labels).where(labels: { name: "User Authentication" })
cart_tasks = Task.joins(:labels).where(labels: { name: "Shopping Cart" })

if auth_tasks.any? && cart_tasks.any?
  # 인증이 장바구니보다 먼저 완료되어야 함
  dependency = TaskDependency.find_or_create_by(
    predecessor: auth_tasks.first,
    successor: cart_tasks.first
  ) do |d|
    d.dependency_type = "finish_to_start"
    d.lag_time = 0
  end
  
  puts "  ✓ 의존성 생성: 인증 → 장바구니"
end

# ============================================================================
# 8. Dashboard Customization 생성
# ============================================================================
puts "\n🎨 Dashboard Customization 생성 중..."

demo_users = demo_org.users.limit(3)
demo_users.each do |user|
  dashboard = DashboardCustomization.find_or_create_by(user: user) do |d|
    d.layout = ["default", "three_column", "dashboard"].sample
    d.preferences = {
      theme: ["light", "dark"].sample,
      density: "comfortable",
      auto_refresh: true,
      refresh_interval: 30000,
      notifications: {
        email: true,
        browser: true,
        sound: false
      }
    }
    d.widget_configurations = {
      "metrics" => { 
        position: { row: 0, col: 0, width: 2, height: 1 }, 
        enabled: true,
        settings: { show_velocity: true, show_completion_rate: true }
      },
      "sprint_progress" => { 
        position: { row: 0, col: 2, width: 2, height: 1 }, 
        enabled: true,
        settings: { show_burndown: true }
      },
      "tasks_summary" => { 
        position: { row: 1, col: 0, width: 1, height: 1 }, 
        enabled: true,
        settings: { max_items: 10 }
      },
      "recent_activity" => { 
        position: { row: 1, col: 1, width: 1, height: 2 }, 
        enabled: true 
      },
      "team_workload" => { 
        position: { row: 1, col: 2, width: 2, height: 1 }, 
        enabled: true 
      }
    }
    d.theme_settings = {
      primary_color: "#3b82f6",
      secondary_color: "#64748b",
      accent_color: "#10b981"
    }
  end
  
  puts "  ✓ #{user.name}의 대시보드 커스터마이징"
end

# ============================================================================
# 9. Sprint Metrics 데이터 생성
# ============================================================================
puts "\n📊 Sprint Metrics 생성 중..."

# 현재 스프린트의 번다운 데이터
days_in_sprint = (current_sprint.end_date - current_sprint.start_date).to_i
current_day = (Date.today - current_sprint.start_date).to_i

burndown_data = {
  sprint_id: current_sprint.id,
  dates: (0..days_in_sprint).map { |d| (current_sprint.start_date + d.days).strftime("%m/%d") },
  ideal: (0..days_in_sprint).map { |d| current_sprint.velocity_target * (1 - d.to_f / days_in_sprint) },
  actual: (0..current_day).map { |d| current_sprint.velocity_target * (1 - (d.to_f * 0.8 / days_in_sprint)) }
}

# Rails 캐시에 메트릭 데이터 저장 (데모용)
Rails.cache.write("sprint_burndown_#{current_sprint.id}", burndown_data, expires_in: 1.hour)
puts "  ✓ Sprint #{current_sprint.name} 번다운 데이터"

# 팀 성능 메트릭
team_metrics = {
  velocity_trend: [25, 28, 30, 28, 32, 35],
  completion_rate: 87.5,
  average_cycle_time: 3.2,
  team_health_score: 8.5,
  capacity_utilization: 85
}

Rails.cache.write("team_performance_metrics", team_metrics, expires_in: 1.hour)
puts "  ✓ 팀 성능 메트릭 데이터"

# ============================================================================
# 10. Activity Logs 생성
# ============================================================================
puts "\n📝 Activity Logs 생성 중..."

recent_activities = []
activities = [
  { type: "task_created", message: "새 태스크가 생성되었습니다" },
  { type: "task_completed", message: "태스크를 완료했습니다" },
  { type: "comment_added", message: "댓글을 추가했습니다" },
  { type: "sprint_started", message: "스프린트가 시작되었습니다" },
  { type: "milestone_updated", message: "마일스톤이 업데이트되었습니다" }
]

10.times do |i|
  activity = activities.sample
  recent_activities << {
    type: activity[:type],
    message: activity[:message],
    user: members.sample.name,
    timestamp: i.hours.ago,
    metadata: {
      task_id: Task.pluck(:id).sample,
      sprint_id: current_sprint.id
    }
  }
end

Rails.cache.write("recent_activities_#{demo_org.id}", recent_activities, expires_in: 1.hour)
puts "  ✓ #{recent_activities.count}개의 활동 로그"

# ============================================================================
# 완료 및 요약
# ============================================================================

# Tenant 컨텍스트 정리
ActsAsTenant.current_tenant = nil

puts "\n" + "=" * 60
puts "✅ 고급 기능 데모 데이터 생성 완료!"
puts "=" * 60

puts "\n📊 생성된 고급 데이터 요약:"
puts "  • Services: #{Service.count}개"
puts "  • Milestones: #{Milestone.count}개"
puts "  • Epic Labels: #{Label.where(is_epic: true).count}개"
puts "  • Sprints: #{Sprint.count}개"
puts "  • Tasks with Epics: #{Task.joins(:labels).distinct.count}개"
puts "  • Comments: #{Comment.count}개"
puts "  • Dashboard Customizations: #{DashboardCustomization.count}개"

puts "\n🎯 테스트 가능한 기능들:"
puts "  1. Sprint Dashboard: 번다운 차트, 속도 트렌드"
puts "  2. Epic Management: Epic별 진행률, 태스크 그룹핑"
puts "  3. Roadmap View: 타임라인, Gantt 차트"
puts "  4. Dashboard Customization: 위젯 드래그&드롭, 테마 설정"
puts "  5. Team Performance: 팀 메트릭, 용량 관리"
puts "  6. Task Dependencies: 의존성 그래프, 임계 경로"

puts "\n💡 접속 후 확인 방법:"
puts "  1. demo.creatia.local로 접속"
puts "  2. admin@creatia.local / password123 로그인"
puts "  3. Dashboard에서 실시간 메트릭 확인"
puts "  4. Sprints 메뉴에서 현재 스프린트 상태 확인"
puts "  5. Roadmap에서 프로젝트 타임라인 확인"
puts "  6. Settings에서 대시보드 커스터마이징"

puts "\n" + "=" * 60