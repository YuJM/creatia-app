# frozen_string_literal: true

require 'faker'

# Demo 조직 전용 풍부한 시드 데이터 (Faker 사용)
# 이 파일은 demo 조직에 대해 더 현실적인 데이터를 생성합니다.

puts "\n🚀 Demo 조직 전용 데이터 생성 중 (Faker 사용)..."
puts "=" * 60

# Faker 한국어 설정 (한국어와 영어 혼용)
Faker::Config.locale = 'ko'

# Demo 조직 찾기
demo_org = Organization.find_by(subdomain: 'demo')
unless demo_org
  puts "⚠️ Demo 조직이 존재하지 않습니다. 먼저 기본 seed를 실행하세요."
  exit 1
end

demo_service = Service.find_by(organization: demo_org)
unless demo_service
  demo_service = Service.create!(
    name: "Demo Project",
    organization: demo_org,
    description: "Demo 조직의 메인 프로젝트",
    task_prefix: "DEMO"
  )
end

puts "✅ Demo 조직: #{demo_org.name}"
puts "✅ Demo 서비스: #{demo_service.name}"

# ============================================================================
# 1. 추가 사용자 생성 (Faker 사용)
# ============================================================================
puts "\n👥 추가 팀 멤버 생성 중..."

additional_users = []
10.times do |i|
  user = User.find_or_create_by(
    email: Faker::Internet.unique.email(domain: 'demo.creatia.local')
  ) do |u|
    u.password = 'password123'
    u.password_confirmation = 'password123'
    u.name = Faker::Name.name
    u.username = Faker::Internet.unique.username(separators: ['_'])
    u.role = ['user', 'user', 'admin'].sample  # 대부분 일반 사용자
  end
  
  if user.persisted?
    additional_users << user
    
    # Demo 조직에 멤버로 추가
    OrganizationMembership.find_or_create_by(
      user: user,
      organization: demo_org
    ) do |m|
      m.role = ['member', 'member', 'admin'].sample
      m.active = true
    end
    
    puts "  ✓ #{user.name} (#{user.email})"
  end
end

all_demo_users = demo_org.users.to_a

# ============================================================================
# 2. 프로젝트 관련 Epic 라벨 생성 (실제 프로젝트 같은 라벨)
# ============================================================================
realistic_epics = [
  { name: "🚀 Phase 1 - MVP", color: "#FF6B6B", description: "최소 기능 제품 구현" },
  { name: "🛠️ Infrastructure", color: "#4DABF7", description: "인프라 및 DevOps" },
  { name: "📱 Mobile App", color: "#51CF66", description: "모바일 애플리케이션 개발" },
  { name: "🔐 Security & Compliance", color: "#FFD43B", description: "보안 및 규정 준수" },
  { name: "📊 Analytics Platform", color: "#C92A2A", description: "분석 플랫폼 구축" },
  { name: "🤖 AI Features", color: "#A9E34B", description: "AI/ML 기능 통합" },
  { name: "⚡ Performance", color: "#E599F7", description: "성능 최적화" },
  { name: "🌍 Internationalization", color: "#FF8787", description: "다국어 지원" },
  { name: "💰 Billing System", color: "#748FFC", description: "결제 및 구독 시스템" },
  { name: "🔄 Data Migration", color: "#D6336C", description: "레거시 데이터 마이그레이션" }
]

created_labels = []
if defined?(Label)
  puts "\n🏷️ 프로젝트 Epic 라벨 생성 중..."
  
  realistic_epics.each do |label_attrs|
    label = Label.find_or_create_by(
      organization: demo_org,
      name: label_attrs[:name]
    ) do |l|
      l.color = label_attrs[:color]
      l.description = label_attrs[:description]
      l.label_type = 'epic'
    end
    created_labels << label if label.persisted?
    puts "  ✓ #{label.name}"
  end
else
  puts "\n⚠️ Label 모델이 없어 Epic 라벨 생성을 건너뜁니다."
  created_labels = realistic_epics.map { |attrs| OpenStruct.new(name: attrs[:name]) }
end

# ============================================================================
# 3. 현실적인 마일스톤 생성
# ============================================================================
puts "\n🎯 프로젝트 마일스톤 생성 중..."

