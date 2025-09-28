# frozen_string_literal: true

# Demo 조직 전용 풍부한 시드 데이터
# 이 파일은 demo 조직에 대해 더 많은 데이터를 생성합니다.

puts "\n🚀 Demo 조직 전용 데이터 생성 중..."
puts "=" * 60

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
    description: "Demo 조직의 메인 프로젝트"
  )
end

puts "✅ Demo 조직: #{demo_org.name}"
puts "✅ Demo 서비스: #{demo_service.name}"

# ============================================================================
# 1. Epic 라벨 생성 (Label 모델이 있는 경우에만)
# ============================================================================
epic_labels = [
  { name: "🛒 장바구니 시스템", color: "#FF6B6B", description: "쇼핑 카트 전체 기능" },
  { name: "👤 회원 관리", color: "#4DABF7", description: "사용자 인증 및 프로필 관리" },
  { name: "💳 결제 시스템", color: "#51CF66", description: "결제 처리 및 청구 관리" },
  { name: "🔍 검색 기능", color: "#FFD43B", description: "검색 엔진 및 필터링" },
  { name: "📊 분석 대시보드", color: "#C92A2A", description: "데이터 시각화 및 리포팅" },
  { name: "🔔 알림 시스템", color: "#A9E34B", description: "실시간 알림 및 이메일" },
  { name: "📱 모바일 최적화", color: "#E599F7", description: "반응형 디자인 및 터치 최적화" },
  { name: "🔐 보안 강화", color: "#FF8787", description: "보안 취약점 개선 및 감사" }
]

created_labels = []
if defined?(Label)
  puts "\n🏷️ Epic 라벨 생성 중..."
  
  epic_labels.each do |label_attrs|
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
  # Epic 라벨 이름만 사용하도록 배열 생성
  created_labels = epic_labels.map { |attrs| OpenStruct.new(name: attrs[:name]) }
end

# ============================================================================
# 2. 추가 마일스톤 생성
# ============================================================================
puts "\n🎯 추가 마일스톤 생성 중..."

additional_milestones = [
  {
    title: "Q2 성능 개선",
    description: "시스템 전반의 성능 최적화 및 확장성 개선",
    status: "planning",
    milestone_type: "technical",
    planned_start: Date.current + 90.days,
    planned_end: Date.current + 180.days,
    objectives: [
      {
        id: "obj-perf-1",
        title: "응답 시간 개선",
        key_results: [
          { id: "kr-perf-1", description: "API 응답 시간 50% 감소", target: 100, current: 200, unit: "ms" },
          { id: "kr-perf-2", description: "페이지 로드 시간 2초 이내", target: 2, current: 3.5, unit: "seconds" }
        ]
      }
    ]
  },
  {
    title: "모바일 앱 출시",
    description: "iOS 및 Android 네이티브 앱 개발 및 출시",
    status: "planning",
    milestone_type: "release",
    planned_start: Date.current + 120.days,
    planned_end: Date.current + 210.days,
    objectives: [
      {
        id: "obj-mobile-1",
        title: "모바일 사용자 확보",
        key_results: [
          { id: "kr-mobile-1", description: "앱 다운로드 10,000건", target: 10000, current: 0, unit: "downloads" },
          { id: "kr-mobile-2", description: "평점 4.5 이상", target: 4.5, current: 0, unit: "rating" }
        ]
      }
    ]
  }
]

additional_milestones.each do |milestone_attrs|
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
    m.owner_id = demo_org.owner.id
    m.stakeholder_ids = demo_org.users.pluck(:id).first(5)
  end
  puts "  ✓ #{milestone.title}" if milestone.persisted?
end

# ============================================================================
# 3. 대량 Task 생성 (Epic별로 구성)
# ============================================================================
puts "\n📋 Epic별 Task 생성 중..."

# 현재 스프린트 찾기
active_sprint = Mongodb::MongoSprint.find_by(
  organization_id: demo_org.id,
  status: 'active'
)

planning_sprint = Mongodb::MongoSprint.find_by(
  organization_id: demo_org.id,
  status: 'planning'  
)

# Task 카운터 시작 번호
task_counter = Mongodb::MongoTask.where(organization_id: demo_org.id).count + 1

