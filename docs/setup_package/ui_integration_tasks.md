# UI Integration Tasks - Phase 1-4 구현 내용 통합

## 📋 프로젝트 개요

Phase 1-4에서 구현한 Core Extensions 기능들을 실제 사용자 인터페이스와 연결하는 통합 작업입니다.

### 🎯 목표
- Phase 1-4의 서비스, 구조체, 검증 로직을 실제 UI에 연결
- **모든 구성원**(개발자, 디자이너, PM, QA 등)이 사용할 수 있는 직관적인 UI 구현
- **GitHub 연동은 옵셔널** - 연동 없이도 완전한 기능 제공
- **ViewComponent + Stimulus + Hotwire (Turbo Frames & Streams)** 조합으로 SPA-like 경험 제공
- 실시간 메트릭 및 대시보드 구현
- **Trix 에디터** 기반 리치 텍스트 편집 지원

---

## 📚 Phase 1-4 구현 내용 요약

### ✅ Phase 1: 검증 레이어
- `GithubWebhookContract` - GitHub webhook 검증
- `ApplicationContract` - 기본 검증 클래스
- 한국어 에러 메시지 지원

### ✅ Phase 2: 서비스 객체
- `CreateTaskWithBranchService` - Task 생성 + GitHub 브랜치 생성
- `TaskStatus` - 타입 안전 상태 관리
- `ProcessGithubPushJob` - GitHub 이벤트 처리

### ✅ Phase 3: 메모이제이션
- `DependencyAnalyzer` - 스프린트 의존성 분석
- `SprintPlanningService` - 스프린트 계획 최적화
- `SprintPlan` - 계획 결과 구조체

### ✅ Phase 4: 데이터 구조
- `GithubPayload` - GitHub 데이터 처리
- `TaskMetrics` - 작업 성과 측정
- `TeamMetrics` - 팀 성과 지표
- `RiskAssessment` - 리스크 평가

---

## 🚀 통합 작업 계획

## Task 1: Task 관리 UI 강화 (ViewComponent + Turbo 기반)

### 1.1 Task 생성 폼 개선 (Turbo Streams + 옵셔널 GitHub 연동)
**Priority: High** | **Effort: 5h** | **Stack: ViewComponent + Stimulus + Turbo**

#### Turbo Streams 기반 Controller 수정
```ruby
# app/controllers/tasks_controller.rb
def create
  # GitHub 연동이 활성화된 경우에만 브랜치 생성 서비스 사용
  if github_integration_enabled? && params[:create_github_branch] == 'true'
    result = CreateTaskWithBranchService.new(
      task_params.to_h,
      current_user,
      current_organization.current_service
    ).call
    
    if result.success?
      @task = result.value!
      handle_task_creation_success(@task, github_branch_created: true)
    else
      handle_task_creation_error(result.failure)
    end
  else
    # 일반 Task 생성 (GitHub 연동 없음)
    @task = build_tenant_resource(Task, task_params)
    authorize @task
    
    if @task.save
      handle_task_creation_success(@task)
    else
      handle_task_creation_error(@task.errors)
    end
  end
end

private

def handle_task_creation_success(task, github_branch_created: false)
  respond_to do |format|
    format.turbo_stream do
      flash[:notice] = github_branch_created ? 
        "작업이 생성되고 GitHub 브랜치가 자동으로 생성되었습니다." : 
        "작업이 성공적으로 생성되었습니다."
      
      render turbo_stream: [
        turbo_stream.prepend("tasks_list", 
          render_to_string(partial: "tasks/task_item", locals: { task: task })
        ),
        turbo_stream.replace("task_form",
          render_to_string(partial: "tasks/form", locals: { task: Task.new })
        ),
        turbo_stream.replace("flash_messages",
          render_to_string(partial: "shared/flash_messages")
        )
      ]
    end
    
    format.json { render_with_success(TaskSerializer, task) }
    format.html { redirect_to tasks_path, notice: "작업이 생성되었습니다." }
  end
end

def github_integration_enabled?
  current_organization_membership&.developer_role? &&
  current_organization.github_integration_active?
end
```