project_milestones = [
  {
    title: "v1.0 Public Beta",
    description: Faker::Lorem.paragraph(sentence_count: 3),
    status: "active",
    milestone_type: "release",
    planned_start: 1.month.ago,
    planned_end: 1.month.from_now,
    objectives: [
      {
        id: SecureRandom.uuid,
        title: "User Engagement",
        key_results: [
          { 
            id: SecureRandom.uuid,
            description: "Beta 사용자 1,000명 확보",
            target: 1000,
            current: 650,
            unit: "users"
          },
          {
            id: SecureRandom.uuid,
            description: "일일 활성 사용자 500명",
            target: 500,
            current: 320,
            unit: "DAU"
          }
        ]
      }
    ]
  },
  {
    title: "v2.0 Enterprise Edition",
    description: Faker::Lorem.paragraph(sentence_count: 3),
    status: "planning",
    milestone_type: "release",
    planned_start: 2.months.from_now,
    planned_end: 5.months.from_now,
    objectives: [
      {
        id: SecureRandom.uuid,
        title: "Enterprise Features",
        key_results: [
          {
            id: SecureRandom.uuid,
            description: "SSO 통합 완료",
            target: 100,
            current: 0,
            unit: "%"
          },
          {
            id: SecureRandom.uuid,
            description: "Enterprise 고객 10개 확보",
            target: 10,
            current: 0,
            unit: "customers"
          }
        ]
      }
    ]
  },
  {
    title: "Infrastructure Scaling",
    description: "클라우드 인프라 확장 및 최적화",
    status: "active",
    milestone_type: "technical",
    planned_start: 2.weeks.ago,
    planned_end: 6.weeks.from_now,
    objectives: [
      {
        id: SecureRandom.uuid,
        title: "System Performance",
        key_results: [
          {
            id: SecureRandom.uuid,
            description: "API 응답 시간 < 200ms",
            target: 200,
            current: 350,
            unit: "ms"
          },
          {
            id: SecureRandom.uuid,
            description: "99.9% Uptime",
            target: 99.9,
            current: 99.5,
            unit: "%"
          }
        ]
      }
    ]
  }
]

project_milestones.each do |milestone_attrs|
  milestone = Milestone.find_or_create_by(
    organization_id: demo_org.id,
    title: milestone_attrs[:title]
  ) do |m|
    m.description = milestone_attrs[:description]
    m.status = milestone_attrs[:status]
    m.milestone_type = milestone_attrs[:milestone_type]
    m.planned_start = milestone_attrs[:planned_start]
    m.planned_end = milestone_attrs[:planned_end]
    m.objectives = milestone_attrs[:objectives]
    m.created_by_id = demo_org.owner.id
    m.owner_id = all_demo_users.sample.id
    m.stakeholder_ids = all_demo_users.sample(rand(3..5)).map(&:id)
    m.risks = rand < 0.5 ? [
      {
        id: SecureRandom.uuid,
        title: Faker::Lorem.sentence,
        impact: ['low', 'medium', 'high'].sample,
        probability: ['low', 'medium', 'high'].sample,
        mitigation: Faker::Lorem.paragraph
      }
    ] : []
  end
  puts "  ✓ #{milestone.title}" if milestone.persisted?
end

# ============================================================================
# 4. 현실적인 Sprint 생성
# ============================================================================
puts "\n⚡ 프로젝트 스프린트 생성 중..."

# 지난 스프린트들
past_sprints = []
3.times do |i|
  sprint_number = i + 1
  start_date = (8 - (i * 2)).weeks.ago
  end_date = start_date + 2.weeks
  
  sprint = Mongodb::MongoSprint.find_or_create_by(
    organization_id: demo_org.id,
    service_id: demo_service.id,
    name: "Sprint #{sprint_number}"
  ) do |s|
    s.goal = Faker::Company.catch_phrase
    s.status = 'completed'
    s.start_date = start_date
    s.end_date = end_date
    s.working_days = 10
    s.committed_points = rand(45..75).to_f
    s.completed_points = (s.committed_points * rand(0.85..1.05)).round
    s.sprint_number = sprint_number
    s.team_capacity = all_demo_users.size * 6  # 6 hours per person per day
    s.planned_velocity = s.committed_points / 10
    s.actual_velocity = s.completed_points / 10
    s.health_score = rand(75..95)
    s.retrospective = {
      went_well: Faker::Lorem.sentences(number: 3),
      needs_improvement: Faker::Lorem.sentences(number: 2),
      action_items: Faker::Lorem.sentences(number: 2)
    }
  end
  past_sprints << sprint if sprint.persisted?
  puts "  ✓ #{sprint.name} (완료됨)"