# Epic별 Task 템플릿
epic_tasks = {
  "🛒 장바구니 시스템" => [
    { title: "장바구니 추가 API 구현", type: "feature", priority: "high", points: 5 },
    { title: "장바구니 수량 업데이트 기능", type: "feature", priority: "medium", points: 3 },
    { title: "장바구니 아이템 삭제 기능", type: "feature", priority: "medium", points: 2 },
    { title: "장바구니 UI 컴포넌트 개발", type: "feature", priority: "high", points: 8 },
    { title: "장바구니 상태 관리 구현", type: "feature", priority: "high", points: 5 },
    { title: "장바구니 로컬 스토리지 동기화", type: "feature", priority: "low", points: 3 },
    { title: "장바구니 애니메이션 추가", type: "enhancement", priority: "low", points: 2 }
  ],
  "👤 회원 관리" => [
    { title: "회원가입 폼 검증 강화", type: "feature", priority: "high", points: 3 },
    { title: "소셜 로그인 통합 (Google)", type: "feature", priority: "medium", points: 8 },
    { title: "소셜 로그인 통합 (GitHub)", type: "feature", priority: "medium", points: 5 },
    { title: "비밀번호 재설정 플로우", type: "feature", priority: "high", points: 5 },
    { title: "프로필 이미지 업로드", type: "feature", priority: "low", points: 3 },
    { title: "회원 정보 수정 페이지", type: "feature", priority: "medium", points: 5 },
    { title: "이메일 인증 시스템", type: "feature", priority: "high", points: 8 }
  ],
  "💳 결제 시스템" => [
    { title: "Stripe 결제 게이트웨이 연동", type: "feature", priority: "high", points: 13 },
    { title: "결제 내역 조회 API", type: "feature", priority: "high", points: 5 },
    { title: "환불 처리 기능", type: "feature", priority: "medium", points: 8 },
    { title: "정기 결제 구현", type: "feature", priority: "medium", points: 13 },
    { title: "결제 실패 재시도 로직", type: "feature", priority: "high", points: 5 },
    { title: "영수증 PDF 생성", type: "feature", priority: "low", points: 5 }
  ],
  "🔍 검색 기능" => [
    { title: "Elasticsearch 연동", type: "feature", priority: "high", points: 13 },
    { title: "자동완성 기능 구현", type: "feature", priority: "medium", points: 8 },
    { title: "검색 필터 UI 개발", type: "feature", priority: "medium", points: 5 },
    { title: "검색 결과 페이지네이션", type: "feature", priority: "medium", points: 3 },
    { title: "검색어 하이라이팅", type: "enhancement", priority: "low", points: 2 },
    { title: "최근 검색어 저장", type: "feature", priority: "low", points: 3 }
  ],
  "📊 분석 대시보드" => [
    { title: "차트 라이브러리 통합", type: "feature", priority: "high", points: 8 },
    { title: "실시간 데이터 업데이트", type: "feature", priority: "medium", points: 8 },
    { title: "커스텀 대시보드 위젯", type: "feature", priority: "medium", points: 13 },
    { title: "데이터 내보내기 (CSV/Excel)", type: "feature", priority: "low", points: 5 },
    { title: "대시보드 레이아웃 커스터마이징", type: "feature", priority: "low", points: 8 }
  ]
}

created_task_count = 0
demo_users = demo_org.users.to_a

