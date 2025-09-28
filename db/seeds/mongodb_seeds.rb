# frozen_string_literal: true

# MongoDB 실행 데이터 시드
# PostgreSQL 시드 데이터가 먼저 실행되어야 합니다.

# ============================================================================
# 헬퍼 메서드 정의
# ============================================================================
def generate_burndown_data(start_date, end_date, committed_points, completed_points, status)
  burndown_data = []
  current_remaining = committed_points
  
  (start_date..Date.current).each_with_index do |date, index|
    # 이상적인 번다운 계산
    total_days = (end_date - start_date).to_i
    ideal_remaining = committed_points - (committed_points * (index + 1) / total_days.to_f)
    
    # 실제 번다운 (약간의 랜덤성 추가)
    if date <= Date.current
      if status == 'completed' && date == Date.current - 7.days
        # 완료된 스프린트는 마지막에 0에 도달
        actual_remaining = [committed_points - completed_points, 0].max
      else
        # 진행 중인 스프린트는 점진적 감소
        daily_completion = rand(0..5) # 하루에 완료되는 포인트
        current_remaining = [current_remaining - daily_completion, 0].max
        actual_remaining = current_remaining
      end
    else
      actual_remaining = nil # 미래 데이터는 nil
    end
    
    burndown_data << {
      date: date,
      ideal_remaining: ideal_remaining.round(1),
      actual_remaining: actual_remaining&.round(1),
      tasks_completed: rand(0..3),
      points_completed: rand(0..5)
    }
  end
  
  burndown_data
end

puts "\n🏗️ MongoDB 실행 데이터 생성 중..."
puts "=" * 60

# MongoDB 연결 확인
begin
  Mongoid.default_client.command(ping: 1)
  puts "✅ MongoDB 연결 확인됨"
rescue Mongo::Error => e
  puts "❌ MongoDB 연결 실패: #{e.message}"
  puts "   podman machine이 실행 중인지 확인해주세요."
  exit 1
end

# PostgreSQL 데이터 존재 확인
organizations = Organization.all
users = User.all

if organizations.empty? || users.empty?
  puts "⚠️ PostgreSQL seed 데이터가 필요합니다."
  puts "   먼저 'bin/rails db:seed'를 실행해주세요."
  exit 1
end

puts "📊 기존 데이터: 조직 #{organizations.count}개, 사용자 #{users.count}명"

# ============================================================================
# 1. Milestone 생성
# ============================================================================
puts "\n🎯 마일스톤 생성 중..."

milestone_data = [
  {
    title: "Q1 제품 출시",
    description: "첫 번째 분기 주요 기능 출시 마일스톤",
    status: "active",
    milestone_type: "release",
    planned_start: Date.current - 30.days,
    planned_end: Date.current + 60.days,
    objectives: [
      {
        id: "obj-1",
        title: "사용자 참여도 향상", 
        key_results: [
          { id: "kr-1", description: "DAU 50% 증가", target: 1000, current: 650, unit: "users" },
          { id: "kr-2", description: "세션 시간 30% 개선", target: 15, current: 12, unit: "minutes" }
        ]
      }
    ]
  },
  {
    title: "베타 버전 완료",
    description: "베타 테스트를 위한 핵심 기능 구현 완료",
    status: "planning",
    milestone_type: "feature",
    planned_start: Date.current + 70.days,
    planned_end: Date.current + 120.days,
    objectives: [
      {
        id: "obj-2",
        title: "핵심 기능 안정성",
        key_results: [
          { id: "kr-3", description: "버그 신고 50% 감소", target: 10, current: 20, unit: "bugs" },
          { id: "kr-4", description: "응답 시간 개선", target: 200, current: 350, unit: "ms" }
        ]
      }
    ]
  }
]

created_milestones = []
organizations.each do |org|
  milestone_data.each do |milestone_attrs|
    owner = org.owner
    next unless owner
    
    milestone = Milestone.find_or_create_by(
      organization_id: org.id,
      title: milestone_attrs[:title]
    ) do |m|
      m.description = milestone_attrs[:description]
      m.status = milestone_attrs[:status]
      m.milestone_type = milestone_attrs[:milestone_type]
      m.planned_start = milestone_attrs[:planned_start]
      m.planned_end = milestone_attrs[:planned_end]
      m.objectives = milestone_attrs[:objectives]
      m.created_by_id = owner.id
      m.owner_id = owner.id
      m.stakeholder_ids = org.users.pluck(:id).first(3)
    end
    
    if milestone.persisted?
      created_milestones << milestone
      puts "  ✓ #{milestone.title} (#{org.name})"
    end
  end