end

# 현재 스프린트
current_sprint = Mongodb::MongoSprint.find_or_create_by(
  organization_id: demo_org.id,
  service_id: demo_service.id,
  name: "Sprint #{past_sprints.size + 1}"
) do |s|
  s.goal = "사용자 대시보드 개선 및 성능 최적화"
  s.status = 'active'
  s.start_date = 1.week.ago
  s.end_date = 1.week.from_now
  s.working_days = 10
  s.committed_points = 68.0
  s.completed_points = 28.0
  s.sprint_number = past_sprints.size + 1
  s.team_capacity = all_demo_users.size * 6
  s.planned_velocity = 6.8
  s.actual_velocity = 4.0  # 현재까지
  s.health_score = 82
  s.daily_standups = [
    {
      date: Date.current.to_s,
      notes: {
        blockers: ["API 성능 이슈 조사 중", "디자인 리뷰 대기"],
        achievements: ["로그인 플로우 완료", "캐싱 구현 완료"],
        focus_today: ["대시보드 위젯 개발", "테스트 작성"]
      }
    }
  ]
end
puts "  ✓ #{current_sprint.name} (진행 중)" if current_sprint.persisted?

# 미래 스프린트
future_sprint = Mongodb::MongoSprint.find_or_create_by(
  organization_id: demo_org.id,
  service_id: demo_service.id,
  name: "Sprint #{past_sprints.size + 2}"
) do |s|
  s.goal = "모바일 최적화 및 PWA 구현"
  s.status = 'planning'
  s.start_date = 1.week.from_now + 1.day
  s.end_date = 3.weeks.from_now + 1.day
  s.working_days = 10
  s.committed_points = 55.0
  s.sprint_number = past_sprints.size + 2
  s.team_capacity = all_demo_users.size * 6
  s.planned_velocity = 5.5
end
puts "  ✓ #{future_sprint.name} (계획 중)" if future_sprint.persisted?

# ============================================================================
# 5. 현실적인 Task 생성 (Faker 사용)
# ============================================================================
puts "\n📋 현실적인 태스크 생성 중..."

task_counter = Mongodb::MongoTask.where(organization_id: demo_org.id).count + 1
created_task_count = 0

# Task 템플릿 생성 함수
def generate_realistic_task(epic_name, task_counter, service)
  task_templates = {
    "🚀 Phase 1 - MVP" => [
      { 
        title: "사용자 등록 플로우 구현",
        type: "feature",
        priority: "high",
        points: 8
      },
      {
        title: "이메일 인증 시스템 구축",
        type: "feature",
        priority: "high",
        points: 5
      },
      {
        title: "프로필 관리 페이지 개발",
        type: "feature",
        priority: "medium",
        points: 5
      }
    ],
    "🛠️ Infrastructure" => [
      {
        title: "Kubernetes 클러스터 설정",
        type: "chore",
        priority: "high",
        points: 13
      },
      {
        title: "CI/CD 파이프라인 구축",
        type: "chore",
        priority: "high",
        points: 8
      },
      {
        title: "모니터링 시스템 구현",
        type: "chore",
        priority: "medium",
        points: 8
      }
    ],
    "📱 Mobile App" => [
      {
        title: "React Native 프로젝트 초기화",
        type: "feature",
        priority: "high",
        points: 5
      },
      {
        title: "푸시 알림 구현",
        type: "feature",
        priority: "medium",
        points: 8
      },
      {
        title: "오프라인 모드 지원",
        type: "feature",
        priority: "low",
        points: 13
      }
    ],
    "🔐 Security & Compliance" => [
      {
        title: "OWASP Top 10 보안 감사",
        type: "chore",
        priority: "high",
        points: 8
      },
      {
        title: "GDPR 컴플라이언스 구현",
        type: "feature",
        priority: "high",
        points: 13
      },
      {
        title: "2FA 인증 구현",
        type: "feature",
        priority: "medium",
        points: 8
      }
    ]
  }
  
  # 기본 템플릿이 없으면 Faker로 생성
  templates = task_templates[epic_name] || [
    {
      title: Faker::Hacker.say_something_smart,
      type: ['feature', 'bug', 'chore'].sample,
      priority: ['low', 'medium', 'high'].sample,
      points: [1, 2, 3, 5, 8, 13].sample
    }
  ]
  
  task = templates.sample
  {
    task_id: "#{service.task_prefix || 'DEMO'}-#{task_counter.to_s.rjust(4, '0')}",
    title: task[:title],
    description: Faker::Lorem.paragraph(sentence_count: 3),
    task_type: task[:type],
    priority: task[:priority],
    story_points: task[:points].to_f,
    acceptance_criteria: [
      Faker::Lorem.sentence,
      Faker::Lorem.sentence,
      Faker::Lorem.sentence
    ]
  }
