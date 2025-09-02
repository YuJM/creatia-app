# frozen_string_literal: true

require 'memo_wise'

# Dashboard 데이터를 준비하는 Service 레이어
# View에서 직접 모델을 호출하지 않도록 캡슐화
class DashboardService
  prepend MemoWise
  pattr_initialize [:organization!, :user]
  
  # Dashboard 메트릭 DTO 반환
  memo_wise def metrics
    Dto::DashboardMetrics.new(
      task_stats: task_statistics,
      member_stats: member_statistics,
      activity_stats: activity_statistics,
      recent_tasks: recent_tasks_list,
      upcoming_milestones: upcoming_milestones_list
    )
  end
  
  private
  
  def task_statistics
    tasks = Task.where(organization_id: organization.id.to_s)
    
    {
      total: tasks.count,
      completed: tasks.where(status: 'done').count,
      in_progress: tasks.where(status: 'in_progress').count,
      overdue: tasks.where(:due_date.lt => Date.current, :status.ne => 'done').count,
      completion_rate: calculate_completion_rate(tasks)
    }
  end
  
  def member_statistics
    memberships = organization.organization_memberships.active
    
    {
      total: memberships.count,
      active: memberships.joins(:user).where('users.last_sign_in_at > ?', 30.days.ago).count,
      owners: memberships.where(role: 'owner').count,
      admins: memberships.where(role: 'admin').count,
      members: memberships.where(role: 'member').count
    }
  end
  
  def activity_statistics
    {
      tasks_created_today: Task.where(
        organization_id: organization.id.to_s,
        :created_at.gte => Date.current.beginning_of_day
      ).count,
      tasks_completed_today: Task.where(
        organization_id: organization.id.to_s,
        status: 'done',
        :updated_at.gte => Date.current.beginning_of_day
      ).count,
      active_sprints: Sprint.where(
        organization_id: organization.id.to_s,
        status: 'active'
      ).count
    }
  end
  
  def recent_tasks_list
    Task.where(organization_id: organization.id.to_s)
        .order_by(created_at: :desc)
        .limit(5)
        .map { |task| Dto::TaskDto.from_model(task) }
  rescue => e
    Rails.logger.error "Error fetching recent tasks: #{e.message}"
    []
  end
  
  def upcoming_milestones_list
    Milestone.where(organization_id: organization.id.to_s)
             .upcoming
             .limit(3)
             .map { |milestone| Dto::MilestoneDto.from_model(milestone) }
  rescue => e
    Rails.logger.error "Error fetching upcoming milestones: #{e.message}"
    []
  end
  
  def calculate_completion_rate(tasks)
    total = tasks.count
    return 0.0 if total.zero?
    
    completed = tasks.where(status: 'done').count
    ((completed.to_f / total) * 100).round(1)
  end
end