end

# ============================================================================
# 2. Sprint 생성
# ============================================================================
puts "\n⚡ 스프린트 생성 중..."

sprint_data = [
  {
    name: "Sprint 1 - 기반 구축",
    goal: "프로젝트 기본 구조와 인증 시스템 구현",
    status: "completed",
    start_date: Date.current - 21.days,
    end_date: Date.current - 7.days,
    working_days: 10,
    committed_points: 55.0,
    completed_points: 52.0
  },
  {
    name: "Sprint 2 - 핵심 기능",
    goal: "Task 관리와 Sprint 보드 구현",
    status: "active", 
    start_date: Date.current - 6.days,
    end_date: Date.current + 8.days,
    working_days: 10,
    committed_points: 68.0,
    completed_points: 25.0
  },
  {
    name: "Sprint 3 - 고급 기능",
    goal: "메트릭스와 실시간 기능 구현",
    status: "planning",
    start_date: Date.current + 9.days,
    end_date: Date.current + 23.days,
    working_days: 10,
    committed_points: 45.0,
    completed_points: 0.0
  }
]

created_sprints = []
organizations.each do |org|
  service = Service.find_or_create_by(
    name: "#{org.name} 메인 서비스",
    organization: org
  ) do |s|
    s.description = "#{org.name}의 메인 개발 프로젝트"
  end
  
  sprint_data.each_with_index do |sprint_attrs, index|
    milestone = created_milestones.find { |m| m.organization_id == org.id }
    
    sprint = Mongodb::MongoSprint.find_or_create_by(
      organization_id: org.id,
      service_id: service.id,
      name: sprint_attrs[:name]
    ) do |s|
      s.goal = sprint_attrs[:goal]
      s.status = sprint_attrs[:status]
      s.start_date = sprint_attrs[:start_date]
      s.end_date = sprint_attrs[:end_date]
      s.working_days = sprint_attrs[:working_days]
      s.committed_points = sprint_attrs[:committed_points]
      s.completed_points = sprint_attrs[:completed_points]
      s.sprint_number = index + 1
      s.milestone_id = milestone&.id&.to_s
      s.team_capacity = 40.0
      s.planned_velocity = sprint_attrs[:committed_points] / sprint_attrs[:working_days]
      s.health_score = rand(70..95)
      
      # 번다운 데이터 생성
      if sprint_attrs[:status] != 'planning'
        s.burndown_data = generate_burndown_data(
          sprint_attrs[:start_date],
          sprint_attrs[:end_date],
          sprint_attrs[:committed_points],
          sprint_attrs[:completed_points],
          sprint_attrs[:status]
        )
      end
    end
    
    if sprint.persisted?
      created_sprints << sprint
      puts "  ✓ #{sprint.name} (#{org.name}) - #{sprint.status}"
    end
  end
end

# ============================================================================
# 3. Task 생성 (MongoDB 버전)
# ============================================================================
puts "\n📋 MongoDB Task 생성 중..."

task_templates = [
  {
    title: "사용자 인증 시스템 구현",
    description: "JWT 기반 사용자 인증 및 세션 관리 구현",
    task_type: "feature",
    priority: "high",
    story_points: 8.0,
    status: "done"
  },
  {
    title: "대시보드 UI 개발",
    description: "메인 대시보드 컴포넌트 및 레이아웃 구현",
    task_type: "feature",
    priority: "high",
    story_points: 13.0,
    status: "done"
  },
  {
    title: "API 엔드포인트 구현",
    description: "RESTful API 설계 및 기본 CRUD 엔드포인트 구현",
    task_type: "feature",
    priority: "medium",
    story_points: 5.0,
    status: "in_progress"
  },
  {
    title: "데이터베이스 마이그레이션",
    description: "MongoDB 연동 및 데이터 마이그레이션 스크립트 작성",
    task_type: "chore",
    priority: "high",
    story_points: 8.0,
    status: "in_progress"
  },
  {
    title: "성능 최적화",
    description: "쿼리 최적화 및 인덱스 개선",
    task_type: "chore",
    priority: "medium",
    story_points: 5.0,
    status: "todo"
  },
  {
    title: "테스트 커버리지 개선",
    description: "단위 테스트 및 통합 테스트 작성",
    task_type: "chore",
    priority: "medium",
    story_points: 8.0,
    status: "todo"
  },
  {
    title: "에러 처리 개선",
    description: "에러 핸들링 및 사용자 피드백 개선",
    task_type: "bug",
    priority: "high",
    story_points: 3.0,
    status: "review"
  },
  {
    title: "모바일 반응형 최적화",
    description: "모바일 환경에서 사용성 개선",
    task_type: "feature",
    priority: "medium",
    story_points: 13.0,
    status: "todo"
  }
]