end

# 각 Epic에 대해 태스크 생성
created_labels.each do |epic_label|
  epic_task_count = rand(5..15)
  
  epic_task_count.times do
    task_data = generate_realistic_task(epic_label.name, task_counter, demo_service)
    
    # 상태 결정 (현실적인 분포)
    status_distribution = ['todo'] * 3 + ['in_progress'] * 2 + ['review'] * 1 + ['done'] * 4
    status = status_distribution.sample
    
    # Sprint 할당
    sprint = case status
             when 'done' then past_sprints.sample
             when 'todo' then [future_sprint, nil].sample  # 일부는 백로그에
             else current_sprint
             end
    
    # 담당자 할당 (진행 중인 태스크만)
    assignee = status.in?(['in_progress', 'review', 'done']) ? all_demo_users.sample : nil
    
    # 시간 추적 데이터
    original_estimate = task_data[:story_points] * rand(1.5..3.0)
    time_spent = case status
                 when 'done' then original_estimate * rand(0.8..1.2)
                 when 'in_progress', 'review' then original_estimate * rand(0.3..0.7)
                 else 0
                 end
    
    task = Mongodb::MongoTask.create(
      organization_id: demo_org.id,
      service_id: demo_service.id,
      task_id: task_data[:task_id],
      title: task_data[:title],
      description: task_data[:description],
      task_type: task_data[:task_type],
      priority: task_data[:priority],
      story_points: task_data[:story_points],
      status: status,
      sprint_id: sprint&.id&.to_s,
      assignee_id: assignee&.id,
      assignee_name: assignee&.name,
      created_by_id: all_demo_users.sample.id,
      labels: [epic_label.name, task_data[:task_type]],
      epic_id: epic_label.name,
      acceptance_criteria: task_data[:acceptance_criteria],
      original_estimate_hours: original_estimate,
      time_spent_hours: time_spent,
      remaining_hours: [original_estimate - time_spent, 0].max,
      started_at: status != 'todo' ? rand(7.days.ago..Time.current) : nil,
      completed_at: status == 'done' ? rand(3.days.ago..Time.current) : nil,
      due_date: sprint ? sprint.end_date : Date.current + rand(30..90).days,
      is_blocked: status == 'in_progress' && rand < 0.1,
      blocked_reason: status == 'in_progress' && rand < 0.1 ? Faker::Lorem.sentence : nil,
      blocked_by_task_ids: rand < 0.2 ? ["DEMO-#{rand(1..task_counter).to_s.rjust(4, '0')}"] : [],
      subtasks: rand < 0.4 ? (1..rand(2..5)).map do
        {
          id: SecureRandom.uuid,
          title: Faker::Lorem.sentence,
          completed: status == 'done' || (status != 'todo' && rand < 0.5),
          assignee_id: assignee&.id
        }
      end : []
    )
    
    if task.persisted?
      created_task_count += 1
    else
      puts "    ⚠️ 태스크 생성 실패: #{task.errors.full_messages.join(', ')}"
    end
    task_counter += 1
    
    # Sprint에 Task 추가
    if sprint && task.persisted?
      sprint.task_ids << task.id.to_s unless sprint.task_ids.include?(task.id.to_s)
      sprint.total_tasks += 1
      sprint.completed_tasks += 1 if task.status == 'done'
      sprint.active_tasks += 1 if task.status.in?(['todo', 'in_progress', 'review'])
      sprint.save!
    end
  end
  
  puts "  ✓ #{epic_label.name}: #{epic_task_count}개 태스크 생성"
end

# ============================================================================
# 6. 현실적인 댓글 생성 (Faker 사용)
# ============================================================================
puts "\n💬 프로젝트 댓글 생성 중..."