epic_tasks.each do |epic_name, tasks|
  epic_label = created_labels.find { |l| l.name == epic_name }
  
  tasks.each do |task_attrs|
    # 상태 결정 (랜덤)
    status = ['todo', 'todo', 'in_progress', 'review', 'done'].sample
    
    # Sprint 할당
    sprint = case status
             when 'done' then nil # 완료된 태스크는 과거 스프린트
             when 'todo' then planning_sprint
             else active_sprint
             end
    
    # 담당자 할당
    assignee = status != 'todo' ? demo_users.sample : nil
    
    task = Mongodb::MongoTask.create!(
      organization_id: demo_org.id,
      service_id: demo_service.id,
      task_id: "DEMO-#{task_counter.to_s.rjust(4, '0')}",
      title: task_attrs[:title],
      description: "#{epic_name} 기능의 일부로 #{task_attrs[:title]}을(를) 구현합니다.",
      task_type: task_attrs[:type],
      priority: task_attrs[:priority],
      story_points: task_attrs[:points],
      status: status,
      sprint_id: sprint&.id&.to_s,
      assignee_id: assignee&.id,
      assignee_name: assignee&.name,
      created_by_id: demo_org.owner.id,
      labels: [epic_name, task_attrs[:type]],
      epic_label: epic_name,
      started_at: status != 'todo' ? rand(7.days.ago..1.day.ago) : nil,
      completed_at: status == 'done' ? rand(3.days.ago..1.hour.ago) : nil,
      due_date: sprint ? sprint.end_date : Date.current + rand(30..90).days,
      original_estimate_hours: task_attrs[:points] * 2,
      time_spent_hours: status == 'done' ? task_attrs[:points] * 1.8 : task_attrs[:points] * 0.5
    )
    
    created_task_count += 1 if task.persisted?
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
  
  puts "  ✓ #{epic_name}: #{tasks.size}개 태스크 생성"
end

# ============================================================================
# 4. 추가 댓글 및 활동 생성
# ============================================================================
puts "\n💬 추가 댓글 생성 중..."

detailed_comments = [
  "이 기능에 대해 고객 피드백을 받아봤는데, 매우 긍정적이었습니다.",
  "성능 테스트 결과 예상보다 빠르게 동작합니다. 👍",
  "보안 검토가 필요할 것 같습니다. @security-team 확인 부탁드립니다.",
  "디자인 시안이 업데이트되었습니다. Figma 링크 확인해주세요.",
  "이 부분은 리팩토링이 필요해 보입니다. 기술 부채로 등록하겠습니다.",
  "QA 테스트 통과했습니다. 프로덕션 배포 준비 완료!",
  "관련 문서를 Wiki에 업데이트했습니다.",
  "버그 수정 확인했습니다. 재현되지 않습니다.",
  "코드 리뷰 완료. LGTM! 🚀",
  "이 기능은 다음 스프린트로 이동하는 게 좋을 것 같습니다."
]

# 최근 생성된 Demo 조직 태스크들에 댓글 추가
recent_demo_tasks = Mongodb::MongoTask.where(organization_id: demo_org.id).limit(20)
comment_count = 0

recent_demo_tasks.each do |task|
  # 태스크당 1-5개의 댓글
  rand(1..5).times do
    author = demo_users.sample
    
    comment = Mongodb::MongoComment.create!(
      commentable_type: 'MongoTask',
      commentable_id: task.id.to_s,
      organization_id: demo_org.id,
      author_id: author.id,
      author_name: author.name,
      content: detailed_comments.sample,
      content_type: 'text',
      comment_type: ['general', 'question', 'decision', 'review'].sample,
      created_at: rand(5.days.ago..1.hour.ago),
      reactions: rand < 0.3 ? {
        '👍' => demo_users.sample(rand(1..3)).map(&:id),
        '🎉' => demo_users.sample(rand(0..2)).map(&:id)
      } : {}
    )
    
    comment_count += 1 if comment.persisted?
    
    # 태스크 댓글 수 업데이트
    if comment.persisted?
      task.comment_count += 1
      task.save!
    end
  end
end

puts "  ✓ #{comment_count}개 댓글 추가 생성"

# ============================================================================
# 5. 팀 메트릭 생성
# ============================================================================
puts "\n📊 팀 메트릭 생성 중..."