task_counter = 1
created_tasks = []

organizations.each do |org|
  service = Service.find_by(organization: org)
  next unless service
  
  sprints = created_sprints.select { |s| s.organization_id == org.id }
  org_users = org.users.to_a
  
  task_templates.each do |task_attrs|
    # Sprint 할당 (Planning 상태 제외)
    available_sprints = sprints.reject { |s| s.status == 'planning' }
    sprint = available_sprints.sample
    
    # 담당자 할당 (70% 확률)
    assignee = org_users.sample if rand < 0.7
    
    task = Mongodb::MongoTask.find_or_create_by(
      organization_id: org.id,
      service_id: service.id,
      task_id: "#{service.name.upcase.gsub(/\s+/, '')}-#{task_counter.to_s.rjust(3, '0')}"
    ) do |t|
      t.title = task_attrs[:title]
      t.description = task_attrs[:description]
      t.task_type = task_attrs[:task_type]
      t.priority = task_attrs[:priority]
      t.story_points = task_attrs[:story_points]
      t.status = task_attrs[:status]
      t.sprint_id = sprint&.id&.to_s
      t.assignee_id = assignee&.id
      t.assignee_name = assignee&.name
      t.created_by_id = org.owner&.id
      
      # 타임스탬프 설정
      case task_attrs[:status]
      when 'done'
        t.started_at = 5.days.ago
        t.completed_at = 2.days.ago
      when 'in_progress'
        t.started_at = 3.days.ago
      when 'review'
        t.started_at = 4.days.ago
      end
      
      # 서브태스크 추가 (일부 태스크에만)
      if rand < 0.4
        t.subtasks = [
          { id: SecureRandom.uuid, title: "요구사항 분석", completed: true, assignee_id: assignee&.id },
          { id: SecureRandom.uuid, title: "설계 문서 작성", completed: task_attrs[:status] != 'todo', assignee_id: assignee&.id },
          { id: SecureRandom.uuid, title: "구현", completed: task_attrs[:status] == 'done', assignee_id: assignee&.id }
        ]
      end
      
      # 라벨 추가
      t.labels = case task_attrs[:task_type]
                 when 'feature' then ['frontend', 'backend']
                 when 'bug' then ['urgent', 'production']
                 when 'chore' then ['infrastructure', 'maintenance']
                 else ['general']
                 end
    end
    
    if task.persisted?
      created_tasks << task
      sprint_info = sprint ? " (Sprint: #{sprint.name})" : " (Backlog)"
      assignee_info = assignee ? " → #{assignee.name}" : " (미할당)"
      puts "  ✓ #{task.task_id}: #{task.title}#{assignee_info}#{sprint_info}"
      
      # Sprint에 Task 추가
      if sprint
        sprint.task_ids << task.id.to_s unless sprint.task_ids.include?(task.id.to_s)
        sprint.total_tasks += 1
        sprint.completed_tasks += 1 if task.status == 'done'
        sprint.active_tasks += 1 if task.status.in?(['todo', 'in_progress', 'review'])
        sprint.save!
      end
    end
    
    task_counter += 1
  end
end

# ============================================================================
# 4. Comment 생성
# ============================================================================
puts "\n💬 댓글 생성 중..."

comment_templates = [
  "좋은 아이디어입니다! 구현 방향이 맞는 것 같아요.",
  "몇 가지 보안 측면을 더 고려해야 할 것 같습니다.",
  "테스트 케이스도 함께 추가하면 좋겠어요.",
  "다른 팀과의 의존성은 어떻게 처리할까요?",
  "성능 영향도 확인이 필요할 것 같습니다.",
  "UI/UX 관점에서 사용자 경험을 더 개선할 수 있을 것 같아요.",
  "문서화도 함께 업데이트하면 좋겠습니다."
]

