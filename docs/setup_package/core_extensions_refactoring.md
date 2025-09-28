# Core Extensions 및 유틸리티 Gem 리팩토링 Task

## 📋 개요

Creatia 프로젝트에 핵심 Ruby 유틸리티 gem들을 추가하여 코드 품질과 개발 생산성을 향상시킵니다. 특히 의존성 관리, 서비스 객체 패턴, 데이터 검증, 메모이제이션 최적화에 중점을 둡니다.

## 🎯 목표

- Rails ActiveSupport 핵심 기능 활용 극대화
- dry-rb 생태계를 통한 견고한 데이터 검증 구현
- 효율적인 메모이제이션과 캐싱 전략 적용
- 서비스 객체 패턴 간소화
- GitHub API 및 Webhook 데이터 처리 개선

## 📦 설치할 Gem 목록

### 필수 추천 ⭐⭐⭐⭐⭐

#### 1. dry-rb 생태계
```ruby
# Gemfile
gem 'dry-validation', '~> 1.10'
gem 'dry-struct', '~> 1.6'
gem 'dry-types', '~> 1.7'
gem 'dry-monads', '~> 1.6'
```

#### 2. MemoWise
```ruby
# Gemfile
gem 'memo_wise', '~> 1.8'
```

### 강력 추천 ⭐⭐⭐⭐

#### 3. Hashie
```ruby
# Gemfile
gem 'hashie', '~> 5.0'
```

#### 4. AttrExtras
```ruby
# Gemfile
gem 'attr_extras', '~> 7.1'
```

## 🔧 구현 예제

### 1. ActiveSupport 활용 (Rails 내장)

#### Task ID 생성 및 관리
```ruby
# app/models/task.rb
class Task < ApplicationRecord
  before_validation :generate_task_id, on: :create

  private

  def generate_task_id
    return if task_id.present?
    
    # SERVICE_PREFIX-NUMBER 형식
    prefix = service.prefix.upcase
    number = service.tasks.maximum(:task_number).to_i + 1
    
    self.task_number = number
    self.task_id = "#{prefix}-#{number}".parameterize.upcase
  end
end

# app/services/task_dependency_service.rb
class TaskDependencyService
  def blocking_tasks(task)
    # nil 안전 체이닝 활용
    task.try(:dependencies).try(:blocking_tasks) || []
  end
  
  def calculate_due_date(task, days_from_now)
    # 업무일 계산
    days_from_now.business_days.from_now
  end
  
  def cache_dependencies(organization_id)
    Rails.cache.fetch("org:#{organization_id}:dependencies", expires_in: 5.minutes) do
      calculate_dependency_graph(organization_id)
    end
  end
end
```

### 2. Dry-Validation을 통한 GitHub Webhook 검증

#### GitHub Webhook 페이로드 검증
```ruby
# app/contracts/github_webhook_contract.rb
require 'dry-validation'

class GithubWebhookContract < Dry::Validation::Contract
  params do
    required(:ref).filled(:string)
    required(:repository).hash do
      required(:name).filled(:string)
      required(:full_name).filled(:string)
    end
    optional(:commits).array(:hash) do
      required(:message).filled(:string)
      required(:author).hash do
        required(:name).filled(:string)
        required(:email).filled(:string)
      end
    end
  end
  
  rule(:ref) do
    # Task ID 형식 검증 (예: SHOP-142, PAY-23)
    unless value.match?(/[A-Z]+-\d+/)
      key.failure('브랜치명에 유효한 Task ID가 없습니다')
    end
  end
  
  rule(:commits).each do
    unless value[:message].match?(/\[?[A-Z]+-\d+\]?/)
      key.failure('커밋 메시지에 Task ID가 포함되어야 합니다')
    end
  end
end

# app/controllers/webhooks/github_controller.rb
class Webhooks::GithubController < ApplicationController
  def push
    contract = GithubWebhookContract.new
    result = contract.call(webhook_params)
    
    if result.success?
      ProcessGithubPushJob.perform_later(result.to_h)
      head :ok
    else
      render json: { errors: result.errors.to_h }, status: :unprocessable_entity
    end
  end
  
  private
  
  def webhook_params
    params.permit!.to_h
  end
end
```

### 3. Dry-Struct를 통한 Task 상태 관리

