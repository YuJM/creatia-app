# frozen_string_literal: true

# Task 관련 비즈니스 로직을 처리하는 Service
class TaskService
  include Dry::Monads[:result, :do]
  
  pattr_initialize [:organization!, :user]
  
  # Task 목록 조회
  def list(filters = {})
    scope = Task.where(organization_id: organization.id.to_s)
    
    # 필터 적용
    scope = apply_filters(scope, filters)
    
    # 정렬 적용
    scope = apply_sorting(scope, filters[:sort_by])
    
    # 페이지네이션 적용
    page = filters[:page] || 1
    per_page = filters[:per_page] || 25
    paginated_scope = scope.page(page).per(per_page)
    
    # DTO로 변환
    tasks = paginated_scope.map { |task| Dto::TaskDto.from_model(task) }
    
    # 페이지네이션 메타데이터와 함께 반환
    result = {
      tasks: tasks,
      pagination: {
        current_page: paginated_scope.current_page,
        total_pages: paginated_scope.total_pages,
        total_count: paginated_scope.total_count,
        per_page: per_page
      }
    }
    
    Success(result)
  end
  
  # 단일 Task 조회
  def find(task_id)
    task = Task.where(organization_id: organization.id.to_s, _id: task_id).first
    
    return Failure(:not_found) unless task
    
    Success(Dto::TaskDto.from_model(task))
  end
  
  # Task 생성
  def create(params)
    task = Task.new(
      params.merge(
        organization_id: organization.id.to_s,
        created_by_id: user.id.to_s
      )
    )
    
    if task.save
      Success(Dto::TaskDto.from_model(task))
    else
      Failure(task.errors)
    end
  end
  
  # Task 수정
  def update(task_id, params)
    task = Task.where(organization_id: organization.id, _id: task_id).first
    
    return Failure(:not_found) unless task
    
    if task.update(params)
      Success(Dto::TaskDto.from_model(task))
    else
      Failure(task.errors)
    end
  end
  
  # Task 삭제
  def destroy(task_id)
    task = Task.where(organization_id: organization.id.to_s, _id: task_id).first
    
    return Failure(:not_found) unless task
    
    if task.destroy
      Success(true)
    else
      Failure(task.errors)
    end
  end
  
  # Task 상태 변경
  def change_status(task_id, new_status)
    task = Task.where(organization_id: organization.id.to_s, _id: task_id).first
    
    return Failure(:not_found) unless task
    return Failure(:invalid_status) unless Task::STATUSES.include?(new_status)
    
    task.status = new_status
    
    if task.save
      Success(Dto::TaskDto.from_model(task))
    else
      Failure(task.errors)
    end
  end
  
  # Task 할당
  def assign(task_id, assignee_id)
    task = Task.where(organization_id: organization.id.to_s, _id: task_id).first
    
    return Failure(:not_found) unless task
    
    if assignee_id.present?
      assignee = User.cached_find(assignee_id)
      return Failure(:invalid_assignee) unless assignee
      return Failure(:not_member) unless assignee.member_of?(organization)
    end
    
    task.assignee_id = assignee_id
    
    if task.save
      Success(Dto::TaskDto.from_model(task))
    else
      Failure(task.errors)
    end
  end
  
  # Task 통계
  def statistics
    tasks = Task.where(organization_id: organization.id.to_s)
    
    stats = {
      total: tasks.count,
      by_status: {
        todo: tasks.where(status: 'todo').count,
        in_progress: tasks.where(status: 'in_progress').count,
        review: tasks.where(status: 'review').count,
        done: tasks.where(status: 'done').count
      },
      by_priority: {
        urgent: tasks.where(priority: 'urgent').count,
        high: tasks.where(priority: 'high').count,
        medium: tasks.where(priority: 'medium').count,
        low: tasks.where(priority: 'low').count
      },
      overdue: tasks.where(:due_date.lt => Date.current, :status.ne => 'done').count,
      unassigned: tasks.where(assignee_id: nil).count
    }
    
    Success(Dto::TaskStatisticsDto.new(stats))
  end
  
  # 사용 가능한 Sprint 목록
  def available_sprints
    Sprint.where(organization_id: organization.id, status: ['planned', 'active'])
          .map { |sprint| Dto::SprintDto.from_model(sprint) }
  end
  
  # 사용 가능한 담당자 목록
  def available_assignees
    organization.users.map do |user|
      {
        id: user.id,
        name: user.name,
        email: user.email,
        avatar_url: user.avatar_url
      }
    end
  end
  
  private
  
  def apply_filters(scope, filters)
    scope = scope.where(status: filters[:status]) if filters[:status].present?
    scope = scope.where(priority: filters[:priority]) if filters[:priority].present?
    scope = scope.where(assignee_id: filters[:assignee_id]) if filters[:assignee_id].present?
    scope = scope.where(sprint_id: filters[:sprint_id]) if filters[:sprint_id].present?
    scope = scope.where(assignee_id: nil) if filters[:unassigned] == 'true'
    
    if filters[:overdue] == 'true'
      scope = scope.where(:due_date.lt => Date.current, :status.ne => 'done')
    end
    
    if filters[:due_soon] == 'true'
      scope = scope.where(
        :due_date.gte => Date.current,
        :due_date.lte => 7.days.from_now
      )
    end
    
    scope
  end
  
  def apply_sorting(scope, sort_by)
    case sort_by
    when 'priority'
      scope.order_by(priority_score: :desc, created_at: :desc)
    when 'due_date'
      scope.order_by(due_date: :asc, created_at: :desc)
    when 'created'
      scope.order_by(created_at: :desc)
    when 'updated'
      scope.order_by(updated_at: :desc)
    else
      scope.order_by(position: :asc, created_at: :desc)
    end
  end
end