created_tasks.each do |task|
  # 태스크당 0-3개의 댓글 생성
  comment_count = rand(0..3)
  org = organizations.find { |o| o.id == task.organization_id }
  org_users = org.users.to_a
  
  comment_count.times do |i|
    author = org_users.sample
    next unless author
    
    comment = Mongodb::MongoComment.create!(
      commentable_type: 'MongoTask',
      commentable_id: task.id.to_s,
      organization_id: task.organization_id,
      author_id: author.id,
      author_name: author.name,
      content: comment_templates.sample,
      content_type: 'text',
      comment_type: ['general', 'question', 'decision'].sample,
      created_at: rand(5.days.ago..1.hour.ago)
    )
    
    if comment.persisted?
      # Task 댓글 수 업데이트
      task.comment_count += 1
    end
  end
  
  task.save! if task.comment_count > 0
end

puts "  ✓ 총 #{Mongodb::MongoComment.count}개 댓글 생성"

# ============================================================================
# 5. Activity 생성
# ============================================================================
puts "\n📊 활동 기록 생성 중..."

activity_count = 0
created_tasks.each do |task|
  org = organizations.find { |o| o.id == task.organization_id }
  
  # Task 생성 활동
  Mongodb::MongoActivity.create!(
    organization_id: task.organization_id,
    actor_id: task.created_by_id,
    actor_name: org.owner&.name,
    action: 'created',
    target_type: 'MongoTask',
    target_id: task.id.to_s,
    target_title: task.title,
    activity_changes: {},
    activity_metadata: {
      task_type: task.task_type,
      priority: task.priority,
      story_points: task.story_points
    },
    source: 'web',
    created_at: task.created_at
  )
  activity_count += 1
  
  # 상태 변경 활동 (진행 중이거나 완료된 태스크)
  if task.status != 'todo'
    Mongodb::MongoActivity.create!(
      organization_id: task.organization_id,
      actor_id: task.assignee_id || task.created_by_id,
      actor_name: task.assignee_name || org.owner&.name,
      action: 'status_changed',
      target_type: 'MongoTask', 
      target_id: task.id.to_s,
      target_title: task.title,
      activity_changes: {
        status: ['todo', task.status]
      },
      activity_metadata: {
        sprint_id: task.sprint_id
      },
      source: 'web',
      created_at: task.started_at || 2.days.ago
    )
    activity_count += 1
  end
  
  # 완료 활동
  if task.status == 'done'
    Mongodb::MongoActivity.create!(
      organization_id: task.organization_id,
      actor_id: task.assignee_id || task.created_by_id,
      actor_name: task.assignee_name || org.owner&.name,
      action: 'completed',
      target_type: 'MongoTask',
      target_id: task.id.to_s,
      target_title: task.title,
      activity_changes: {
        status: ['in_progress', 'done']
      },
      activity_metadata: {
        completion_time: task.completed_at,
        story_points: task.story_points
      },
      source: 'web',
      created_at: task.completed_at || 1.day.ago
    )
    activity_count += 1
  end
end

puts "  ✓ #{activity_count}개 활동 기록 생성"

# ============================================================================
# 6. PomodoroSession 생성
# ============================================================================
puts "\n🍅 포모도로 세션 생성 중..."

session_count = 0
organizations.each do |org|
  org.users.each do |user|
    # 지난 7일간의 포모도로 세션 생성
    (0..6).each do |days_ago|
      session_date = Date.current - days_ago.days
      daily_sessions = rand(3..8) # 하루 3-8세션
      
      daily_sessions.times do |session_num|
        session_start = session_date.beginning_of_day + rand(8..18).hours + rand(60).minutes
        
        session = Mongodb::MongoPomodoroSession.create!(
          organization_id: org.id,
          user_id: user.id,
          session_type: 'pomodoro',
          duration_minutes: 25,
          status: 'completed',
          started_at: session_start,
          completed_at: session_start + 25.minutes,
          session_date: session_date,
          daily_session_number: session_num + 1,
          focus_score: rand(60..95),
          productivity_rating: rand(3..5),
          energy_level: rand(2..5),
          session_goal: "집중 작업 세션 #{session_num + 1}",
          completed_goal: rand < 0.8,
          location: ['home', 'office', 'cafe'].sample,
          environment_noise: ['quiet', 'moderate'].sample,
          tools_used: ['vscode', 'browser', 'terminal'].sample(rand(1..3)),
          hour_started: session_start.hour,
          day_of_week: session_date.strftime('%A').downcase,
          time_zone: Time.zone.name,
          interruptions: rand < 0.3 ? [
            {
              timestamp: session_start + rand(5..20).minutes,
              type: ['internal', 'external'].sample,
              reason: ['phone_call', 'email', 'meeting', 'coffee_break'].sample,
              duration_seconds: rand(30..300)
            }
          ] : []
        )
        
        session_count += 1 if session.persisted?
      end
    end
  end