```ruby
# app/structs/task_status.rb
require 'dry-struct'

module Types
  include Dry.Types()
end

class TaskStatus < Dry::Struct
  attribute :state, Types::String.enum('todo', 'in_progress', 'blocked', 'review', 'done')
  attribute :blocked_by, Types::Array.of(Types::String).optional
  attribute :blocking, Types::Array.of(Types::String).optional
  attribute :assigned_to, Types::String.optional
  attribute :started_at, Types::Time.optional
  attribute :completed_at, Types::Time.optional
  
  def can_transition_to?(new_state)
    case state
    when 'todo'
      %w[in_progress blocked].include?(new_state)
    when 'in_progress'
      %w[blocked review done].include?(new_state)
    when 'blocked'
      %w[in_progress].include?(new_state)
    when 'review'
      %w[in_progress done].include?(new_state)
    when 'done'
      false # 완료된 태스크는 상태 변경 불가
    else
      false
    end
  end
end

# app/models/task.rb
class Task < ApplicationRecord
  def status
    @status ||= TaskStatus.new(
      state: state,
      blocked_by: blocked_by_task_ids,
      blocking: blocking_task_ids,
      assigned_to: assignee&.email,
      started_at: started_at,
      completed_at: completed_at
    )
  end
  
  def transition_to!(new_state)
    if status.can_transition_to?(new_state)
      update!(state: new_state)
    else
      errors.add(:state, "#{state}에서 #{new_state}로 전환할 수 없습니다")
      false
    end
  end
end
```

### 4. MemoWise를 통한 의존성 그래프 최적화

```ruby
# app/services/dependency_analyzer.rb
class DependencyAnalyzer
  prepend MemoWise
  
  def initialize(sprint)
    @sprint = sprint
    @tasks = sprint.tasks.includes(:dependencies, :dependents)
  end
  
  # 크리티컬 패스 계산 (복잡한 연산을 메모이제이션)
  memo_wise def critical_path
    return [] if @tasks.empty?
    
    # 의존성 그래프를 통한 최장 경로 계산
    end_tasks = @tasks.select { |t| t.dependents.empty? }
    
    paths = end_tasks.map do |task|
      calculate_path_to_start(task)
    end
    
    paths.max_by { |path| path.sum(&:estimated_hours) }
  end
  
  # 병목 지점 태스크 찾기
  memo_wise def bottleneck_tasks
    @tasks.select do |task|
      blocking_count = task.dependents.count
      blocked_by_count = task.dependencies.count
      
      # 많은 태스크를 블로킹하면서 자신도 블로킹당하는 태스크
      blocking_count >= 3 && blocked_by_count >= 1
    end.sort_by { |t| -t.dependents.count }
  end
  
  # 팀 벨로시티 기반 완료 예상일
  memo_wise def estimated_completion_date
    total_hours = critical_path.sum(&:estimated_hours)
    team_velocity = calculate_team_velocity
    
    working_days_needed = (total_hours / team_velocity).ceil
    working_days_needed.business_days.from_now
  end
  
  private
  
  memo_wise def calculate_path_to_start(task, visited = Set.new)
    return [] if visited.include?(task.id)
    visited.add(task.id)
    
    if task.dependencies.empty?
      [task]
    else
      longest_dep_path = task.dependencies.map do |dep|
        calculate_path_to_start(dep, visited.dup)
      end.max_by(&:length)
      
      longest_dep_path + [task]
    end
  end
  
  def calculate_team_velocity
    # 최근 3개 스프린트의 평균 벨로시티
    recent_sprints = @sprint.service.sprints
                            .completed
                            .order(end_date: :desc)
                            .limit(3)
    
    return 8.0 if recent_sprints.empty? # 기본값: 하루 8시간
    
    total_hours = recent_sprints.sum do |sprint|
      sprint.tasks.completed.sum(:actual_hours)
    end
    
    total_days = recent_sprints.sum do |sprint|
      sprint.start_date.business_days_until(sprint.end_date)
    end
    
    total_hours / total_days.to_f
  end
end

# 사용 예제
analyzer = DependencyAnalyzer.new(sprint)
critical_path = analyzer.critical_path
bottlenecks = analyzer.bottleneck_tasks
completion_date = analyzer.estimated_completion_date
```

### 5. Hashie를 통한 GitHub API 응답 처리