#### Turbo Frame 기반 폼 개선
```erb
<!-- app/views/tasks/_form.html.erb -->
<%= turbo_frame_tag "task_form", class: "task-form" do %>
  <%= form_with model: @task, 
                data: { 
                  turbo_frame: "_top",
                  controller: "task-form",
                  action: "turbo:submit-end->task-form#handleSubmit"
                },
                class: "space-y-6" do |form| %>
    
    <!-- 기본 정보 -->
    <div class="bg-white shadow rounded-lg p-6">
      <h3 class="text-lg font-medium mb-4">작업 정보</h3>
      
      <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
        <!-- 제목 -->
        <div class="sm:col-span-2">
          <%= form.label :title, "작업 제목", class: "block text-sm font-medium text-gray-700" %>
          <%= form.text_field :title, 
                placeholder: "예: 로그인 페이지 디자인 개선",
                class: "mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500",
                data: { task_form_target: "titleField" } %>
        </div>
        
        <!-- 우선순위 -->
        <div>
          <%= form.label :priority, "우선순위", class: "block text-sm font-medium text-gray-700" %>
          <%= form.select :priority, 
                options_for_select([
                  ['🔴 긴급', 'urgent'],
                  ['🟠 높음', 'high'], 
                  ['🟡 보통', 'medium'],
                  ['🟢 낮음', 'low']
                ], @task.priority),
                { prompt: '우선순위를 선택하세요' },
                { class: "mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500" } %>
        </div>
        
        <!-- 담당자 -->
        <div>
          <%= form.label :assigned_user_id, "담당자", class: "block text-sm font-medium text-gray-700" %>
          <%= form.select :assigned_user_id,
                options_from_collection_for_select(current_organization.active_members, :id, :display_name, @task.assigned_user_id),
                { prompt: '담당자를 선택하세요' },
                { class: "mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500" } %>
        </div>
        
        <!-- 마감일 -->
        <div>
          <%= form.label :due_date, "마감일", class: "block text-sm font-medium text-gray-700" %>
          <%= form.date_field :due_date,
                class: "mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500" %>
        </div>
        
        <!-- 예상 시간 -->
        <div>
          <%= form.label :estimated_hours, "예상 시간", class: "block text-sm font-medium text-gray-700" %>
          <%= form.number_field :estimated_hours,
                placeholder: "시간 (예: 4)",
                step: 0.5,
                min: 0,
                class: "mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500" %>
        </div>
      </div>
    </div>
    
    <!-- 상세 설명 (Trix 에디터) -->
    <div class="bg-white shadow rounded-lg p-6">
      <h3 class="text-lg font-medium mb-4">상세 설명</h3>
      <%= form.label :description, "작업 내용을 자세히 작성해주세요", class: "block text-sm font-medium text-gray-700 mb-2" %>
      <%= form.rich_text_area :description,
            placeholder: "작업의 목적, 요구사항, 완료 조건 등을 작성해주세요...",
            class: "trix-editor-custom" %>
    </div>
    
    <!-- GitHub 연동 (개발자만 표시) -->
    <% if github_integration_enabled? %>
      <div class="bg-blue-50 shadow rounded-lg p-6 border border-blue-200">
        <h3 class="text-lg font-medium mb-4 text-blue-900">
          <i class="fab fa-github mr-2"></i>GitHub 연동 (선택사항)
        </h3>
        
        <div class="space-y-4">
          <div class="flex items-center">
            <%= check_box_tag :create_github_branch, 'true', false,
                  class: "h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded",
                  data: { action: "change->github-integration#toggleBranchPreview" } %>
            <%= label_tag :create_github_branch, 
                  "GitHub 브랜치 자동 생성", 
                  class: "ml-2 block text-sm text-blue-900 font-medium" %>
          </div>
          
          <div id="branch-preview" class="hidden p-3 bg-white rounded border">
            <p class="text-sm text-gray-600 mb-2">생성될 브랜치명:</p>
            <code id="branch-name" class="text-sm bg-gray-100 px-2 py-1 rounded">
              feature/TASK-XXX-branch-name
            </code>
          </div>
          
          <p class="text-sm text-blue-700">
            💡 개발 작업의 경우 GitHub 브랜치를 생성하면 코드 관리가 편리합니다.
          </p>
        </div>
      </div>
    <% end %>
    
    <!-- 제출 버튼 -->
    <div class="flex justify-end space-x-3">
      <%= link_to "취소", tasks_path, 
            class: "bg-white py-2 px-4 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500" %>
      <%= form.submit "작업 생성", 
            class: "bg-blue-600 py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500" %>
    </div>
  <% end %>
</div>
```