# 팀 전체 메트릭
(0..30).each do |days_ago|
  date = Date.current - days_ago.days
  
  # 일일 완료 태스크 수
  Mongodb::MongoMetrics.create!(
    organization_id: demo_org.id,
    service_id: demo_service.id,
    metric_type: 'daily_completed_tasks',
    metric_category: 'productivity',
    scope: 'team',
    scope_id: demo_org.id,
    value: rand(3..12),
    unit: 'tasks',
    timestamp: date.end_of_day,
    date: date,
    source: 'system',
    collection_method: 'periodic',
    dimensions: {
      team_size: demo_users.size,
      active_sprints: 1
    },
    business_impact: 'high',
    confidence_level: 0.95
  )
  
  # 평균 사이클 타임
  Mongodb::MongoMetrics.create!(
    organization_id: demo_org.id,
    service_id: demo_service.id,
    metric_type: 'cycle_time',
    metric_category: 'performance',
    scope: 'team',
    scope_id: demo_org.id,
    value: rand(1.5..5.0).round(1),
    unit: 'days',
    timestamp: date.end_of_day,
    date: date,
    source: 'system',
    collection_method: 'periodic',
    dimensions: {
      task_complexity: 'medium',
      team_efficiency: rand(0.7..0.95).round(2)
    },
    business_impact: 'medium',
    confidence_level: 0.85
  )
end

puts "  ✓ 팀 메트릭 데이터 생성 완료"

# ============================================================================
# 6. 알림 생성 (Notification 모델이 있는 경우)
# ============================================================================
if defined?(Notification)
  puts "\n🔔 알림 생성 중..."
  
  notification_count = 0
  demo_users.each do |user|
    # 각 사용자별 알림
    notifications = [
      {
        type: 'task_assigned',
        title: '새로운 태스크가 할당되었습니다',
        message: 'DEMO-0042: API 성능 최적화 태스크가 할당되었습니다.',
        priority: 'medium'
      },
      {
        type: 'mention',
        title: '댓글에서 언급되었습니다',
        message: '@' + user.username + ' 코드 리뷰를 확인해주세요.',
        priority: 'high'
      },
      {
        type: 'sprint_update',
        title: '스프린트가 시작되었습니다',
        message: 'Sprint 2 - 핵심 기능이 시작되었습니다.',
        priority: 'low'
      }
    ]
    
    notifications.sample(rand(1..3)).each do |notif_attrs|
      notification = Notification.create!(
        organization_id: demo_org.id,
        recipient_id: user.id,
        notification_type: notif_attrs[:type],
        title: notif_attrs[:title],
        message: notif_attrs[:message],
        priority: notif_attrs[:priority],
        read_at: rand < 0.6 ? rand(1.hour.ago..Time.current) : nil,
        action_url: "/tasks/#{rand(1..100)}",
        metadata: {
          sender_id: demo_users.sample.id,
          context: 'demo_seed'
        }
      )
      
      notification_count += 1 if notification.persisted?
    end
  end
  
  puts "  ✓ #{notification_count}개 알림 생성"
else
  puts "\n⚠️ Notification 모델이 없어 알림 생성을 건너뜁니다."
end

# ============================================================================
# 완료 리포트
# ============================================================================
puts "\n" + "=" * 60
puts "✅ Demo 조직 전용 데이터 생성 완료!"
puts "=" * 60

puts "\n📊 Demo 조직 데이터 요약:"
puts "  • Epic 라벨: #{created_labels.count}개"
puts "  • 추가 마일스톤: #{additional_milestones.count}개"
puts "  • 추가 태스크: #{created_task_count}개"
puts "  • 추가 댓글: #{comment_count}개"
puts "  • 알림: #{defined?(notification_count) ? notification_count : 0}개"

demo_task_total = Mongodb::MongoTask.where(organization_id: demo_org.id).count
demo_sprint_total = Mongodb::MongoSprint.where(organization_id: demo_org.id).count

puts "\n📈 Demo 조직 전체 통계:"
puts "  • 총 태스크: #{demo_task_total}개"
puts "  • 총 스프린트: #{demo_sprint_total}개"
puts "  • 총 마일스톤: #{Milestone.where(organization_id: demo_org.id).count}개"
puts "  • 팀 멤버: #{demo_org.users.count}명"

puts "\n🔗 Demo 조직 접속:"
puts "  URL: #{DomainService.organization_url('demo')}"
puts "  계정: admin@creatia.local / password123"

puts "\n💡 주요 기능 테스트:"
puts "  • 스프린트 보드: /web/services/#{demo_service.id}/sprints"
puts "  • 태스크 목록: /web/services/#{demo_service.id}/tasks"
puts "  • 대시보드: /web/dashboard"
puts "  • 메트릭스: /web/metrics"

puts "\n" + "=" * 60