end

puts "  ✓ #{session_count}개 포모도로 세션 생성"

# ============================================================================
# 7. Metrics 생성
# ============================================================================
puts "\n📈 메트릭 데이터 생성 중..."

metrics_count = 0
organizations.each do |org|
  org_sprints = created_sprints.select { |s| s.organization_id == org.id }
  
  # 스프린트 속도 메트릭
  org_sprints.each do |sprint|
    next if sprint.status == 'planning'
    
    (sprint.start_date..Date.current).each do |date|
      velocity = rand(3.0..8.0)
      
      Mongodb::MongoMetrics.create!(
        organization_id: org.id,
        service_id: sprint.service_id,
        metric_type: 'sprint_velocity',
        metric_category: 'performance',
        scope: 'sprint',
        scope_id: sprint.id.to_s,
        value: velocity,
        unit: 'points_per_day',
        timestamp: date.end_of_day,
        date: date,
        source: 'system',
        collection_method: 'periodic',
        dimensions: {
          sprint_name: sprint.name,
          team_size: rand(3..7),
          sprint_length: sprint.working_days
        },
        business_impact: 'medium',
        confidence_level: 0.9
      )
      
      metrics_count += 1
    end
  end
  
  # 사용자 생산성 메트릭
  org.users.each do |user|
    (0..6).each do |days_ago|
      date = Date.current - days_ago.days
      productivity_score = rand(60..95)
      
      Mongodb::MongoMetrics.create!(
        organization_id: org.id,
        user_id: user.id,
        metric_type: 'daily_productivity',
        metric_category: 'productivity',
        scope: 'user',
        scope_id: user.id,
        value: productivity_score,
        unit: 'percentage',
        timestamp: date.end_of_day,
        date: date,
        source: 'system',
        collection_method: 'periodic',
        dimensions: {
          sessions_count: rand(4..8),
          total_work_minutes: rand(180..400),
          interruptions: rand(0..5)
        },
        business_impact: 'low',
        confidence_level: 0.8
      )
      
      metrics_count += 1
    end
  end
end

puts "  ✓ #{metrics_count}개 메트릭 데이터 생성"

# ============================================================================
# 완료 리포트
# ============================================================================
puts "\n" + "=" * 60
puts "✅ MongoDB 실행 데이터 생성 완료!"
puts "=" * 60

puts "\n📊 생성된 MongoDB 데이터:"
puts "  • 마일스톤: #{Milestone.count}개"
puts "  • 스프린트: #{Mongodb::MongoSprint.count}개"
puts "  • 태스크: #{Mongodb::MongoTask.count}개"
puts "  • 댓글: #{Mongodb::MongoComment.count}개"
puts "  • 활동 기록: #{Mongodb::MongoActivity.count}개"
puts "  • 포모도로 세션: #{Mongodb::MongoPomodoroSession.count}개"
puts "  • 메트릭: #{Mongodb::MongoMetrics.count}개"

puts "\n🔗 테스트 URL:"
organizations.each do |org|
  puts "  #{org.name}: #{DomainService.organization_url(org.subdomain)}/dashboard"
end

puts "\n💡 다음 단계:"
puts "  1. bin/dev로 서버 시작"
puts "  2. 스프린트 보드 테스트: {org}.creatia.local/web/services/{service_id}/sprints/{sprint_id}/board"
puts "  3. 번다운 차트 테스트: {org}.creatia.local/web/services/{service_id}/sprints/{sprint_id}/burndown"

puts "\n" + "=" * 60