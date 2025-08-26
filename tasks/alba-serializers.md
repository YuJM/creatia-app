# Alba JSON Serializers 사용법

## 개요

Creatia는 [Alba gem](https://github.com/okuramasafumi/alba)을 사용하여 JSON API 응답을 직렬화합니다. Alba는 빠르고 효율적인 JSON 직렬화 라이브러리로, 기존 JBuilder보다 우수한 성능을 제공합니다.

## 설정

### Initializer 설정

```ruby
# config/initializers/alba.rb
Alba.backend = :active_support
Alba.inflector = :active_support
```

### 기본 설정

- **Backend**: ActiveSupport와의 호환성을 위해 `:active_support` 사용
- **Inflector**: camelCase 변환을 위해 `:active_support` 사용
- **Key Transform**: 모든 응답의 키는 `lower_camel` (camelCase)로 변환

## Serializer 클래스 구조

### BaseSerializer

모든 serializer의 부모 클래스입니다.

```ruby
class BaseSerializer
  include Alba::Resource
  
  transform_keys :lower_camel
end
```

### 사용 가능한 Serializer 클래스

| Serializer | 용도 | 위치 |
|------------|------|------|
| `TaskSerializer` | Task의 상세 정보 (GitHub 통합 포함) | `app/serializers/task_serializer.rb` |
| `SimpleTaskSerializer` | Task의 간단한 정보 (상태 변경용) | `app/serializers/simple_task_serializer.rb` |
| `NotificationSerializer` | 알림 데이터 | `app/serializers/notification_serializer.rb` |
| `CommitSerializer` | GitHub 커밋 정보 | `app/serializers/commit_serializer.rb` |
| `BranchSerializer` | GitHub 브랜치 정보 | `app/serializers/branch_serializer.rb` |
| `GithubRepositorySerializer` | GitHub 저장소 정보 | `app/serializers/github_repository_serializer.rb` |
| `ErrorSerializer` | 에러 응답 표준화 | `app/serializers/error_serializer.rb` |

## 기본 사용법

### 1. 단순한 직렬화

```ruby
# 컨트롤러에서
def show
  @task = Task.find(params[:id])
  render json: TaskSerializer.new(@task).serializable_hash
end
```

### 2. ApplicationController 헬퍼 사용

```ruby
# 헬퍼 메서드 사용 (권장)
def show
  @task = Task.find(params[:id])
  render_serialized(TaskSerializer, @task)
end

# 성공 응답과 함께
def create
  @task = Task.create(task_params)
  if @task.save
    render_with_success(TaskSerializer, @task)
  else
    render_error(@task.errors)
  end
end
```

### 3. 컬렉션 직렬화

```ruby
def index
  @tasks = Task.all
  render_serialized(TaskSerializer, @tasks)
end
```

## ApplicationController 헬퍼 메서드

### render_serialized(serializer_class, object, options = {})

기본적인 직렬화를 수행합니다.

```ruby
# 기본 사용
render_serialized(TaskSerializer, @task)

# 추가 파라미터 전달
render_serialized(TaskSerializer, @task, params: { from_status: 'open' })

# HTTP 상태 코드 지정
render_serialized(TaskSerializer, @task, status: :created)
```

### render_with_success(serializer_class, object, options = {})

성공 응답 형태로 래핑하여 직렬화합니다.

```ruby
render_with_success(TaskSerializer, @task)

# 응답 형태:
# {
#   "success": true,
#   "data": { ... serialized object ... }
# }
```

### render_error(errors, options = {})

에러 응답을 표준화된 형태로 반환합니다.

```ruby
# ActiveRecord 에러
render_error(@task.errors)

# 문자열 에러
render_error("GitHub 저장소가 연결되지 않았습니다.", status: :unprocessable_entity)

# 배열 에러
render_error(["Field is required", "Invalid format"])

# 단일 에러 메시지
render_error(@task.errors, single_error: "Task creation failed")
```

## 파라미터 전달

Serializer에 추가 데이터를 전달할 수 있습니다.

### Helper 메서드 전달

```ruby
# 시간 헬퍼를 자동으로 전달 (time_ago_in_words 등)
render_serialized(NotificationSerializer, @notifications)
```

### 커스텀 파라미터 전달

```ruby
# 상태 변경 정보 전달
render_serialized(SimpleTaskSerializer, @task, params: { 
  from_status: 'open', 
  to_status: 'in_progress' 
})

# 브랜치 정보 전달
render_serialized(BranchSerializer, branch_data, params: {
  task: @task,
  github_repository: @repository
})
```

## Serializer 작성 가이드

### 기본 구조

```ruby
class MyModelSerializer < BaseSerializer
  # 기본 속성들
  attributes :id, :name, :created_at, :updated_at
  
  # 커스텀 속성
  attribute :display_name do |model|
    "#{model.name} (#{model.id})"
  end
  
  # 조건부 속성
  attribute :secret_data, if: proc { |model, params| params[:include_secrets] } do |model|
    model.secret_information
  end
  
  # 파라미터 사용
  attribute :formatted_date do |model, params|
    if params[:time_helper].present?
      params[:time_helper].time_ago_in_words(model.created_at)
    else
      model.created_at.to_s
    end
  end
end
```

### 연관 관계 처리

```ruby
class TaskSerializer < BaseSerializer
  attributes :id, :title, :description
  
  # 단일 연관 관계
  attribute :assignee do |task|
    if task.assignee.present?
      {
        id: task.assignee.id,
        name: task.assignee.name,
        email: task.assignee.email
      }
    end
  end
  
  # 복잡한 중첩 데이터
  attribute :github_integration do |task|
    {
      has_branch: task.has_github_branch?,
      branch_name: task.github_branch_name,
      branch_url: task.github_branch_url,
      has_pr: task.has_github_pr?,
      pr_number: task.github_pr_number,
      status: task.github_status
    }
  end
end
```

## 실제 사용 예시

### TasksController

```ruby
class TasksController < ApplicationController
  def update
    @task = Task.find(params[:id])
    old_status = @task.status
    
    if @task.update(task_params)
      respond_to do |format|
        format.html { redirect_to @task, notice: 'Task updated.' }
        format.json { 
          render json: { 
            success: true, 
            task: TaskSerializer.new(@task).serializable_hash
          } 
        }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render_error(@task.errors) }
      end
    end
  end
  
  def move
    @task = Task.find(params[:id])
    old_status = @task.status
    new_status = params[:status]
    
    if @task.update(status: new_status)
      render json: { 
        success: true,
        task: SimpleTaskSerializer.new(@task, params: { 
          from_status: old_status, 
          to_status: new_status 
        }).serializable_hash
      }
    else
      render_error(@task.errors)
    end
  end
end
```

### NotificationsController

```ruby
class NotificationsController < ApplicationController
  def index
    @notifications = current_user.notifications.recent.limit(20)
    
    render json: {
      notifications: NotificationSerializer.new(@notifications, params: { 
        time_helper: helpers 
      }).serializable_hash,
      unread_count: current_user.notifications.unread.count
    }
  end
end
```

## JSON 응답 형태

### 일반적인 응답

```json
{
  "id": 1,
  "title": "Fix authentication bug",
  "description": "User login is not working properly",
  "status": "open",
  "priority": "high",
  "taskId": "SHOP-142",
  "createdAt": "2025-08-24T14:11:03+09:00",
  "updatedAt": "2025-08-24T14:15:30+09:00",
  "assignee": {
    "id": 5,
    "name": "홍길동",
    "email": "hong@example.com"
  },
  "githubIntegration": {
    "hasBranch": true,
    "branchName": "feature/SHOP-142-fix-auth",
    "branchUrl": "https://github.com/company/repo/tree/feature/SHOP-142-fix-auth",
    "hasPr": false,
    "prNumber": null,
    "status": "connected"
  },
  "overdue": false
}
```

### 성공 응답

```json
{
  "success": true,
  "data": {
    "id": 1,
    "title": "Task title",
    ...
  }
}
```

### 에러 응답

```json
{
  "success": false,
  "errors": [
    "Title can't be blank",
    "Priority must be included in the list"
  ],
  "error": "Title can't be blank, Priority must be included in the list"
}
```

## 성능 최적화

### 1. N+1 쿼리 방지

```ruby
# 컨트롤러에서 미리 로드
@tasks = Task.includes(:assignee, :reporter, :service, :sprint).all
render_serialized(TaskSerializer, @tasks)
```

### 2. 조건부 속성 사용

```ruby
# 필요한 경우에만 포함
attribute :expensive_calculation, if: proc { |obj, params| params[:include_details] } do |obj|
  obj.perform_expensive_operation
end
```

### 3. 간단한 Serializer 사용

```ruby
# 목록에서는 간단한 정보만
render_serialized(SimpleTaskSerializer, @tasks)

# 상세보기에서는 전체 정보
render_serialized(TaskSerializer, @task)
```

## 테스트 작성

```ruby
# spec/serializers/task_serializer_spec.rb
RSpec.describe TaskSerializer, type: :serializer do
  let(:task) { create(:task, title: 'Test Task') }
  
  describe '#serializable_hash' do
    subject { TaskSerializer.new(task).serializable_hash }
    
    it 'serializes task with camelCase keys' do
      expect(subject).to include(
        'id' => task.id,
        'title' => 'Test Task',
        'taskId' => task.task_id
      )
    end
  end
end
```

## 마이그레이션 가이드

### 기존 코드에서 변경

```ruby
# Before (JBuilder 스타일)
render json: {
  success: true,
  task: {
    id: @task.id,
    title: @task.title,
    assignee_name: @task.assignee&.name
  }
}

# After (Alba 사용)
render json: {
  success: true,
  task: TaskSerializer.new(@task).serializable_hash
}

# 또는 헬퍼 사용 (권장)
render_with_success(TaskSerializer, @task)
```

## 트러블슈팅

### 1. undefined method 에러

```ruby
# 에러: undefined method `time_ago_in_words`
# 해결: time_helper 파라미터 전달
render_serialized(NotificationSerializer, @notifications, params: { time_helper: helpers })
```

### 2. 키 변환이 안 되는 경우

```ruby
# BaseSerializer를 상속받았는지 확인
class MySerializer < BaseSerializer  # ✅ 올바름
  # ...
end

class MySerializer  # ❌ 잘못됨
  include Alba::Resource
  # ...
end
```

### 3. 파라미터가 전달되지 않는 경우

```ruby
# 올바른 사용법
render_serialized(MySerializer, @object, params: { custom_param: value })

# 잘못된 사용법
render_serialized(MySerializer, @object, custom_param: value)
```

## 참고 자료

- [Alba GitHub Repository](https://github.com/okuramasafumi/alba)
- [Alba 공식 문서](https://github.com/okuramasafumi/alba#readme)
- [Alba vs. 다른 JSON 직렬화 라이브러리 성능 비교](https://github.com/okuramasafumi/alba/tree/main/benchmark)