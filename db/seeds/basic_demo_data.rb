# frozen_string_literal: true

# 기본 데모 데이터 - 현재 존재하는 모델만 사용
# Sprint, Service, Task 관련 기능을 테스트할 수 있는 데이터

puts "\n🚀 기본 데모 데이터 생성 중..."
puts "=" * 60

# Demo 조직 찾기
demo_org = Organization.find_by(subdomain: "demo")
unless demo_org
  puts "❌ Demo 조직을 찾을 수 없습니다. 기본 seed를 먼저 실행하세요."
  exit
end

ActsAsTenant.current_tenant = demo_org
puts "🏢 조직: #{demo_org.name}"

# ============================================================================
# 1. Services 생성 (Task ID 접두사용)
# ============================================================================
puts "\n📦 Services 생성 중..."

services = [
  {
    name: "E-Commerce Platform",
    key: "ECOMMERCE",
    task_prefix: "ECOM",
    description: "온라인 쇼핑몰 플랫폼 - 제품 카탈로그, 장바구니, 결제 시스템"
  },
  {
    name: "Mobile App",
    key: "MOBILE",
    task_prefix: "MOB",
    description: "iOS/Android 모바일 애플리케이션 - 반응형 UI, 오프라인 동기화"
  },
  {
    name: "Admin Dashboard",
    key: "ADMIN",
    task_prefix: "ADM",
    description: "관리자 대시보드 - 통계, 리포트, 시스템 관리"
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
    puts "  ✓ #{service.name} (#{service.task_prefix}-XXX)"
  else
    puts "  ✗ #{service_data[:name]} 생성 실패: #{service.errors.full_messages.join(', ')}"
  end
end

if created_services.empty?
  puts "  ⚠️  Service 생성 실패. 기존 Service 확인 중..."
  created_services = Service.where(organization: demo_org).to_a
  created_services.each do |s|
    puts "  → 기존: #{s.name} (#{s.task_prefix})"
  end
end

# ============================================================================
# 2. Sprints 생성 - 번다운 차트와 속도 추적용
# ============================================================================
puts "\n⏱️ Sprints 생성 중..."

# 과거 스프린트들 (속도 트렌드 데이터용)
past_sprints = [
  {
    name: "Sprint 20",
    goal: "초기 프로토타입 구축",
    start_date: 7.weeks.ago,
    end_date: 5.weeks.ago,
    status: "completed",
    capacity: 80,
    velocity_target: 20,
    actual_velocity: 18
  },
  {
    name: "Sprint 21",
    goal: "사용자 인증 시스템 구현",
    start_date: 5.weeks.ago,
    end_date: 3.weeks.ago,
    status: "completed",
    capacity: 100,
    velocity_target: 25,
    actual_velocity: 28
  },
  {
    name: "Sprint 22",
    goal: "제품 카탈로그 UI 개발",
    start_date: 3.weeks.ago,
    end_date: 1.week.ago,
    status: "completed",
    capacity: 100,
    velocity_target: 30,
    actual_velocity: 32
  }
]

ecom_service = created_services.first  # E-Commerce 서비스 사용

if ecom_service.nil?
  puts "  ⚠️  Service가 없습니다. 기본 Service 생성 중..."
  ecom_service = Service.create!(
    name: "Default Service",
    key: "DEFAULT",
    task_prefix: "TASK",
    description: "기본 서비스",
    organization: demo_org
  )
  created_services << ecom_service
end

past_sprints.each do |sprint_data|
  sprint = Sprint.find_or_create_by(
    name: sprint_data[:name],
    service: ecom_service
  ) do |s|
    s.goal = sprint_data[:goal]
    s.start_date = sprint_data[:start_date]
    s.end_date = sprint_data[:end_date]
    s.status = sprint_data[:status]
    # capacity, velocity_target, actual_velocity는 Sprint 모델에 없음
  end
  puts "  ✓ #{sprint.name} (#{sprint_data[:status]})"
end

# 현재 스프린트
current_sprint = Sprint.find_or_create_by(
  name: "Sprint 23",
  service: ecom_service
) do |s|
  s.goal = "장바구니 기능 완성 및 결제 시스템 통합"
  s.start_date = 1.week.ago
  s.end_date = 1.week.from_now
  s.status = "active"
end
puts "  ✓ #{current_sprint.name} (현재 진행 중: #{(Date.today - current_sprint.start_date).to_i}/14일)"

# 예정된 스프린트
upcoming_sprint = Sprint.find_or_create_by(
  name: "Sprint 24",
  service: ecom_service
) do |s|
  s.goal = "주문 관리 시스템 및 배송 추적"
  s.start_date = 1.week.from_now
  s.end_date = 3.weeks.from_now
  s.status = "planning"
end
puts "  ✓ #{upcoming_sprint.name} (예정: #{upcoming_sprint.start_date.strftime('%m/%d')} 시작)"

# ============================================================================
# 3. Tasks 생성 - 다양한 상태와 우선순위로
# ============================================================================
puts "\n📋 현재 스프린트 Tasks 생성 중..."

members = demo_org.users.to_a
ecom_service = created_services.find { |s| s.task_prefix == "ECOM" }

# 현재 스프린트의 태스크들 (번다운 차트용)
current_tasks = [
  # 완료된 태스크들
  {
    title: "장바구니 데이터 모델 설계",
    description: "장바구니 아이템, 세션 관리, 영속성을 위한 DB 스키마",
    status: "done",
    priority: "high",
    story_points: 3,
    assignee: members[0],
    completed_at: 3.days.ago
  },
  {
    title: "장바구니 추가 API 구현",
    description: "제품을 장바구니에 추가하는 RESTful API 엔드포인트",
    status: "done",
    priority: "high",
    story_points: 5,
    assignee: members[1],
    completed_at: 2.days.ago
  },
  {
    title: "장바구니 아이템 검증 로직",
    description: "재고 확인, 가격 검증, 수량 제한 체크",
    status: "done",
    priority: "urgent",
    story_points: 3,
    assignee: members[2],
    completed_at: 1.day.ago
  },
  # 진행 중인 태스크들
  {
    title: "장바구니 UI 컴포넌트 개발",
    description: "React 컴포넌트: 아이템 목록, 수량 조절, 삭제 기능",
    status: "in_progress",
    priority: "urgent",
    story_points: 8,
    assignee: members[1],
    due_date: 2.days.from_now
  },
  {
    title: "결제 게이트웨이 통합",
    description: "Stripe API 연동 및 결제 프로세스 구현",
    status: "in_progress",
    priority: "high",
    story_points: 13,
    assignee: members[0],
    due_date: 4.days.from_now
  },
  # 리뷰 중인 태스크
  {
    title: "장바구니 수량 업데이트 API",
    description: "장바구니 내 제품 수량 변경 엔드포인트",
    status: "review",
    priority: "medium",
    story_points: 3,
    assignee: members[3]
  },
  # 차단된 태스크
  {
    title: "장바구니 할인 쿠폰 적용",
    description: "프로모션 코드 및 할인 로직 구현 - 쿠폰 시스템 대기 중",
    status: "blocked",
    priority: "medium",
    story_points: 5,
    assignee: members[2],
    blocked_reason: "쿠폰 관리 시스템이 아직 구현되지 않음"
  },
  # 대기 중인 태스크들
  {
    title: "장바구니 저장 및 복원",
    description: "로그인 사용자의 장바구니 영속성 관리",
    status: "todo",
    priority: "medium",
    story_points: 5,
    assignee: nil
  },
  {
    title: "장바구니 분석 이벤트 추가",
    description: "Google Analytics 이벤트 트래킹",
    status: "todo",
    priority: "low",
    story_points: 2,
    assignee: nil
  },
  {
    title: "장바구니 성능 최적화",
    description: "대량 아이템 처리 시 성능 개선",
    status: "todo",
    priority: "low",
    story_points: 3,
    assignee: nil
  }
]

task_counter = 142  # ECOM-142부터 시작
current_tasks.each_with_index do |task_data, index|
  task_id = "#{ecom_service.task_prefix}-#{task_counter + index}"
  
  task = Task.find_or_create_by(
    title: task_data[:title],
    organization: demo_org,
    service: ecom_service
  ) do |t|
    t.description = task_data[:description]
    t.status = task_data[:status]
    t.priority = task_data[:priority]
    t.story_points = task_data[:story_points]
    t.assignee_id = task_data[:assignee]&.id
    t.sprint_id = current_sprint.id
    t.position = index + 1
    t.due_date = task_data[:due_date]
    t.completed_at = task_data[:completed_at] if task_data[:completed_at]
  end
  
  status_emoji = {
    "done" => "✅",
    "in_progress" => "🔄",
    "review" => "👀",
    "blocked" => "🚫",
    "todo" => "📝"
  }[task.status]
  
  assignee_info = task.assigned_user ? " → #{task.assigned_user.name}" : " (미할당)"
  puts "  #{status_emoji} #{task_id}: #{task.title}#{assignee_info}"
end

# ============================================================================
# 4. 팀 작업 데이터 생성 (팀 성능 메트릭용)
# ============================================================================
puts "\n👥 팀별 작업 분배..."

# 팀 생성 또는 찾기
teams = [
  { name: "Frontend Team", description: "UI/UX 개발팀" },
  { name: "Backend Team", description: "API 및 서버 개발팀" },
  { name: "DevOps Team", description: "인프라 및 배포 담당팀" }
]

created_teams = []
teams.each do |team_data|
  team = Team.find_or_create_by(
    name: team_data[:name],
    organization: demo_org
  ) do |t|
    t.description = team_data[:description]
  end
  created_teams << team if team.persisted?
  puts "  ✓ #{team.name}"
end

# 팀별 작업 할당 시뮬레이션 (캐시에 저장)
team_workload = {
  "Frontend Team" => {
    capacity: 40,
    allocated: 35,
    members: [members[1], members[3]].map(&:name),
    tasks_count: 8,
    velocity: 28
  },
  "Backend Team" => {
    capacity: 60,
    allocated: 52,
    members: [members[0], members[2]].map(&:name),
    tasks_count: 12,
    velocity: 35
  },
  "DevOps Team" => {
    capacity: 20,
    allocated: 15,
    members: [members[4]].compact.map(&:name),
    tasks_count: 3,
    velocity: 12
  }
}

Rails.cache.write("team_workload_#{demo_org.id}", team_workload, expires_in: 1.hour)

# ============================================================================
# 5. 대시보드용 메트릭 데이터 생성
# ============================================================================
puts "\n📊 대시보드 메트릭 데이터 생성 중..."

# 번다운 차트 데이터
sprint_days = (current_sprint.end_date - current_sprint.start_date).to_i
elapsed_days = (Date.today - current_sprint.start_date).to_i

burndown_data = {
  sprint_id: current_sprint.id,
  dates: (0..sprint_days).map { |d| (current_sprint.start_date + d.days).strftime("%m/%d") },
  ideal: (0..sprint_days).map { |d| 
    total_points = current_tasks.sum { |t| t[:story_points] }
    (total_points * (1 - d.to_f / sprint_days)).round(1)
  },
  actual: (0..elapsed_days).map { |d|
    total_points = current_tasks.sum { |t| t[:story_points] }
    completed_points = current_tasks.select { |t| t[:status] == "done" }.sum { |t| t[:story_points] }
    
    if d <= 3
      total_points - (completed_points * d / 3.0).round(1)
    else
      total_points - completed_points
    end
  }
}

Rails.cache.write("sprint_burndown_#{current_sprint.id}", burndown_data, expires_in: 1.hour)

# 속도 트렌드 데이터
velocity_data = {
  sprints: ["Sprint 20", "Sprint 21", "Sprint 22", "Sprint 23"],
  completed: [18, 28, 32, 11],  # 현재 스프린트는 진행 중
  average: Array.new(4, 27),  # 평균선
  target: [20, 25, 30, 35]
}

Rails.cache.write("velocity_trend_#{demo_org.id}", velocity_data, expires_in: 1.hour)

# 팀 성능 메트릭
team_metrics = {
  velocity_trend: [18, 28, 32, 11],
  completion_rate: 85.7,
  average_cycle_time: 2.8,
  team_health_score: 8.2,
  capacity_utilization: 87,
  sprint_progress: (11.0 / 35 * 100).round(1),
  blocked_tasks: 1,
  review_tasks: 1
}

Rails.cache.write("team_performance_metrics_#{demo_org.id}", team_metrics, expires_in: 1.hour)

# 최근 활동 로그
activities = []
[
  { hours_ago: 1, user: members[0], action: "completed", task: "ECOM-144" },
  { hours_ago: 2, user: members[1], action: "started", task: "ECOM-145" },
  { hours_ago: 3, user: members[2], action: "blocked", task: "ECOM-148" },
  { hours_ago: 5, user: members[3], action: "reviewed", task: "ECOM-147" },
  { hours_ago: 8, user: members[0], action: "commented", task: "ECOM-146" }
].each do |activity|
  activities << {
    type: "task_#{activity[:action]}",
    message: "#{activity[:user].name}님이 #{activity[:task]}을(를) #{
      case activity[:action]
      when "completed" then "완료했습니다"
      when "started" then "시작했습니다"
      when "blocked" then "차단 상태로 변경했습니다"
      when "reviewed" then "리뷰했습니다"
      when "commented" then "댓글을 달았습니다"
      end
    }",
    user: activity[:user].name,
    timestamp: activity[:hours_ago].hours.ago,
    task_id: activity[:task]
  }
end

Rails.cache.write("recent_activities_#{demo_org.id}", activities, expires_in: 1.hour)

puts "  ✓ 번다운 차트 데이터"
puts "  ✓ 속도 트렌드 데이터"
puts "  ✓ 팀 성능 메트릭"
puts "  ✓ 최근 활동 로그"

# ============================================================================
# 완료 및 요약
# ============================================================================

ActsAsTenant.current_tenant = nil

puts "\n" + "=" * 60
puts "✅ 기본 데모 데이터 생성 완료!"
puts "=" * 60

puts "\n📊 생성된 데이터 요약:"
puts "  • Services: #{Service.where(organization: demo_org).count}개"
puts "  • Sprints: #{Sprint.where(organization: demo_org).count}개 (과거 3개, 현재 1개, 예정 1개)"
puts "  • Tasks: #{Task.where(organization: demo_org, sprint: current_sprint).count}개 (현재 스프린트)"
puts "  • Teams: #{Team.where(organization: demo_org).count}개"

puts "\n🎯 테스트 가능한 기능들:"
puts "  1. Dashboard: 실시간 메트릭, 번다운 차트"
puts "  2. Sprint 관리: 진행 중인 스프린트 상태"
puts "  3. Task 보드: 칸반 스타일 태스크 관리"
puts "  4. Team Performance: 팀별 용량 및 성능"
puts "  5. Service별 Task ID: ECOM-XXX 형식"

puts "\n💡 화면 확인 방법:"
puts "  1. bin/dev 실행하여 서버 시작"
puts "  2. http://demo.creatia.local:3000 접속"
puts "  3. admin@creatia.local / password123 로그인"
puts "  4. Dashboard에서 메트릭 확인"
puts "  5. Sprints 메뉴에서 번다운 차트 확인"

puts "\n📈 현재 스프린트 상태:"
puts "  • Sprint 23: #{elapsed_days}/#{sprint_days}일 경과"
puts "  • 완료: #{current_tasks.count { |t| t[:status] == "done" }}/#{current_tasks.count}개 태스크"
puts "  • Story Points: 11/35 완료 (#{(11.0/35*100).round(1)}%)"

puts "\n" + "=" * 60