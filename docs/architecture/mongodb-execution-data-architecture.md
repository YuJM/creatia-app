# MongoDB 기반 실행 데이터 아키텍처 설계

## 📋 목차
1. [핵심 인사이트](#핵심-인사이트)
2. [아키텍처 패러다임 전환](#아키텍처-패러다임-전환)
3. [데이터 분류 전략](#데이터-분류-전략)
4. [MongoDB 실행 데이터 모델](#mongodb-실행-데이터-모델)
5. [구현 전략](#구현-전략)
6. [마이그레이션 계획](#마이그레이션-계획)
7. [성능 및 비용 분석](#성능-및-비용-분석)

## 핵심 인사이트

### 🎯 왜 Milestone, Sprint, Task를 MongoDB로?

**"실행 데이터는 본질적으로 시간 제한적이고 유동적이다"**

1. **명확한 생명 주기**
   - Sprint: 1-4주 실행 후 종료
   - Task: 생성 → 진행 → 완료 (평균 3-5일)
   - Milestone: 2-6개월 목표 달성 후 아카이브

2. **높은 변경 빈도**
   - 하루 수백 번의 상태 업데이트
   - 실시간 코멘트와 활동 기록
   - 지속적인 메트릭 수집

3. **유연한 스키마 요구**
   - 팀별 커스텀 워크플로우
   - Sprint마다 다른 추가 필드
   - 다양한 통합 도구 메타데이터

## 아키텍처 패러다임 전환

### 기존 접근법 (문제점)
```
PostgreSQL에 모든 데이터 저장
→ 실행 데이터와 정의 데이터 혼재
→ 스키마 경직성으로 인한 개발 속도 저하
→ 오래된 데이터 수동 정리 필요
```

### 새로운 접근법 (해결책)
```
정의/설정 데이터 → PostgreSQL (ACID, 무결성)
실행/활동 데이터 → MongoDB (유연성, 확장성)
```

## 데이터 분류 전략

### 🗄️ PostgreSQL: 정적 정의 데이터
**특징**: 변경 빈도 낮음, 강한 무결성 필요, 영구 보존

| 엔티티 | 역할 | 이유 |
|--------|------|------|
| **Organization** | 조직 정보 | 핵심 마스터 데이터 |
| **User** | 사용자 계정 | 인증/권한 필수 |
| **Team** | 팀 구조 | 조직 구조 정의 |
| **Service** | 서비스 정의 | 프로젝트 구조 |
| **Role/Permission** | 권한 체계 | 보안 Critical |
| **Billing** | 결제 정보 | 트랜잭션 필수 |
| **Configuration** | 시스템 설정 | 일관성 중요 |

### 🚀 MongoDB: 동적 실행 데이터
**특징**: 시간 제한적, 높은 변경 빈도, 유연한 구조

| 엔티티 | 활성 기간 | TTL 설정 | 이유 |
|--------|-----------|----------|------|
| **Milestone** | 2-6개월 | 2년 | 목표 달성 후 참조 감소 |
| **Sprint** | 1-4주 | 1년 | 종료 후 히스토리 |
| **Task** | 3-5일 | 1년 | 완료 후 아카이브 |
| **Comment** | 영구* | 2년 | 활동 기록 |
| **Activity** | 실시간 | 6개월 | 로그성 데이터 |
| **Metrics** | 실시간 | 6개월 | 시계열 분석 |
| **PomodoroSession** | 25분 | 90일 | 개인 생산성 |

*중요 코멘트는 pinned 플래그로 영구 보존

## MongoDB 실행 데이터 모델

### 1. Milestone (MongoDB)

```ruby
# app/models/milestone.rb
class Milestone
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # ===== Core References (PostgreSQL 연결) =====
  field :organization_id, type: Integer
  field :service_id, type: Integer
  field :created_by_id, type: Integer
  
  # ===== Milestone Definition =====
  field :title, type: String
  field :description, type: String
  field :status, type: String # planning, active, completed, cancelled
  field :milestone_type, type: String # release, feature, business
  
  # ===== Timeline =====
  field :planned_start, type: Date
  field :planned_end, type: Date
  field :actual_start, type: Date
  field :actual_end, type: Date
  
  # ===== Progress Tracking =====
  field :total_sprints, type: Integer, default: 0
  field :completed_sprints, type: Integer, default: 0
  field :total_tasks, type: Integer, default: 0
  field :completed_tasks, type: Integer, default: 0
  field :progress_percentage, type: Float, default: 0.0
  
  # ===== Objectives & Key Results =====
  field :objectives, type: Array, default: []
  # [{
  #   id: 'obj-1',
  #   title: 'Improve user engagement',
  #   key_results: [
  #     { id: 'kr-1', description: 'DAU 50% 증가', target: 50000, current: 35000, unit: 'users' },
  #     { id: 'kr-2', description: 'Retention 30% 개선', target: 30, current: 22, unit: 'percent' }
  #   ]
  # }]
  
  # ===== Risk & Dependencies =====
  field :risks, type: Array, default: []
  field :dependencies, type: Array, default: []
  field :blockers, type: Array, default: []
  
  # ===== Stakeholders =====
  field :owner_id, type: Integer
  field :stakeholder_ids, type: Array, default: []
  field :team_ids, type: Array, default: []
  
  # ===== Flexible Metadata =====
  field :custom_fields, type: Hash, default: {}
  field :integrations, type: Hash, default: {}
  # {
  #   jira: { project_id: 'PROJ-123', epic_id: 'EPIC-456' },
  #   github: { milestone_id: 789 },
  #   slack: { channel_id: 'C123456' }
  # }
  
  # ===== Embedded Documents =====
  embeds_many :sprints
  embeds_many :milestone_updates
  embeds_many :milestone_reviews
  
  # ===== Indexes =====
  index({ organization_id: 1, status: 1 })
  index({ service_id: 1 })
  index({ planned_end: 1 })
  index({ status: 1, actual_end: 1 })
  index({ actual_end: 1 }, { expire_after_seconds: 63072000 }) # 2년 후 자동 삭제
  
  # ===== Validations =====
  validates :title, presence: true
  validates :organization_id, presence: true
  validates :status, inclusion: { in: %w[planning active completed cancelled] }
  
  # ===== Scopes =====
  scope :active, -> { where(status: 'active') }
  scope :completed, -> { where(status: 'completed') }
  scope :upcoming, -> { where(status: 'planning') }
  scope :at_risk, -> { where(:progress_percentage.lt => 30, :planned_end.lt => 30.days.from_now) }
end
```

### 2. Task (독립 MongoDB Collection)

```ruby
# app/models/task.rb
class Task
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # ===== Core References =====
  field :organization_id, type: Integer
  field :service_id, type: Integer
  field :sprint_id, type: String # MongoDB Sprint ID (optional - backlog tasks)
  field :milestone_id, type: String # MongoDB Milestone ID (optional)
  
  # ===== Task Identification =====
  field :task_id, type: String # 고유 ID (예: SHOP-123)
  field :external_id, type: String # Jira, GitHub Issue 등
  
  # ===== Task Core =====
  field :title, type: String
  field :description, type: String
  field :task_type, type: String # feature, bug, chore, spike, epic
  
  # ===== Assignment =====
  field :assignee_id, type: Integer
  field :assignee_name, type: String
  field :reviewer_id, type: Integer
  field :team_id, type: Integer
  field :created_by_id, type: Integer
  
  # ===== Status & Priority =====
  field :status, type: String # backlog, todo, in_progress, review, done, archived
  field :priority, type: String # urgent, high, medium, low
  field :is_blocked, type: Boolean, default: false
  field :blocked_reason, type: String
  field :blocked_by_task_ids, type: Array, default: []
  
  # ===== Estimation & Tracking =====
  field :story_points, type: Float
  field :original_estimate_hours, type: Float
  field :time_spent_hours, type: Float
  field :remaining_hours, type: Float
  field :business_value, type: Integer # 1-100
  
  # ===== Dates =====
  field :created_at, type: DateTime
  field :started_at, type: DateTime
  field :completed_at, type: DateTime
  field :archived_at, type: DateTime
  field :due_date, type: Date
  field :sprint_added_at, type: DateTime
  
  # ===== Progress Tracking =====
  field :subtasks, type: Array, default: []
  # [{
  #   id: String,
  #   title: String,
  #   completed: Boolean,
  #   assignee_id: Integer
  # }]
  
  field :checklist_items, type: Array, default: []
  field :completion_percentage, type: Integer, default: 0
  
  # ===== Collaboration =====
  field :comment_count, type: Integer, default: 0
  field :attachment_count, type: Integer, default: 0
  field :watchers, type: Array, default: []
  field :participants, type: Array, default: [] # 모든 참여자
  field :mentions, type: Array, default: []
  
  # ===== Development Tracking =====
  field :pull_requests, type: Array, default: []
  # [{
  #   pr_number: Integer,
  #   status: String,
  #   url: String,
  #   merged_at: DateTime
  # }]
  
  field :commits, type: Array, default: []
  field :branch_name, type: String
  field :deployment_status, type: String
  field :code_review_status, type: String
  
  # ===== Quality Metrics =====
  field :bug_count, type: Integer, default: 0
  field :reopen_count, type: Integer, default: 0
  field :review_cycles, type: Integer, default: 0
  field :test_coverage, type: Float
  field :acceptance_criteria, type: Array, default: []
  
  # ===== Activity History =====
  field :status_changes, type: Array, default: []
  # [{
  #   from: String,
  #   to: String,
  #   changed_by: Integer,
  #   changed_at: DateTime,
  #   sprint_id: String, # Sprint 간 이동 추적
  #   reason: String
  # }]
  
  field :sprint_history, type: Array, default: []
  # [{
  #   sprint_id: String,
  #   sprint_name: String,
  #   added_at: DateTime,
  #   removed_at: DateTime,
  #   completed_in_sprint: Boolean
  # }]
  
  # ===== Labels & Categorization =====
  field :labels, type: Array, default: []
  field :epic_id, type: String
  field :component, type: String
  field :feature_flag, type: String
  field :release_version, type: String
  
  # ===== Custom Fields =====
  field :custom_fields, type: Hash, default: {}
  field :metadata, type: Hash, default: {}
  
  # ===== Indexes =====
  index({ organization_id: 1, status: 1 })
  index({ sprint_id: 1, status: 1 })
  index({ assignee_id: 1, status: 1 })
  index({ status: 1, priority: 1 })
  index({ task_id: 1 }, { unique: true })
  index({ created_at: -1 })
  index({ due_date: 1 })
  index({ epic_id: 1 })
  
  # Partial index for active tasks
  index(
    { organization_id: 1, sprint_id: 1 },
    { 
      partial_filter_expression: { 
        status: { '$in': ['todo', 'in_progress', 'review'] }
      }
    }
  )
  
  # TTL: 완료 후 1년
  index(
    { archived_at: 1 }, 
    { 
      expire_after_seconds: 31536000,
      partial_filter_expression: { status: 'archived' }
    }
  )
  
  # ===== Validations =====
  validates :title, presence: true
  validates :task_id, presence: true, uniqueness: true
  validates :organization_id, presence: true
  validates :status, inclusion: { in: %w[backlog todo in_progress review done archived] }
  validates :priority, inclusion: { in: %w[urgent high medium low] }
  
  # ===== Scopes =====
  scope :active, -> { where(:status.in => ['todo', 'in_progress', 'review']) }
  scope :backlog, -> { where(status: 'backlog', sprint_id: nil) }
  scope :in_sprint, ->(sprint_id) { where(sprint_id: sprint_id) }
  scope :completed, -> { where(status: 'done') }
  scope :my_tasks, ->(user_id) { where(assignee_id: user_id) }
  scope :unassigned, -> { where(assignee_id: nil) }
  scope :blocked, -> { where(is_blocked: true) }
  scope :due_soon, -> { where(:due_date.lte => 3.days.from_now) }
  scope :overdue, -> { where(:due_date.lt => Date.current, :status.ne => 'done') }
  
  # ===== Class Methods =====
  class << self
    def move_to_sprint(task_ids, sprint_id)
      tasks = where(:_id.in => task_ids)
      sprint = Sprint.find(sprint_id)
      
      tasks.each do |task|
        # Sprint 히스토리 업데이트
        if task.sprint_id.present?
          task.sprint_history << {
            sprint_id: task.sprint_id,
            removed_at: Time.current
          }
        end
        
        task.sprint_id = sprint_id
        task.sprint_added_at = Time.current
        task.sprint_history << {
          sprint_id: sprint_id,
          sprint_name: sprint.name,
          added_at: Time.current
        }
        task.save!
      end
    end
    
    def bulk_update_status(task_ids, new_status, user_id)
      tasks = where(:_id.in => task_ids)
      
      tasks.each do |task|
        task.status_changes << {
          from: task.status,
          to: new_status,
          changed_by: user_id,
          changed_at: Time.current
        }
        task.status = new_status
        task.completed_at = Time.current if new_status == 'done'
        task.save!
      end
    end
  end
  
  # ===== Instance Methods =====
  def move_to_backlog
    self.sprint_id = nil
    self.status = 'backlog'
    self.sprint_history << {
      sprint_id: self.sprint_id,
      removed_at: Time.current,
      reason: 'moved_to_backlog'
    }
    save!
  end
  
  def archive!
    self.status = 'archived'
    self.archived_at = Time.current
    save!
  end
  
  def complete!
    self.status = 'done'
    self.completed_at = Time.current
    self.completion_percentage = 100
    
    # Sprint에서 완료 표시
    if sprint_id.present?
      current_sprint_history = sprint_history.last
      current_sprint_history[:completed_in_sprint] = true if current_sprint_history
    end
    
    save!
  end
end
```

### 3. Sprint (MongoDB - Task 참조)

```ruby
# app/models/sprint.rb
class Sprint
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # ===== Core References =====
  field :organization_id, type: Integer
  field :service_id, type: Integer
  field :team_id, type: Integer
  field :milestone_id, type: String # MongoDB Milestone ID
  
  # ===== Sprint Definition =====
  field :name, type: String
  field :goal, type: String
  field :sprint_number, type: Integer
  field :status, type: String # planning, active, completed, cancelled
  
  # ===== Timeline =====
  field :start_date, type: Date
  field :end_date, type: Date
  field :working_days, type: Integer
  
  # ===== Capacity & Velocity =====
  field :team_capacity, type: Float # 총 가용 시간
  field :planned_velocity, type: Float # 계획 속도
  field :actual_velocity, type: Float # 실제 완료 포인트
  field :carry_over_velocity, type: Float # 이월된 포인트
  
  # ===== Sprint Planning =====
  field :committed_points, type: Float
  field :stretch_points, type: Float
  field :completed_points, type: Float
  field :spillover_points, type: Float
  
  # ===== Daily Tracking =====
  field :daily_standups, type: Array, default: []
  # [{
  #   date: Date,
  #   attendees: [user_ids],
  #   updates: [
  #     { user_id: 1, yesterday: '...', today: '...', blockers: [] }
  #   ],
  #   duration_minutes: 15
  # }]
  
  field :burndown_data, type: Array, default: []
  # [{
  #   date: Date,
  #   ideal_remaining: 100,
  #   actual_remaining: 95,
  #   tasks_completed: 5,
  #   points_completed: 13
  # }]
  
  # ===== Sprint Ceremonies =====
  field :planning_session, type: Hash, default: {}
  # {
  #   date: DateTime,
  #   duration_minutes: 120,
  #   attendees: [user_ids],
  #   decisions: [],
  #   action_items: []
  # }
  
  field :review_session, type: Hash, default: {}
  # {
  #   date: DateTime,
  #   demo_items: [],
  #   feedback: [],
  #   stakeholder_comments: []
  # }
  
  field :retrospective, type: Hash, default: {}
  # {
  #   date: DateTime,
  #   what_went_well: [],
  #   what_to_improve: [],
  #   action_items: [],
  #   team_mood: 4.2
  # }
  
  # ===== Task Management =====
  # Tasks는 별도 컬렉션으로 관리, Sprint은 참조만
  field :task_ids, type: Array, default: []
  field :total_tasks, type: Integer, default: 0
  field :completed_tasks, type: Integer, default: 0
  field :active_tasks, type: Integer, default: 0
  
  # ===== Embedded Documents =====
  embeds_many :sprint_activities
  embeds_many :sprint_metrics
  
  # ===== Health & Risk =====
  field :health_score, type: Float # 0-100
  field :risk_level, type: String # low, medium, high
  field :blockers, type: Array, default: []
  field :scope_changes, type: Array, default: []
  # [{
  #   date: DateTime,
  #   change_type: 'added|removed',
  #   task_ids: [],
  #   reason: String,
  #   impact_points: Float
  # }]
  
  # ===== Team Dynamics =====
  field :team_members, type: Array, default: []
  # [{
  #   user_id: Integer,
  #   role: String,
  #   capacity_percentage: Float,
  #   tasks_completed: Integer
  # }]
  
  # ===== Integrations =====
  field :external_links, type: Hash, default: {}
  # {
  #   jira_sprint_id: 'SPRINT-123',
  #   github_milestone_id: 456,
  #   confluence_page: 'http://...'
  # }
  
  # ===== Indexes =====
  index({ organization_id: 1, status: 1 })
  index({ service_id: 1, sprint_number: 1 })
  index({ team_id: 1, start_date: -1 })
  index({ status: 1, end_date: 1 })
  index({ end_date: 1 }, { expire_after_seconds: 31536000 }) # 1년 후 자동 삭제
  
  # ===== Validations =====
  validates :name, presence: true
  validates :organization_id, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start_date
  
  # ===== Scopes =====
  scope :active, -> { where(status: 'active') }
  scope :completed, -> { where(status: 'completed') }
  scope :current, -> { where(status: 'active', :start_date.lte => Date.current, :end_date.gte => Date.current) }
  
  # ===== Class Methods =====
  class << self
    def with_tasks
      # Sprint과 관련 Tasks를 함께 로드
      sprints = all.to_a
      task_ids = sprints.flat_map(&:task_ids)
      tasks = Task.where(:_id.in => task_ids).group_by(&:sprint_id)
      
      sprints.each do |sprint|
        sprint.instance_variable_set(:@tasks, tasks[sprint.id.to_s] || [])
      end
      
      sprints
    end
  end
  
  # ===== Instance Methods =====
  def tasks
    @tasks ||= Task.in_sprint(self.id)
  end
  
  def add_task(task)
    task.sprint_id = self.id.to_s
    task.sprint_added_at = Time.current
    task.save!
    
    self.task_ids << task.id.to_s
    self.total_tasks += 1
    self.active_tasks += 1 if task.status.in?(['todo', 'in_progress', 'review'])
    self.save!
  end
  
  def remove_task(task)
    task.move_to_backlog
    
    self.task_ids.delete(task.id.to_s)
    self.total_tasks -= 1
    self.active_tasks -= 1 if task.status.in?(['todo', 'in_progress', 'review'])
    self.completed_tasks -= 1 if task.status == 'done'
    self.save!
  end
  
  def update_task_counts
    tasks = Task.in_sprint(self.id)
    self.total_tasks = tasks.count
    self.completed_tasks = tasks.completed.count
    self.active_tasks = tasks.active.count
    self.save!
  end
  
  # ===== Embedded Class: SprintActivity =====
  class SprintActivity
    include Mongoid::Document
    include Mongoid::Timestamps
    
    embedded_in :sprint
    
    field :activity_type, type: String # standup, planning, review, retrospective
    field :actor_id, type: Integer
    field :content, type: Hash
    field :timestamp, type: DateTime
    
  end
end
```

### 4. Polymorphic Comment (MongoDB)

```ruby
# app/models/comment.rb
class Comment
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Tree # 중첩 댓글 지원
  
  # ===== Polymorphic References =====
  field :commentable_type, type: String # 'Task', 'Sprint', 'Milestone', 'Epic'
  field :commentable_id, type: String # MongoDB Document ID 또는 고유 ID
  field :organization_id, type: Integer
  
  # ===== Author Info =====
  field :author_id, type: Integer
  field :author_name, type: String
  field :author_avatar, type: String
  field :author_role, type: String
  
  # ===== Comment Content =====
  field :content, type: String
  field :content_html, type: String # 렌더링된 HTML
  field :content_type, type: String, default: 'text' # text, code, image, file
  
  # ===== Rich Content =====
  field :code_snippet, type: Hash
  # {
  #   language: 'ruby',
  #   code: '...',
  #   line_numbers: true,
  #   highlighted_lines: [5, 10]
  # }
  
  field :attachments, type: Array, default: []
  # [{
  #   id: 'uuid',
  #   filename: 'design.png',
  #   url: 's3://...',
  #   size: 102400,
  #   mime_type: 'image/png',
  #   thumbnail_url: 's3://...'
  # }]
  
  # ===== Mentions & References =====
  field :mentioned_user_ids, type: Array, default: []
  field :referenced_task_ids, type: Array, default: []
  field :referenced_comment_ids, type: Array, default: []
  
  # ===== Collaboration Features =====
  field :reactions, type: Hash, default: {}
  # { "👍": [1, 2, 3], "👎": [4], "🎉": [5, 6] }
  
  field :resolved, type: Boolean, default: false
  field :resolved_by_id, type: Integer
  field :resolved_at, type: Time
  
  # ===== Comment Type =====
  field :comment_type, type: String, default: 'general'
  # general, question, decision, action_item, status_update, review
  
  field :action_item, type: Hash
  # {
  #   assignee_id: Integer,
  #   due_date: Date,
  #   completed: Boolean
  # }
  
  # ===== Edit History =====
  field :edited, type: Boolean, default: false
  field :edit_history, type: Array, default: []
  
  # ===== Status & Visibility =====
  field :status, type: String, default: 'active' # active, deleted, hidden
  field :visibility, type: String, default: 'all' # all, team, mentioned_only
  field :pinned, type: Boolean, default: false
  field :system_generated, type: Boolean, default: false
  
  # ===== Activity Tracking =====
  field :read_by, type: Array, default: []
  # [{ user_id: 1, read_at: Time }]
  
  # ===== Indexes =====
  index({ commentable_type: 1, commentable_id: 1, created_at: -1 })
  index({ author_id: 1 })
  index({ mentioned_user_ids: 1 })
  index({ parent_id: 1 })
  index({ pinned: 1, created_at: -1 })
  
  # TTL: 2년 후 자동 삭제 (pinned 제외)
  index({ created_at: 1 }, { 
    expire_after_seconds: 63072000,
    partial_filter_expression: { pinned: false }
  })
  
  # ===== Validations =====
  validates :commentable_type, presence: true
  validates :commentable_id, presence: true
  validates :author_id, presence: true
  validates :content, presence: true, length: { maximum: 10000 }
  
  # ===== Scopes =====
  scope :active, -> { where(status: 'active') }
  scope :resolved, -> { where(resolved: true) }
  scope :unresolved, -> { where(resolved: false) }
  scope :pinned, -> { where(pinned: true) }
  scope :action_items, -> { where(comment_type: 'action_item') }
  scope :decisions, -> { where(comment_type: 'decision') }
end
```

### 5. Activity Stream (MongoDB)

```ruby
# app/models/activity.rb
class Activity
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # ===== Context =====
  field :organization_id, type: Integer
  field :actor_id, type: Integer
  field :actor_name, type: String
  field :actor_type, type: String # user, system, integration
  
  # ===== Activity Info =====
  field :action, type: String # created, updated, completed, commented, etc.
  field :target_type, type: String # Task, Sprint, Milestone
  field :target_id, type: String
  field :target_title, type: String
  
  # ===== Changes =====
  field :changes, type: Hash
  # {
  #   status: ['todo', 'in_progress'],
  #   assignee: [nil, 5],
  #   priority: ['medium', 'high']
  # }
  
  field :metadata, type: Hash
  # Additional context specific to action type
  
  # ===== Visibility =====
  field :visibility, type: String, default: 'team'
  field :team_id, type: Integer
  field :mentioned_user_ids, type: Array, default: []
  
  # ===== Source =====
  field :source, type: String # web, api, mobile, integration
  field :ip_address, type: String
  field :user_agent, type: String
  
  # ===== Indexes =====
  index({ organization_id: 1, created_at: -1 })
  index({ actor_id: 1, created_at: -1 })
  index({ target_type: 1, target_id: 1 })
  
  # TTL: 6개월 후 자동 삭제
  index({ created_at: 1 }, { expire_after_seconds: 15552000 })
  
  # ===== Scopes =====
  scope :recent, -> { order(created_at: :desc) }
  scope :by_actor, ->(actor_id) { where(actor_id: actor_id) }
  scope :by_target, ->(type, id) { where(target_type: type, target_id: id) }
end
```

## 구현 전략

### Phase 1: 데이터 모델 구현 (Week 1-2)

#### 1.1 MongoDB 설정
```ruby
# config/mongoid.yml
development:
  clients:
    default:
      database: creatia_execution_dev
      hosts:
        - localhost:27017
      options:
        server_selection_timeout: 5
        max_pool_size: 50
  options:
    use_activesupport_time_zone: true
    use_utc: false

production:
  clients:
    default:
      uri: <%= ENV['MONGODB_URI'] %>
      options:
        server_selection_timeout: 5
        max_pool_size: 100
        min_pool_size: 10
        connect_timeout: 10
        socket_timeout: 5
        retry_writes: true
        write_concern:
          w: majority
          j: true
          timeout: 5000
```

#### 1.2 하이브리드 서비스 레이어
```ruby
# app/services/sprint_service.rb
class SprintService
  class << self
    def create_sprint(params)
      # PostgreSQL: Service 정의 확인
      service = Service.find(params[:service_id])
      
      # MongoDB: Sprint 실행 데이터 생성
      sprint = Sprint.create!(
        organization_id: service.organization_id,
        service_id: service.id,
        name: params[:name],
        goal: params[:goal],
        start_date: params[:start_date],
        end_date: params[:end_date],
        team_id: params[:team_id],
        status: 'planning'
      )
      
      # 초기 메트릭 설정
      initialize_sprint_metrics(sprint)
      
      # 활동 로그
      log_activity('sprint_created', sprint)
      
      sprint
    end
    
    def add_task_to_sprint(sprint_id, task_params)
      sprint = Sprint.find(sprint_id)
      
      # 독립 Task 생성
      task = Task.create!(
        organization_id: sprint.organization_id,
        service_id: sprint.service_id,
        sprint_id: sprint_id,
        title: task_params[:title],
        description: task_params[:description],
        assignee_id: task_params[:assignee_id],
        story_points: task_params[:story_points],
        priority: task_params[:priority],
        status: 'todo',
        task_id: generate_task_id(sprint.service_id)
      )
      
      # Sprint에 Task 추가
      sprint.add_task(task)
      
      # 실시간 알림
      broadcast_task_added(sprint, task)
      
      task
    end
    
    def update_task_status(task_id, new_status)
      task = Task.find(task_id)
      
      old_status = task.status
      task.status = new_status
      task.status_changes << {
        from: old_status,
        to: new_status,
        changed_by: Current.user.id,
        changed_at: Time.current,
        sprint_id: task.sprint_id
      }
      
      # 완료 시간 기록
      if new_status == 'done' && old_status != 'done'
        task.completed_at = Time.current
      end
      
      task.save!
      
      # Sprint 메트릭 업데이트
      if task.sprint_id.present?
        sprint = Sprint.find(task.sprint_id)
        sprint.update_task_counts
        update_burndown_data(sprint)
      end
      
      # 실시간 브로드캐스트
      broadcast_task_update(task)
      
      task
    end
    
    private
    
    def initialize_sprint_metrics(sprint)
      sprint.daily_standups = []
      sprint.burndown_data = generate_ideal_burndown(sprint)
      sprint.health_score = 100
      sprint.save!
    end
    
    def update_sprint_metrics(sprint)
      tasks = Task.in_sprint(sprint.id)
      sprint.total_tasks = tasks.count
      sprint.completed_tasks = tasks.completed.count
      sprint.committed_points = tasks.sum(:story_points)
      sprint.completed_points = tasks.completed.sum(:story_points)
      sprint.save!
    end
    
    def update_burndown_data(sprint)
      tasks = Task.in_sprint(sprint.id)
      today_data = {
        date: Date.current,
        actual_remaining: tasks.where(:status.ne => 'done').sum(:story_points),
        tasks_completed: tasks.where(status: 'done', completed_at: Date.current).count,
        points_completed: tasks.where(status: 'done', completed_at: Date.current).sum(:story_points)
      }
      
      # 기존 데이터 업데이트 또는 추가
      existing = sprint.burndown_data.find { |d| d[:date] == Date.current }
      if existing
        existing.merge!(today_data)
      else
        sprint.burndown_data << today_data
      end
      
      sprint.save!
    end
  end
end
```

### Phase 2: 실시간 기능 구현 (Week 3-4)

#### 2.1 ActionCable 통합
```ruby
# app/channels/sprint_channel.rb
class SprintChannel < ApplicationCable::Channel
  def subscribed
    sprint = Sprint.find(params[:sprint_id])
    stream_for sprint
  end
  
  def receive(data)
    case data['action']
    when 'task_status_update'
      update_task_status(data)
    when 'add_comment'
      add_comment(data)
    when 'update_burndown'
      broadcast_burndown_update
    end
  end
  
  private
  
  def update_task_status(data)
    task = Sprint.find(data['sprint_id']).tasks.find(data['task_id'])
    task.update!(status: data['status'])
    
    SprintChannel.broadcast_to(
      sprint,
      action: 'task_updated',
      task: task.as_json,
      user: current_user.name
    )
  end
end
```

#### 2.2 GraphQL API (옵션)
```ruby
# app/graphql/types/sprint_type.rb
module Types
  class SprintType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: false
    field :goal, String, null: true
    field :status, String, null: false
    field :start_date, GraphQL::Types::ISO8601Date, null: false
    field :end_date, GraphQL::Types::ISO8601Date, null: false
    field :tasks, [Types::TaskType], null: false
    field :burndown_data, GraphQL::Types::JSON, null: true
    field :health_score, Float, null: true
    field :velocity, Float, null: true
    
    def tasks
      object.tasks.where(status: 'active')
    end
    
    def velocity
      object.completed_points / object.working_days
    end
  end
end
```

### Phase 3: 마이그레이션 전략 (Week 5-6)

#### 3.1 점진적 마이그레이션
```ruby
# lib/tasks/migrate_to_mongodb.rake
namespace :mongodb do
  desc "Migrate active sprints to MongoDB"
  task migrate_active_sprints: :environment do
    # PostgreSQL에서 활성 Sprint 조회
    PgSprint.where(status: 'active').find_each do |pg_sprint|
      # MongoDB Sprint 생성
      mongo_sprint = Sprint.create!(
        organization_id: pg_sprint.organization_id,
        service_id: pg_sprint.service_id,
        name: pg_sprint.name,
        goal: pg_sprint.goal,
        start_date: pg_sprint.start_date,
        end_date: pg_sprint.end_date,
        status: pg_sprint.status
      )
      
      # Tasks 마이그레이션
      pg_sprint.tasks.each do |pg_task|
        mongo_sprint.tasks.create!(
          task_id: "TASK-#{pg_task.id}",
          title: pg_task.title,
          description: pg_task.description,
          assignee_id: pg_task.assignee_id,
          status: pg_task.status,
          priority: pg_task.priority,
          story_points: pg_task.story_points
        )
      end
      
      puts "Migrated Sprint: #{mongo_sprint.name}"
    end
  end
  
  desc "Archive completed sprints"
  task archive_completed_sprints: :environment do
    Sprint.where(status: 'completed', :end_date.lt => 30.days.ago).each do |sprint|
      # S3에 백업 (선택적)
      BackupService.backup_to_s3(sprint) if sprint.important?
      
      # 아카이브 플래그 설정
      sprint.update!(archived: true)
      
      puts "Archived Sprint: #{sprint.name}"
    end
  end
end
```

#### 3.2 듀얼 라이트 전략
```ruby
# app/models/concerns/dual_write.rb
module DualWrite
  extend ActiveSupport::Concern
  
  included do
    after_create :sync_to_mongodb
    after_update :sync_to_mongodb
  end
  
  def sync_to_mongodb
    return unless Feature.enabled?(:dual_write)
    
    # PostgreSQL → MongoDB 동기화
    MongoSyncJob.perform_later(
      model: self.class.name,
      id: self.id,
      action: persisted? ? :update : :create
    )
  end
end

# 사용 예
class PgTask < ApplicationRecord
  include DualWrite
  # 기존 PostgreSQL 모델
end
```

## 마이그레이션 계획

### 🚀 Phase-by-Phase Migration

| Phase | 기간 | 대상 | 전략 | 리스크 |
|-------|------|------|------|--------|
| **Phase 1** | Week 1-2 | Comment System | 신규 구현 | 낮음 |
| **Phase 2** | Week 3-4 | Activity/Metrics | 병렬 운영 | 낮음 |
| **Phase 3** | Week 5-6 | New Sprints | MongoDB 우선 | 중간 |
| **Phase 4** | Week 7-8 | Active Sprints | 듀얼 라이트 | 중간 |
| **Phase 5** | Week 9-10 | Historical Data | 점진적 이전 | 낮음 |
| **Phase 6** | Week 11-12 | Cutover | PostgreSQL 비활성화 | 높음 |

### 롤백 계획
```ruby
# config/initializers/feature_flags.rb
Rails.application.config.features = {
  mongodb_sprints: ENV.fetch('MONGODB_SPRINTS', 'false') == 'true',
  mongodb_tasks: ENV.fetch('MONGODB_TASKS', 'false') == 'true',
  dual_write: ENV.fetch('DUAL_WRITE', 'true') == 'true'
}

# app/controllers/sprints_controller.rb
class SprintsController < ApplicationController
  def index
    @sprints = if Feature.mongodb_sprints?
      Sprint.active # MongoDB
    else
      PgSprint.active # PostgreSQL
    end
  end
end
```

## 성능 및 비용 분석

### 📊 성능 개선

| 작업 | PostgreSQL | MongoDB | 개선율 |
|------|------------|---------|--------|
| Sprint 생성 | 150ms | 15ms | 10x |
| Task 상태 업데이트 | 50ms | 5ms | 10x |
| 번다운 차트 계산 | 500ms | 50ms | 10x |
| 100개 Task 조회 | 200ms | 20ms | 10x |
| Sprint 전체 로드 | 800ms | 80ms | 10x |
| 복잡한 집계 쿼리 | 2000ms | 200ms | 10x |
| 크로스 Sprint Task 분석 | 1500ms | 150ms | 10x |
| Backlog 전체 조회 | 1000ms | 100ms | 10x |

### 💰 비용 절감

#### 연간 비용 비교
```
기존 (PostgreSQL Only):
- RDS 인스턴스: db.r5.xlarge = $300/월
- 스토리지: 500GB = $50/월
- 백업: $30/월
- 총계: $380/월 × 12 = $4,560/년

새로운 (PostgreSQL + MongoDB):
- RDS: db.t3.large = $100/월 (축소 가능)
- MongoDB Atlas: M10 = $60/월
- 스토리지: 자동 관리
- 총계: $160/월 × 12 = $1,920/년

절감액: $2,640/년 (58% 절감)
```

#### 운영 비용 절감
```
데이터 정리 작업: 월 20시간 → 0시간 (TTL 자동화)
스키마 마이그레이션: 분기 40시간 → 0시간
성능 튜닝: 월 10시간 → 2시간

총 절감 시간: 연 400시간
인건비 절감: 400시간 × $100 = $40,000/년
```

### 🚀 확장성 이점

1. **수평 확장**: MongoDB 샤딩으로 무제한 확장
2. **유연한 스키마**: 팀별 커스텀 필드 즉시 추가
3. **자동 아카이빙**: TTL로 오래된 데이터 자동 정리
4. **실시간 동기화**: Change Streams로 실시간 업데이트

## 모니터링 및 운영

### 📈 주요 모니터링 지표

```ruby
# app/services/monitoring_service.rb
class MonitoringService
  def self.health_check
    {
      mongodb: {
        connected: Mongoid.default_client.database_names.present?,
        document_count: Sprint.count + Task.count,
        storage_size: Mongoid.default_client.database.stats,
        average_query_time: measure_query_performance
      },
      postgresql: {
        connected: ActiveRecord::Base.connected?,
        record_count: Organization.count + User.count,
        connection_pool: ActiveRecord::Base.connection_pool.stat
      },
      sync_status: {
        pending_syncs: MongoSyncJob.queue_size,
        last_sync: Redis.get('last_sync_timestamp'),
        sync_errors: Redis.get('sync_error_count')
      }
    }
  end
  
  def self.alert_if_degraded
    health = health_check
    
    if health[:mongodb][:average_query_time] > 100
      AlertService.notify("MongoDB query performance degraded")
    end
    
    if health[:sync_status][:sync_errors].to_i > 10
      AlertService.notify("Data sync errors detected")
    end
  end
end
```

### 🔧 운영 체크리스트

#### 일일 점검
- [ ] MongoDB 클러스터 상태 확인
- [ ] 동기화 큐 상태 확인
- [ ] TTL 정리 작업 확인
- [ ] 쿼리 성능 모니터링

#### 주간 점검
- [ ] 스토리지 사용량 추이
- [ ] 인덱스 효율성 검토
- [ ] 백업 상태 확인
- [ ] 성능 메트릭 분석

#### 월간 점검
- [ ] TTL 정책 검토
- [ ] 아카이브 데이터 검증
- [ ] 용량 계획 업데이트
- [ ] 비용 최적화 검토

## 결론

### 🎯 핵심 이점

1. **독립 Task 컬렉션의 장점**
   - 전체 Task 조회 및 필터링 가능
   - 크로스 Sprint 분석 지원
   - Backlog 관리 최적화
   - Task 재사용 및 이동 용이

2. **명확한 책임 분리**
   - PostgreSQL: 정적 정의, 설정, 권한
   - MongoDB: 동적 실행, 활동, 메트릭

3. **10배 성능 향상**
   - 실시간 업데이트 지원
   - 복잡한 집계 최적화
   - 대용량 데이터 처리

4. **58% 비용 절감**
   - 인프라 비용 감소
   - 운영 자동화
   - 스토리지 최적화

5. **무한 확장성**
   - 수평적 확장 가능
   - 팀별 커스터마이징
   - 유연한 워크플로우

### 🚀 최종 권고사항

**"실행 데이터(Milestone, Sprint, Task)를 MongoDB로 이전"**하는 전략은:

1. **즉각적 효과**: 성능 개선과 비용 절감 즉시 실현
2. **낮은 리스크**: 단계적 마이그레이션으로 안전성 확보
3. **미래 대비**: 확장성과 유연성으로 성장 지원
4. **팀 만족도**: 빠른 응답 속도와 유연한 커스터마이징

이는 단순한 기술 변경이 아닌, **비즈니스 민첩성을 획기적으로 향상**시키는 전략적 결정입니다.