#### Route 개선
```ruby
resources :tasks do
  member do
    patch :assign
    patch :change_status, path: 'status'
    patch :reorder
    get :metrics  # 새로 추가
  end
  collection do
    get :stats
  end
end
```

### 1.2 Task 메트릭 표시 (ViewComponent + Turbo Frame)
**Priority: Medium** | **Effort: 4h** | **Stack: ViewComponent + Stimulus + Turbo Frame**

#### Turbo Stream 지원 Controller 액션
```ruby
def metrics
  authorize @task
  
  @task_metrics = TaskMetrics.new(
    estimated_hours: @task.estimated_hours,
    actual_hours: @task.actual_hours || 0.0,
    completion_percentage: calculate_completion_percentage(@task),
    complexity_score: @task.complexity_score || 1
  )
  
  respond_to do |format|
    format.json do
      render json: { 
        metrics: @task_metrics.to_h,
        user_friendly: {
          efficiency_status: efficiency_status_text(@task_metrics),
          complexity_description: complexity_description(@task_metrics),
          progress_description: progress_description(@task_metrics),
          time_status: time_status_description(@task_metrics)
        }
      }
    end
    
    format.turbo_stream do
      render turbo_stream: turbo_stream.replace(
        "task_metrics_#{@task.id}",
        TaskMetricsCardComponent.new(task: @task, task_metrics: @task_metrics)
      )
    end
  end
end

def change_status
  # 상태 변경시 메트릭도 자동 업데이트
  respond_to do |format|
    format.turbo_stream do
      task_metrics = TaskMetrics.new(...)
      
      render turbo_stream: [
        turbo_stream.replace("task_#{@task.id}", partial: "tasks/task_item"),
        turbo_stream.replace("task_metrics_#{@task.id}", 
          TaskMetricsCardComponent.new(task: @task, task_metrics: task_metrics)
        ),
        turbo_stream.replace("flash_messages", partial: "shared/flash_messages")
      ]
    end
  end
end

private

def calculate_completion_percentage(task)
  case task.status
  when 'todo' then 0.0
  when 'in_progress' then 50.0
  when 'review' then 90.0
  when 'done' then 100.0
  else 0.0
  end
end

def efficiency_status_text(metrics)
  if metrics.is_on_track?
    "👍 예정대로 진행 중"
  else
    "⚠️ 일정 지연 위험"
  end
end

def complexity_description(metrics)
  case metrics.complexity_level
  when 'low' then "🟢 간단한 작업"
  when 'medium' then "🟡 보통 작업" 
  when 'high' then "🟠 복잡한 작업"
  when 'very_high' then "🔴 매우 복잡한 작업"
  end
end
```

#### TaskMetricsCardComponent (ViewComponent)
```ruby
# app/components/task_metrics_card_component.rb
class TaskMetricsCardComponent < ViewComponent::Base
  def initialize(task:, task_metrics:)
    @task = task
    @task_metrics = task_metrics
  end

  private

  attr_reader :task, :task_metrics

  def progress_bar_color
    if task_metrics.completion_percentage >= 90
      "bg-green-600"
    elsif task_metrics.completion_percentage >= 50
      "bg-blue-600"
    else
      "bg-yellow-600"
    end
  end

  def efficiency_status_class
    if task_metrics.is_on_track?
      "bg-green-50 text-green-800"
    else
      "bg-yellow-50 text-yellow-800"
    end
  end
end
```

