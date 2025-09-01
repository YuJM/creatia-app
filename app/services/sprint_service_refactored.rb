# frozen_string_literal: true

# Sprint 관련 비즈니스 로직을 처리하는 Service (리팩토링 버전)
class SprintServiceRefactored
  include Dry::Monads[:result, :do]
  
  pattr_initialize [:organization!, :user]
  
  # Sprint 목록 조회
  def list(filters = {})
    scope = Sprint.where(organization_id: organization.id)
    
    # 필터 적용
    scope = scope.where(status: filters[:status]) if filters[:status].present?
    scope = scope.where(:start_date.gte => filters[:start_date]) if filters[:start_date].present?
    scope = scope.where(:end_date.lte => filters[:end_date]) if filters[:end_date].present?
    
    # 정렬
    scope = scope.order_by(start_date: :desc)
    
    # DTO로 변환
    sprints = scope.map { |sprint| Dto::SprintDto.from_model(sprint) }
    
    Success(sprints)
  end
  
  # 단일 Sprint 조회
  def find(sprint_id)
    sprint = Sprint.where(organization_id: organization.id, _id: sprint_id).first
    
    return Failure(:not_found) unless sprint
    
    Success(Dto::SprintDto.from_model(sprint))
  end
  
  # Sprint 생성
  def create(params)
    sprint = Sprint.new(
      params.merge(
        organization_id: organization.id,
        created_by_id: user.id
      )
    )
    
    if sprint.save
      Success(Dto::SprintDto.from_model(sprint))
    else
      Failure(sprint.errors)
    end
  end
  
  # Sprint 수정
  def update(sprint_id, params)
    sprint = Sprint.where(organization_id: organization.id, _id: sprint_id).first
    
    return Failure(:not_found) unless sprint
    
    if sprint.update(params)
      Success(Dto::SprintDto.from_model(sprint))
    else
      Failure(sprint.errors)
    end
  end
  
  # Sprint 활성화
  def activate(sprint_id)
    sprint = Sprint.where(organization_id: organization.id, _id: sprint_id).first
    
    return Failure(:not_found) unless sprint
    return Failure(:already_active) if sprint.active?
    
    # 다른 활성 Sprint 종료
    Sprint.where(organization_id: organization.id, status: 'active')
          .update_all(status: 'completed')
    
    sprint.status = 'active'
    sprint.started_at = Time.current
    
    if sprint.save
      Success(Dto::SprintDto.from_model(sprint))
    else
      Failure(sprint.errors)
    end
  end
  
  # Sprint 완료
  def complete(sprint_id)
    sprint = Sprint.where(organization_id: organization.id, _id: sprint_id).first
    
    return Failure(:not_found) unless sprint
    return Failure(:not_active) unless sprint.active?
    
    sprint.status = 'completed'
    sprint.completed_at = Time.current
    
    if sprint.save
      Success(Dto::SprintDto.from_model(sprint))
    else
      Failure(sprint.errors)
    end
  end
  
  # Sprint Board 데이터
  def board(sprint_id)
    sprint = Sprint.where(organization_id: organization.id, _id: sprint_id).first
    
    return Failure(:not_found) unless sprint
    
    # Task를 상태별로 그룹화
    tasks_by_status = Task.where(sprint_id: sprint_id)
                          .group_by(&:status)
                          .transform_values { |tasks| tasks.map { |t| Dto::TaskDto.from_model(t) } }
    
    board_data = Dto::SprintBoardDto.new(
      sprint: Dto::SprintDto.from_model(sprint),
      columns: [
        { status: 'todo', title: 'To Do', tasks: tasks_by_status['todo'] || [] },
        { status: 'in_progress', title: 'In Progress', tasks: tasks_by_status['in_progress'] || [] },
        { status: 'review', title: 'Review', tasks: tasks_by_status['review'] || [] },
        { status: 'done', title: 'Done', tasks: tasks_by_status['done'] || [] }
      ],
      statistics: calculate_sprint_statistics(sprint)
    )
    
    Success(board_data)
  end
  
  # Sprint 통계
  def statistics(sprint_id)
    sprint = Sprint.where(organization_id: organization.id, _id: sprint_id).first
    
    return Failure(:not_found) unless sprint
    
    Success(calculate_sprint_statistics(sprint))
  end
  
  # Burndown Chart 데이터
  def burndown_chart(sprint_id)
    sprint = Sprint.where(organization_id: organization.id, _id: sprint_id).first
    
    return Failure(:not_found) unless sprint
    
    chart_data = generate_burndown_data(sprint)
    
    Success(chart_data)
  end
  
  private
  
  def calculate_sprint_statistics(sprint)
    tasks = Task.where(sprint_id: sprint.id)
    
    {
      total_tasks: tasks.count,
      completed_tasks: tasks.where(status: 'done').count,
      in_progress_tasks: tasks.where(status: 'in_progress').count,
      total_points: tasks.sum(&:story_points) || 0,
      completed_points: tasks.where(status: 'done').sum(&:story_points) || 0,
      velocity: calculate_velocity(sprint),
      days_remaining: calculate_days_remaining(sprint),
      completion_rate: calculate_completion_rate(tasks)
    }
  end
  
  def calculate_velocity(sprint)
    return 0 unless sprint.active? || sprint.completed?
    
    elapsed_days = (Date.current - sprint.start_date).to_i + 1
    completed_points = Task.where(sprint_id: sprint.id, status: 'done').sum(&:story_points) || 0
    
    (completed_points.to_f / elapsed_days).round(2)
  end
  
  def calculate_days_remaining(sprint)
    return 0 if sprint.completed?
    [(sprint.end_date - Date.current).to_i, 0].max
  end
  
  def calculate_completion_rate(tasks)
    return 0 if tasks.count.zero?
    ((tasks.where(status: 'done').count.to_f / tasks.count) * 100).round(1)
  end
  
  def generate_burndown_data(sprint)
    total_points = Task.where(sprint_id: sprint.id).sum(&:story_points) || 0
    days = (sprint.end_date - sprint.start_date).to_i + 1
    
    ideal_line = (0..days).map do |day|
      remaining = total_points - (total_points.to_f / days * day)
      { day: day, points: remaining.round(1) }
    end
    
    # 실제 진행 데이터 (여기서는 간단한 예시)
    actual_line = calculate_actual_burndown(sprint)
    
    {
      ideal: ideal_line,
      actual: actual_line,
      total_points: total_points,
      days: days
    }
  end
  
  def calculate_actual_burndown(sprint)
    # 실제 구현에서는 TaskHistory나 Activity 로그를 사용
    # 여기서는 간단한 예시
    completed_points = Task.where(sprint_id: sprint.id, status: 'done').sum(&:story_points) || 0
    total_points = Task.where(sprint_id: sprint.id).sum(&:story_points) || 0
    days_elapsed = (Date.current - sprint.start_date).to_i + 1
    
    (0..days_elapsed).map do |day|
      if day == days_elapsed
        { day: day, points: total_points - completed_points }
      else
        { day: day, points: total_points }
      end
    end
  end
end