comment_templates = [
  -> { "#{Faker::Name.first_name}님, 이 부분 리뷰 부탁드립니다." },
  -> { "테스트 결과: #{['통과', '실패', '부분 통과'].sample} - #{Faker::Lorem.sentence}" },
  -> { "고객 피드백: #{Faker::Lorem.sentence}" },
  -> { "성능 측정 결과: #{rand(50..200)}ms (목표: 100ms)" },
  -> { "코드 리뷰 완료. #{['LGTM', '수정 필요', '재검토 필요'].sample}" },
  -> { "PR ##{rand(100..500)} 머지 완료" },
  -> { "배포 완료: #{['production', 'staging', 'development'].sample} 환경" },
  -> { "버그 재현 성공. 원인: #{Faker::Lorem.sentence}" },
  -> { "디자인 시안 업데이트: #{Faker::Internet.url}" },
  -> { "미팅 요약: #{Faker::Lorem.paragraph(sentence_count: 2)}" }
]

recent_tasks = Mongodb::MongoTask.where(organization_id: demo_org.id).limit(30)
comment_count = 0

recent_tasks.each do |task|
  # 태스크당 0-8개의 댓글 (더 현실적인 분포)
  comment_num = [0, 0, 1, 1, 2, 2, 3, 4, 5, 8].sample
  
  comment_num.times do |i|
    author = all_demo_users.sample
    created_at = task.created_at + (i * rand(1..24).hours)
    
    comment = Mongodb::MongoComment.create(
      commentable_type: 'MongoTask',
      commentable_id: task.id.to_s,
      organization_id: demo_org.id,
      author_id: author.id,
      author_name: author.name,
      content: comment_templates.sample.call,
      content_type: 'text',
      comment_type: ['general', 'technical', 'review', 'question', 'decision'].sample,
      created_at: created_at,
      edited: rand < 0.1,
      reactions: rand < 0.4 ? {
        '👍' => all_demo_users.sample(rand(0..5)).map(&:id),
        '👀' => all_demo_users.sample(rand(0..3)).map(&:id),
        '🎉' => all_demo_users.sample(rand(0..2)).map(&:id),
        '❤️' => all_demo_users.sample(rand(0..2)).map(&:id)
      }.delete_if { |_, v| v.empty? } : {},
      mentioned_user_ids: rand < 0.3 ? all_demo_users.sample(rand(1..2)).map(&:id) : []
    )
    
    unless comment.persisted?
      puts "    ⚠️ 댓글 생성 실패: #{comment.errors.full_messages.join(', ')}"
    end
    
    comment_count += 1 if comment.persisted?
    
    # 태스크 댓글 수 업데이트
    if comment.persisted?
      task.comment_count = (task.comment_count || 0) + 1
      task.save!
    end
  end
end

puts "  ✓ #{comment_count}개 댓글 생성 완료"

# ============================================================================
# 7. 활동 로그 생성
# ============================================================================
puts "\n📊 활동 로그 생성 중..."

activity_count = 0
action_types = ['created', 'updated', 'status_changed', 'assigned', 'commented', 'completed', 'blocked', 'unblocked']

# 최근 30일간의 활동 생성
(0..30).each do |days_ago|
  date = days_ago.days.ago
  daily_activities = rand(10..50)  # 하루 10-50개 활동
  
  daily_activities.times do
    actor = all_demo_users.sample
    action = action_types.sample
    task = Mongodb::MongoTask.where(organization_id: demo_org.id).sample
    
    next unless task  # task가 nil인 경우 건너뛰기
    
    activity = Mongodb::MongoActivity.create!(
      organization_id: demo_org.id,
      actor_id: actor.id,
      actor_name: actor.name,
      action: action,
      target_type: 'MongoTask',
      target_id: task.id.to_s,
      target_title: task.title,
      activity_changes: case action
                        when 'status_changed'
                          { status: [['todo', 'in_progress'], ['in_progress', 'review'], ['review', 'done']].sample }
                        when 'assigned'
                          { assignee: [nil, all_demo_users.sample.name] }
                        when 'updated'
                          { 
                            priority: [['low', 'medium'], ['medium', 'high']].sample,
                            story_points: [[3, 5], [5, 8], [8, 13]].sample
                          }
                        else
                          {}
                        end,
      activity_metadata: {
        browser: ['Chrome', 'Firefox', 'Safari', 'Edge'].sample,
        ip_address: Faker::Internet.ip_v4_address,
        user_agent: Faker::Internet.user_agent
      },
      source: ['web', 'api', 'mobile'].sample,
      created_at: date + rand(0..23).hours + rand(0..59).minutes
    )
    
    activity_count += 1 if activity.persisted?
  end
end

puts "  ✓ #{activity_count}개 활동 로그 생성"