#### ViewComponent 템플릿 (Turbo Frame 포함)
```erb
<!-- app/components/task_metrics_card_component.html.erb -->
<%= turbo_frame_tag "task_metrics_#{task.id}", 
                    class: "bg-white shadow rounded-lg overflow-hidden",
                    data: { 
                      controller: "task-metrics",
                      task_metrics_task_id_value: task.id,
                      turbo_permanent: true
                    } do %>
  <div class="px-4 py-5 sm:p-6">
    <div class="flex items-center justify-between mb-4">
      <h3 class="text-lg font-medium text-gray-900">작업 진행 현황</h3>
      <button type="button" 
              data-action="click->task-metrics#refresh"
              class="text-sm text-blue-600 hover:text-blue-800 transition-colors">
        🔄 새로고침
      </button>
    </div>
    
    <!-- 진행률 표시 -->
    <div class="mb-6">
      <div class="flex justify-between items-center mb-2">
        <span class="text-sm font-medium text-gray-700">완료율</span>
        <span class="text-sm font-bold text-gray-900" data-target="task-metrics.completionPercent">
          <%= @task_metrics.completion_percentage.round(1) %>%
        </span>
      </div>
      <div class="w-full bg-gray-200 rounded-full h-2">
        <div class="bg-blue-600 h-2 rounded-full transition-all duration-300" 
             style="width: <%= @task_metrics.completion_percentage %>%"
             data-target="task-metrics.progressBar"></div>
      </div>
    </div>
    
    <!-- 시간 정보 -->
    <div class="grid grid-cols-2 gap-4 mb-6">
      <div class="text-center p-3 bg-gray-50 rounded-lg">
        <div class="text-2xl font-bold text-blue-600">
          <%= @task_metrics.estimated_hours || "미설정" %>
        </div>
        <div class="text-xs text-gray-500">예상 시간</div>
      </div>
      <div class="text-center p-3 bg-gray-50 rounded-lg">
        <div class="text-2xl font-bold <%= @task_metrics.overdue? ? 'text-red-600' : 'text-green-600' %>">
          <%= @task_metrics.actual_hours || "0" %>
        </div>
        <div class="text-xs text-gray-500">실제 시간</div>
      </div>
    </div>
    
    <!-- 상태 배지들 -->
    <div class="space-y-2">
      <!-- 효율성 상태 -->
      <div class="flex items-center justify-between p-3 rounded-lg <%= @task_metrics.is_on_track? ? 'bg-green-50 text-green-800' : 'bg-yellow-50 text-yellow-800' %>">
        <span class="text-sm font-medium">
          <%= @task_metrics.is_on_track? ? '👍 예정대로 진행 중' : '⚠️ 일정 지연 위험' %>
        </span>
        <% unless @task_metrics.is_on_track? %>
          <span class="text-xs">효율성: <%= (@task_metrics.efficiency_ratio * 100).round(1) %>%</span>
        <% end %>
      </div>
      
      <!-- 복잡도 표시 -->
      <div class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
        <span class="text-sm font-medium text-gray-700">
          <%= case @task_metrics.complexity_level
                when 'low' then '🟢 간단한 작업'
                when 'medium' then '🟡 보통 작업'
                when 'high' then '🟠 복잡한 작업' 
                when 'very_high' then '🔴 매우 복잡한 작업'
                end %>
        </span>
        <span class="text-xs text-gray-500">복잡도: <%= @task_metrics.complexity_score %>/10</span>
      </div>
    </div>
    
    <!-- 남은 작업 정보 -->
    <% if @task_metrics.remaining_percentage > 0 %>
      <div class="mt-4 p-3 bg-blue-50 rounded-lg">
        <div class="text-sm text-blue-800">
          <strong><%= @task_metrics.remaining_percentage.round(1) %>%</strong> 작업이 남아있습니다
        </div>
      </div>
    <% end %>
  </div>
</div>
```

#### Stimulus 컨트롤러 (Turbo Stream 지원)
```javascript
// app/javascript/controllers/task_metrics_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "completionPercent", "progressBar", "estimatedHours", 
    "actualHours", "efficiencyStatus", "remainingInfo", "loading"
  ]
  static values = { 
    taskId: Number,
    refreshInterval: { type: Number, default: 30000 } // 30초
  }
  
  connect() {
    console.log("TaskMetrics controller connected for task", this.taskIdValue)
    this.refreshMetrics()
    this.startAutoRefresh()
  }
  
  disconnect() {
    this.stopAutoRefresh()
  }
  
  refresh() {
    this.refreshMetrics()
  }
  
  async refreshMetrics() {
    try {
      this.showLoading(true)
      
      // Turbo Stream을 우선 시도, 실패시 JSON으로 폴백
      const turboResponse = await fetch(`/tasks/${this.taskIdValue}/metrics`, {
        headers: {
          'Accept': 'text/vnd.turbo-stream.html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (turboResponse.ok && turboResponse.headers.get('content-type')?.includes('turbo-stream')) {
        const streamContent = await turboResponse.text()
        Turbo.renderStreamMessage(streamContent)
        this.showToast('메트릭이 업데이트되었습니다', 'success')
        return
      }
      
      // JSON 폴백
      const jsonResponse = await fetch(`/tasks/${this.taskIdValue}/metrics`)
      const data = await jsonResponse.json()
      
      if (data.metrics) {
        this.updateMetrics(data.metrics, data.user_friendly)
      }
    } catch (error) {
      console.error("Failed to refresh metrics:", error)
      this.showToast('메트릭 업데이트에 실패했습니다', 'error')
    } finally {
      this.showLoading(false)
    }
  }
  
  startAutoRefresh() {
    if (this.refreshIntervalValue > 0) {
      this.refreshTimer = setInterval(() => {
        this.refreshMetricsWithTurbo() // 자동 새로고침은 조용히
      }, this.refreshIntervalValue)
    }
  }
  
  async refreshMetricsWithTurbo() {
    try {
      const response = await fetch(`/tasks/${this.taskIdValue}/metrics`, {
        headers: { 'Accept': 'text/vnd.turbo-stream.html' }
      })
      
      if (response.ok) {
        const streamContent = await response.text()
        Turbo.renderStreamMessage(streamContent)
      }
    } catch (error) {
      console.error("Auto-refresh failed:", error)
    }
  }
}
```