```ruby
# app/models/github_payload.rb
require 'hashie'

class GithubPayload < Hashie::Dash
  include Hashie::Extensions::IndifferentAccess
  include Hashie::Extensions::MethodAccess
  
  property :ref, required: true
  property :before
  property :after
  property :repository, required: true
  property :pusher
  property :sender
  property :created
  property :deleted
  property :forced
  property :commits, default: []
  property :head_commit
  
  def task_id
    # 브랜치명 또는 커밋 메시지에서 Task ID 추출
    branch_match = ref.match(/([A-Z]+-\d+)/)
    return branch_match[1] if branch_match
    
    # 커밋 메시지에서 찾기
    commits.each do |commit|
      message_match = commit['message'].match(/\[?([A-Z]+-\d+)\]?/)
      return message_match[1] if message_match
    end
    
    nil
  end
  
  def branch_name
    ref.gsub('refs/heads/', '')
  end
  
  def repository_full_name
    repository['full_name']
  end
  
  def author_email
    pusher['email'] || sender['email']
  end
end

# app/jobs/process_github_push_job.rb
class ProcessGithubPushJob < ApplicationJob
  def perform(webhook_data)
    payload = GithubPayload.new(webhook_data)
    
    return unless payload.task_id
    
    task = Task.find_by(task_id: payload.task_id)
    return unless task
    
    # GitHub 이벤트 기록
    task.github_events.create!(
      event_type: 'push',
      branch: payload.branch_name,
      repository: payload.repository_full_name,
      author: payload.author_email,
      commits_count: payload.commits.size,
      payload: webhook_data
    )
    
    # 태스크 상태 업데이트
    if task.state == 'todo' && payload.commits.any?
      task.transition_to!('in_progress')
    end
  end
end
```

### 6. AttrExtras를 통한 서비스 객체 간소화

```ruby
# app/services/create_task_with_branch_service.rb
class CreateTaskWithBranchService
  pattr_initialize :task_params, :user, :service
  
  def call
    validate!
    
    ActiveRecord::Base.transaction do
      create_task
      create_github_branch if github_integration_enabled?
      assign_to_sprint if sprint_id.present?
      notify_team
    end
    
    Result.success(task: task)
  rescue => e
    Result.failure(error: e.message)
  end
  
  private
  
  attr_reader :task
  
  memoize def github_client
    return nil unless github_integration_enabled?
    
    Octokit::Client.new(
      access_token: service.github_access_token
    )
  end
  
  def validate!
    raise ArgumentError, "서비스가 필요합니다" unless service
    raise ArgumentError, "사용자가 필요합니다" unless user
    raise ArgumentError, "제목이 필요합니다" if task_params[:title].blank?
  end
  
  def create_task
    @task = service.tasks.build(task_params)
    @task.creator = user
    @task.save!
  end
  
  def create_github_branch
    return unless github_client
    
    repo = service.github_repository
    default_branch = github_client.repository(repo).default_branch
    
    # Task ID를 포함한 브랜치명 생성
    branch_name = "#{task.task_id}-#{task.title.parameterize}"
    
    # 기본 브랜치의 최신 커밋 SHA 가져오기
    base_sha = github_client.ref(repo, "heads/#{default_branch}").object.sha
    
    # 새 브랜치 생성
    github_client.create_ref(
      repo,
      "refs/heads/#{branch_name}",
      base_sha
    )
    
    task.update!(github_branch: branch_name)
  end
  
  def github_integration_enabled?
    service.github_repository.present? && 
    service.github_access_token.present?
  end
  
  def sprint_id
    task_params[:sprint_id]
  end
  
  def assign_to_sprint
    sprint = service.sprints.find(sprint_id)
    task.update!(sprint: sprint)
  end
  
  def notify_team
    TaskCreatedNotificationJob.perform_later(task)
  end
  
  # Result 객체 (dry-monads 스타일)
  class Result
    attr_reader :success, :task, :error
    
    def self.success(task:)
      new(success: true, task: task)
    end
    
    def self.failure(error:)
      new(success: false, error: error)
    end
    
    def initialize(success:, task: nil, error: nil)
      @success = success
      @task = task
      @error = error
    end
    
    def success?
      @success
    end
    
    def failure?
      !@success
    end
  end
end

# 사용 예제
service = CreateTaskWithBranchService.new(
  task_params,
  current_user,
  current_service
)

result = service.call

if result.success?
  redirect_to result.task, notice: '태스크가 생성되었습니다'
else
  flash[:alert] = result.error
  render :new
end
```

### 7. 복합 예제: Sprint 관리 서비스