# ============================================================================
# 8. 팀 생산성 메트릭 생성
# ============================================================================
puts "\n📈 팀 생산성 메트릭 생성 중..."

metrics_count = 0

# 지난 30일간의 메트릭
(0..30).each do |days_ago|
  date = days_ago.days.ago.to_date
  
  # 일일 생산성 메트릭
  Mongodb::MongoMetrics.create!(
    organization_id: demo_org.id,
    service_id: demo_service.id,
    metric_type: 'team_velocity',
    metric_category: 'productivity',
    scope: 'team',
    scope_id: demo_org.id,
    value: rand(5.0..12.0).round(1),
    unit: 'story_points_per_day',
    timestamp: date.end_of_day,
    date: date,
    source: 'system',
    collection_method: 'calculated',
    dimensions: {
      team_size: all_demo_users.size,
      completed_tasks: rand(2..8),
      blocked_tasks: rand(0..2),
      active_sprints: 1
    },
    business_impact: 'high',
    confidence_level: 0.92,
    alert_thresholds: {
      warning: 4.0,
      critical: 2.0
    }
  )
  
  metrics_count += 1
  
  # 코드 품질 메트릭
  Mongodb::MongoMetrics.create(
    organization_id: demo_org.id,
    service_id: demo_service.id,
    metric_type: 'code_quality',
    metric_category: 'quality',
    scope: 'codebase',
    scope_id: demo_service.id,
    value: rand(75..95),
    unit: 'percentage',
    timestamp: date.end_of_day,
    date: date,
    source: 'sonarqube',
    collection_method: 'automated',
    dimensions: {
      code_coverage: rand(60..90),
      technical_debt: rand(10..100),
      code_smells: rand(5..50),
      vulnerabilities: rand(0..5)
    },
    business_impact: 'medium',
    confidence_level: 0.88
  )
  
  metrics_count += 1
end

puts "  ✓ #{metrics_count}개 메트릭 데이터 생성"

# ============================================================================
# 완료 리포트
# ============================================================================
puts "\n" + "=" * 60
puts "✅ Demo 조직 풍부한 데이터 생성 완료!"
puts "=" * 60

puts "\n📊 생성된 데이터 요약:"
puts "  • 추가 팀 멤버: #{additional_users.count}명"
puts "  • Epic 라벨: #{created_labels.count}개"
puts "  • 마일스톤: #{project_milestones.count}개"
puts "  • 스프린트: #{past_sprints.count + 2}개"
puts "  • 태스크: #{created_task_count}개"
puts "  • 댓글: #{comment_count}개"
puts "  • 활동 로그: #{activity_count}개"
puts "  • 메트릭: #{metrics_count}개"

demo_task_total = Mongodb::MongoTask.where(organization_id: demo_org.id).count
demo_sprint_total = Mongodb::MongoSprint.where(organization_id: demo_org.id).count
demo_comment_total = Mongodb::MongoComment.where(organization_id: demo_org.id).count

puts "\n📈 Demo 조직 전체 통계:"
puts "  • 총 태스크: #{demo_task_total}개"
puts "  • 총 스프린트: #{demo_sprint_total}개"
puts "  • 총 댓글: #{demo_comment_total}개"
puts "  • 총 마일스톤: #{Milestone.where(organization_id: demo_org.id).count}개"
puts "  • 팀 멤버: #{demo_org.users.count}명"

puts "\n🔗 Demo 조직 접속:"
puts "  URL: #{DomainService.organization_url('demo')}"
puts "  테스트 계정:"
puts "    • admin@creatia.local / password123 (관리자)"
puts "    • #{additional_users.first.email} / password123 (팀 멤버)"

puts "\n💡 주요 기능 확인:"
puts "  • 대시보드: /web/dashboard"
puts "  • 스프린트 보드: /web/services/#{demo_service.id}/sprints"
puts "  • 백로그: /web/services/#{demo_service.id}/backlog"
puts "  • 메트릭스: /web/services/#{demo_service.id}/metrics"
puts "  • 마일스톤: /web/milestones"

puts "\n🎯 현재 진행 중:"
current_in_progress = Mongodb::MongoTask.where(
  organization_id: demo_org.id,
  status: 'in_progress'
).count
puts "  • 진행 중인 태스크: #{current_in_progress}개"
puts "  • 활성 스프린트: #{current_sprint.name}"
puts "  • 스프린트 진행률: #{((current_sprint.completed_points / current_sprint.committed_points) * 100).round}%"

puts "\n" + "=" * 60