---

## Task 2: Sprint 계획 대시보드 (ViewComponent + Turbo 기반)

### 2.1 Sprint 계획 페이지 생성 (Turbo Frames + ViewComponent)
**Priority: High** | **Effort: 6h** | **Stack: ViewComponent + Stimulus + Turbo**

#### Controller 생성
```ruby
# app/controllers/sprints_controller.rb
class SprintsController < TenantBaseController
  def planning
    @sprint = current_organization.sprints.find(params[:id])
    @team_members = current_organization.active_members
    
    planner = SprintPlanningService.new(@sprint, @team_members)
    @plan_result = planner.execute
    
    if @plan_result.success?
      @sprint_plan = @plan_result.value!
    else
      @errors = @plan_result.failure
    end
  end
  
  def dependency_analysis
    @sprint = current_organization.sprints.find(params[:id])
    @analyzer = DependencyAnalyzer.new(@sprint)
    
    render json: {
      critical_path: @analyzer.critical_path.map(&:task_id),
      bottlenecks: @analyzer.bottleneck_tasks.map(&:task_id),
      completion_date: @analyzer.estimated_completion_date,
      progress: @analyzer.progress_metrics
    }
  end
end
```

#### ViewComponent 기반 템플릿 구조
```erb
<!-- app/views/sprints/planning.html.erb -->
<div class="sprint-planning-dashboard" data-controller="sprint-dashboard">
  <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
    
    <!-- 스프린트 정보 (ViewComponent) -->
    <%= turbo_frame_tag "sprint_info_#{@sprint.id}" do %>
      <%= render SprintInfoCardComponent.new(sprint: @sprint, sprint_plan: @sprint_plan) %>
    <% end %>
    
    <!-- 리스크 평가 (ViewComponent + Turbo Frame) -->
    <%= turbo_frame_tag "risk_assessment_#{@sprint.id}" do %>
      <%= render RiskAssessmentCardComponent.new(sprint: @sprint) %>
    <% end %>
    
    <!-- 의존성 분석 (ViewComponent + 실시간 업데이트) -->
    <%= turbo_frame_tag "dependency_analysis_#{@sprint.id}", 
                        data: { 
                          controller: "dependency-analyzer",
                          dependency_analyzer_sprint_id_value: @sprint.id 
                        } do %>
      <%= render DependencyAnalysisCardComponent.new(sprint: @sprint) %>
    <% end %>
  </div>
  
  <!-- 번다운 차트 (ViewComponent) -->
  <%= turbo_frame_tag "burndown_chart_#{@sprint.id}" do %>
    <%= render BurndownChartComponent.new(sprint: @sprint) %>
  <% end %>
</div>

<!-- ViewComponent들 -->
<!-- SprintInfoCardComponent -->
<!-- RiskAssessmentCardComponent -->  
<!-- DependencyAnalysisCardComponent -->
<!-- BurndownChartComponent -->
```

#### ViewComponent 예시 구현
```ruby
# app/components/sprint_info_card_component.rb
class SprintInfoCardComponent < ViewComponent::Base
  def initialize(sprint:, sprint_plan: nil)
    @sprint = sprint
    @sprint_plan = sprint_plan
  end

  private

  attr_reader :sprint, :sprint_plan

  def utilization_status_class
    return "text-gray-500" unless sprint_plan
    
    if sprint_plan.overloaded?
      "text-red-600"
    elsif sprint_plan.on_track?
      "text-green-600"
    else
      "text-yellow-600"
    end
  end
end
```