```ruby
# app/services/sprint_planning_service.rb
class SprintPlanningService
  extend AttrExtras.mixin
  prepend MemoWise
  
  pattr_initialize :sprint, :team_members
  
  def execute
    contract = SprintPlanningContract.new
    validation = contract.call(sprint_data)
    
    return validation.errors if validation.failure?
    
    ActiveRecord::Base.transaction do
      allocate_tasks
      calculate_capacity
      identify_risks
      generate_burndown_projection
    end
    
    SprintPlan.new(
      sprint: sprint,
      allocations: task_allocations,
      capacity: team_capacity,
      risks: identified_risks,
      burndown: burndown_projection
    )
  end
  
  private
  
  memo_wise def dependency_analyzer
    DependencyAnalyzer.new(sprint)
  end
  
  memo_wise def task_allocations
    allocator = TaskAllocator.new(
      tasks: sprint.tasks.pending,
      team_members: team_members,
      capacity: team_capacity
    )
    allocator.optimize_allocation
  end
  
  memo_wise def team_capacity
    team_members.sum do |member|
      working_hours = WorkingHours.for_team(member.team_id)
      working_hours.working_time_between(
        sprint.start_date,
        sprint.end_date
      ) / 1.hour
    end
  end
  
  def identify_risks
    risks = []
    
    # 의존성 리스크
    bottlenecks = dependency_analyzer.bottleneck_tasks
    if bottlenecks.any?
      risks << {
        type: 'dependency',
        severity: 'high',
        tasks: bottlenecks.map(&:task_id),
        message: "#{bottlenecks.count}개의 병목 태스크가 있습니다"
      }
    end
    
    # 용량 리스크
    total_estimated = sprint.tasks.sum(:estimated_hours)
    if total_estimated > team_capacity * 0.8 # 80% 이상 사용
      risks << {
        type: 'capacity',
        severity: 'medium',
        message: "예상 작업량이 팀 용량의 #{(total_estimated / team_capacity * 100).round}%입니다"
      }
    end
    
    risks
  end
  
  def generate_burndown_projection
    # 번다운 차트 예측 생성
    BurndownProjector.new(
      sprint: sprint,
      team_velocity: calculate_velocity,
      working_days: calculate_working_days
    ).project
  end
  
  memo_wise def calculate_velocity
    # 최근 3개 스프린트 평균 벨로시티
    recent_sprints = sprint.service.sprints
                           .completed
                           .order(end_date: :desc)
                           .limit(3)
    
    return 20 if recent_sprints.empty? # 기본값
    
    recent_sprints.average(:velocity).to_i
  end
  
  def calculate_working_days
    sprint.start_date.business_days_until(sprint.end_date)
  end
  
  def sprint_data
    {
      start_date: sprint.start_date,
      end_date: sprint.end_date,
      tasks_count: sprint.tasks.count,
      team_size: team_members.count
    }
  end
end

# Dry-Validation Contract
class SprintPlanningContract < Dry::Validation::Contract
  params do
    required(:start_date).filled(:date)
    required(:end_date).filled(:date)
    required(:tasks_count).filled(:integer)
    required(:team_size).filled(:integer)
  end
  
  rule(:end_date, :start_date) do
    if values[:end_date] <= values[:start_date]
      key(:end_date).failure('종료일은 시작일 이후여야 합니다')
    end
  end
  
  rule(:tasks_count) do
    if value == 0
      key.failure('스프린트에 최소 1개 이상의 태스크가 필요합니다')
    end
  end
  
  rule(:team_size) do
    if value == 0
      key.failure('스프린트에 최소 1명 이상의 팀원이 필요합니다')
    end
  end
end

# Result 구조체
class SprintPlan < Dry::Struct
  attribute :sprint, Types.Instance(Sprint)
  attribute :allocations, Types::Hash
  attribute :capacity, Types::Float
  attribute :risks, Types::Array.of(Types::Hash)
  attribute :burndown, Types::Hash
  
  def high_risk?
    risks.any? { |r| r[:severity] == 'high' }
  end
  
  def utilization_rate
    (allocations.values.sum / capacity * 100).round(2)
  end
end
```

## 🔄 마이그레이션 전략

### 기존 코드 리팩토링 단계

1. **Phase 1: 검증 레이어 추가**
   - 모든 외부 API 입력에 dry-validation 적용
   - GitHub webhook 페이로드 검증 우선 구현

2. **Phase 2: 서비스 객체 정리**
   - AttrExtras로 기존 서비스 객체 리팩토링
   - 보일러플레이트 코드 제거

