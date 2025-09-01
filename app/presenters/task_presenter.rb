# frozen_string_literal: true

# Task 모델을 View에서 사용하기 위한 Presenter
# 비즈니스 로직과 표현 로직을 분리
class TaskPresenter
  delegate :id, :title, :description, :status, :priority, :due_date, 
           :assignee_id, :created_at, :updated_at, to: :@task
  
  def initialize(task)
    @task = task
  end
  
  def status_badge_color
    case status
    when 'todo' then 'bg-gray-100 text-gray-800'
    when 'in_progress' then 'bg-blue-100 text-blue-800'
    when 'review' then 'bg-yellow-100 text-yellow-800'
    when 'done' then 'bg-green-100 text-green-800'
    else 'bg-gray-100 text-gray-800'
    end
  end
  
  def priority_badge_color
    case priority
    when 'urgent' then 'bg-red-100 text-red-800'
    when 'high' then 'bg-orange-100 text-orange-800'
    when 'medium' then 'bg-yellow-100 text-yellow-800'
    when 'low' then 'bg-gray-100 text-gray-800'
    else 'bg-gray-100 text-gray-800'
    end
  end
  
  def assignee_name
    @assignee_name ||= assignee&.name || 'Unassigned'
  end
  
  def assignee_avatar
    @assignee_avatar ||= assignee&.avatar_url || '/default-avatar.png'
  end
  
  def formatted_due_date
    return 'No due date' unless due_date
    
    if due_date < Date.current
      "Overdue by #{(Date.current - due_date).to_i} days"
    elsif due_date == Date.current
      'Due today'
    elsif due_date == Date.current + 1
      'Due tomorrow'
    else
      "Due in #{(due_date - Date.current).to_i} days"
    end
  end
  
  def due_date_color
    return 'text-gray-500' unless due_date
    
    if due_date < Date.current
      'text-red-600'
    elsif due_date <= Date.current + 2
      'text-yellow-600'
    else
      'text-gray-600'
    end
  end
  
  def progress_percentage
    case status
    when 'todo' then 0
    when 'in_progress' then 50
    when 'review' then 75
    when 'done' then 100
    else 0
    end
  end
  
  def is_overdue?
    due_date && due_date < Date.current && status != 'done'
  end
  
  def is_urgent?
    priority == 'urgent' || (is_overdue? && status != 'done')
  end
  
  private
  
  def assignee
    @assignee ||= User.cached_find(@task.assignee_id)
  end
end