#### Route 추가
```ruby
resources :sprints do
  member do
    get :planning
    get :dependency_analysis
  end
end
```

---

## Task 3: 팀 성과 대시보드

### 3.1 팀 메트릭 대시보드
**Priority: Medium** | **Effort: 5h**

#### Controller 액션
```ruby
# app/controllers/dashboard_controller.rb
def team_metrics
  @team_metrics = TeamMetrics.new(
    total_capacity: calculate_team_capacity,
    allocated_hours: current_sprint_allocated_hours,
    completed_hours: current_sprint_completed_hours,
    team_size: current_organization.active_members.count,
    active_tasks: current_organization.tasks.active.count,
    completed_tasks: current_organization.tasks.completed.count,
    blocked_tasks: current_organization.tasks.blocked.count,
    velocity_last_sprint: last_sprint_velocity,
    average_velocity: average_team_velocity
  )
  
  render json: { team_metrics: @team_metrics }
end
```

#### View 컴포넌트
- 팀 활용률 원형 차트
- 완료율 트렌드 그래프  
- 벨로시티 히스토리
- 팀 건강 점수 표시기

---

## Task 4: 리스크 관리 페이지

### 4.1 리스크 평가 및 관리
**Priority: Medium** | **Effort: 4h**

#### Controller 생성
```ruby
# app/controllers/risks_controller.rb
class RisksController < TenantBaseController
  def index
    @risks = load_current_risks
    @capacity_risk = RiskAssessment.create_capacity_risk(
      current_team_utilization, 
      current_organization.active_members.count
    )
    
    @dependency_risk = RiskAssessment.create_dependency_risk(
      current_organization.tasks.blocked.count
    )
  end
  
  private
  
  def load_current_risks
    # 기존 리스크 + 자동 생성된 리스크
    existing_risks = current_organization.risk_assessments.active
    auto_risks = [
      RiskAssessment.create_capacity_risk(current_team_utilization, team_size),
      RiskAssessment.create_dependency_risk(blocked_tasks_count)
    ].compact
    
    (existing_risks + auto_risks).sort_by(&:risk_score).reverse
  end
end
```

---

## Task 5: GitHub 통합 개선

### 5.1 GitHub Payload 활용
**Priority: Low** | **Effort: 3h**

#### Webhook Controller 개선
```ruby
# app/controllers/webhooks/github_controller.rb
def push
  payload = GithubPayload.new(webhook_params)
  
  # 기존 contract 검증
  contract = GithubWebhookContract.new
  result = contract.call(payload.to_h)
  
  if result.success?
    # GithubPayload 편의 메서드 활용
    task_id = payload.extract_task_id
    branch_type = determine_branch_type(payload)
    
    ProcessGithubPushJob.perform_later(
      payload: payload.to_h,
      task_id: task_id,
      branch_type: branch_type
    )
    
    head :ok
  else
    render json: { errors: result.errors.to_h }, status: :unprocessable_entity
  end
end
```

---

## Task 6: JavaScript 동적 UI

### 6.1 실시간 메트릭 업데이트
**Priority: Medium** | **Effort: 4h**

#### JavaScript 컨트롤러
```javascript
// app/javascript/controllers/sprint_metrics_controller.js
import { Controller } from "@hotwired/stimulus"
import { Chart } from "chart.js"

export default class extends Controller {
  static targets = ["burndownChart", "riskList", "dependencyGraph"]
  
  connect() {
    this.loadMetrics()
    this.startAutoRefresh()
  }
  
  async loadMetrics() {
    try {
      const response = await fetch(`/sprints/${this.data.get("sprintId")}/dependency_analysis`)
      const data = await response.json()
      
      this.updateBurndownChart(data.progress)
      this.updateRiskAssessment()
      this.updateDependencyAnalysis(data.critical_path, data.bottlenecks)
    } catch (error) {
      console.error("Failed to load metrics:", error)
    }
  }
  
  updateBurndownChart(progressData) {
    // Chart.js를 이용한 번다운 차트 업데이트
  }
  
  startAutoRefresh() {
    setInterval(() => this.loadMetrics(), 30000) // 30초마다 업데이트
  }
}
```

---

## 📊 구현 우선순위

### Phase 1 (필수 기능) - 8시간
1. ✅ Task 생성시 GitHub 브랜치 자동 생성
2. ✅ Task 메트릭 표시 기능
3. ✅ 기본 Sprint 계획 페이지