3. **Phase 3: 메모이제이션 최적화**
   - 복잡한 계산 로직에 MemoWise 적용
   - 의존성 그래프, 벨로시티 계산 등

4. **Phase 4: 데이터 구조 개선**
   - Hashie로 API 응답 처리 통일
   - Dry::Struct로 도메인 객체 정의

## ⚙️ 설정 파일

### config/initializers/dry_validation.rb
```ruby
# frozen_string_literal: true

require 'dry-validation'

# 한국어 에러 메시지 설정
Dry::Validation.load_extensions(:hints)

# 기본 Contract 클래스
class ApplicationContract < Dry::Validation::Contract
  config.messages.default_locale = :ko
  config.messages.load_paths << Rails.root.join('config/locales/dry_validation.ko.yml')
end
```

### config/locales/dry_validation.ko.yml
```yaml
ko:
  dry_validation:
    errors:
      filled?: "필수 항목입니다"
      key?: "필수 필드입니다"
      format?: "형식이 올바르지 않습니다"
      size?:
        arg:
          default: "크기는 %{num}이어야 합니다"
          range: "크기는 %{left}에서 %{right} 사이여야 합니다"
      rules:
        task_id:
          format: "Task ID는 SHOP-123 형식이어야 합니다"
        email:
          format: "올바른 이메일 형식이 아닙니다"
```

## 📊 성능 개선 기대 효과

### 메모이제이션 (MemoWise)
- 복잡한 계산 50-90% 속도 향상
- 메모리 효율적인 캐싱
- 스레드 안전성 보장

### 검증 성능 (Dry-Validation)
- 스키마 기반 검증으로 10x 빠른 검증
- 조기 실패로 불필요한 처리 방지

### 개발 생산성
- 보일러플레이트 코드 60% 감소
- 타입 안전성으로 런타임 에러 감소
- 명확한 도메인 모델링

## ✅ 완료 조건

- [ ] Gemfile에 모든 gem 추가 및 bundle install
- [ ] dry-validation 초기화 설정
- [ ] GitHub webhook 검증 Contract 구현
- [ ] Task 상태 관리 Dry::Struct 구현
- [ ] DependencyAnalyzer에 MemoWise 적용
- [ ] GitHub API 응답 Hashie 모델 구현
- [ ] 서비스 객체 AttrExtras 리팩토링
- [ ] Sprint 계획 서비스 통합 구현
- [ ] 한국어 에러 메시지 설정
- [ ] 기존 코드 마이그레이션 (Phase 1-4)
- [ ] 단위 테스트 작성
- [ ] 통합 테스트 작성
- [ ] 성능 벤치마크 측정
- [ ] 문서화 완료

## 🔍 참고 자료

- [Dry-rb 공식 문서](https://dry-rb.org/)
- [Dry-validation 가이드](https://dry-rb.org/gems/dry-validation/)
- [MemoWise GitHub](https://github.com/panorama-ed/memo_wise)
- [Hashie GitHub](https://github.com/hashie/hashie)
- [AttrExtras GitHub](https://github.com/barsoom/attr_extras)
- [Rails ActiveSupport Core Extensions](https://guides.rubyonrails.org/active_support_core_extensions.html)

## 📅 예상 작업 시간

- 전체 구현: 8-10시간
- Phase 1 (검증): 2시간
- Phase 2 (서비스 객체): 2시간
- Phase 3 (메모이제이션): 2시간
- Phase 4 (데이터 구조): 2시간
- 테스트 및 문서화: 2시간

## 🚀 사용 예제

```ruby
# 새로운 태스크 생성 with GitHub 브랜치
result = CreateTaskWithBranchService.new(
  { title: "결제 시스템 개선", description: "..." },
  current_user,
  current_service
).call

if result.success?
  task = result.task
  puts "태스크 생성: #{task.task_id}"
else
  puts "에러: #{result.error}"
end

# 의존성 분석
analyzer = DependencyAnalyzer.new(current_sprint)
critical_path = analyzer.critical_path
puts "크리티컬 패스: #{critical_path.map(&:task_id).join(' -> ')}"
puts "예상 완료일: #{analyzer.estimated_completion_date}"

# Sprint 계획
planner = SprintPlanningService.new(sprint, team_members)
plan = planner.execute

if plan.high_risk?
  puts "⚠️ 고위험 스프린트: #{plan.risks}"
end
puts "팀 활용률: #{plan.utilization_rate}%"
```