### Phase 2 (핵심 기능) - 12시간  
4. ✅ Sprint 의존성 분석 대시보드
5. ✅ 팀 성과 메트릭 표시
6. ✅ 리스크 평가 및 관리 페이지

### Phase 3 (고급 기능) - 8시간
7. ✅ 실시간 JavaScript UI
8. ✅ GitHub 통합 고도화
9. ✅ 성능 최적화

---

## 🛠 기술 스택 (Modern Rails 8.0)

### Backend (Server-First Architecture)
- **Rails 8.0** - MVC + ViewComponent 패턴
- **ViewComponent** - 재사용 가능한 컴포넌트 시스템
- **dry-rb ecosystem** - 검증, 모나드, 구조체
- **Hashie** - 동적 데이터 처리
- **MemoWise** - 성능 최적화

### Frontend (SPA-like without SPA complexity)
- **Hotwire (Turbo Frames + Turbo Streams + Stimulus)** - SPA-like 경험
- **Stimulus** - 경량 JavaScript 프레임워크
- **Tailwind CSS** - 유틸리티 기반 스타일링
- **Chart.js** - 데이터 시각화
- **Trix Editor** - 리치 텍스트 에디팅

### Infrastructure (Rails 8.0 Solid Stack)
- **PostgreSQL** - 메인 데이터베이스
- **Solid Queue** - PostgreSQL 기반 백그라운드 작업
- **Solid Cache** - PostgreSQL 기반 캐싱
- **GitHub API** - Git 통합 (옵셔널)

### Development Philosophy
- **ViewComponent + Stimulus + Hotwire** - 컴포넌트 기반 + 실시간 UI
- **Progressive Enhancement** - JavaScript 없이도 기본 기능 작동
- **Server-Centric Logic** - 비즈니스 로직은 서버에 집중
- **Real-time Updates** - Turbo Streams로 실시간 DOM 업데이트

---

## 📋 체크리스트

### 개발 준비
- [ ] 기존 Phase 1-4 코드 리뷰
- [ ] UI 목업 및 와이어프레임 작성
- [ ] 데이터베이스 스키마 업데이트 계획
- [ ] GitHub API 권한 및 토큰 설정

### 구현 단계
- [ ] Task 1: Task 관리 UI 강화
- [ ] Task 2: Sprint 계획 대시보드
- [ ] Task 3: 팀 성과 대시보드  
- [ ] Task 4: 리스크 관리 페이지
- [ ] Task 5: GitHub 통합 개선
- [ ] Task 6: JavaScript 동적 UI

### 품질 보증
- [ ] 단위 테스트 작성
- [ ] 통합 테스트 작성
- [ ] E2E 테스트 (Playwright)
- [ ] 성능 테스트
- [ ] 접근성 검증

### 배포 및 운영
- [ ] 프로덕션 배포
- [ ] 모니터링 설정
- [ ] 사용자 피드백 수집
- [ ] 문서화 완료

---

## 🎯 성공 지표

### 기능적 지표
- ✅ 모든 Phase 1-4 기능이 UI에서 작동
- ✅ Task 생성시 GitHub 브랜치 자동 생성 성공률 > 95%
- ✅ Sprint 계획 수립 시간 단축 > 50%
- ✅ 리스크 조기 발견율 향상 > 30%

### 기술적 지표
- ✅ 페이지 로딩 시간 < 2초
- ✅ 메트릭 업데이트 지연 < 5초
- ✅ 테스트 커버리지 > 90%
- ✅ 에러율 < 1%

### 사용자 경험
- ✅ 직관적인 UI/UX
- ✅ 실시간 데이터 업데이트
- ✅ 모바일 반응형 지원
- ✅ 접근성 AA 수준 준수

---

## 📚 참고 자료

### 내부 문서
- [Core Extensions Refactoring](./core_extensions_refactoring.md)
- [Phase 1-4 구현 문서](../services/)
- [API 문서](../api/)

### 외부 라이브러리
- [dry-rb 공식 문서](https://dry-rb.org/)
- [Hotwire 가이드](https://hotwired.dev/)
- [Chart.js 문서](https://www.chartjs.org/)
- [GitHub API v4](https://docs.github.com/en/graphql)

---

**작성일**: 2024년 8월 28일  
**마지막 업데이트**: 2024년 8월 28일  
**담당자**: Development Team  
**승인자**: Project Manager