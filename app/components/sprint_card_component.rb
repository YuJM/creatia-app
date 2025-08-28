# frozen_string_literal: true

class SprintCardComponent < ViewComponent::Base
  def initialize(sprint:, sprint_plan: nil, team_metrics: nil)
    @sprint = sprint
    @sprint_plan = sprint_plan
    @team_metrics = team_metrics
  end

  private

  attr_reader :sprint, :sprint_plan, :team_metrics

  def progress_percentage
    return 0 if sprint.tasks.empty?
    
    completed_tasks = sprint.tasks.done.count
    total_tasks = sprint.tasks.count
    
    (completed_tasks.to_f / total_tasks * 100).round(1)
  end

  def progress_bar_color
    percentage = progress_percentage
    
    case percentage
    when 0...25
      "bg-red-500"
    when 25...50
      "bg-yellow-500"  
    when 50...75
      "bg-blue-500"
    when 75...90
      "bg-green-500"
    else
      "bg-emerald-500"
    end
  end

  def status_badge_class
    case sprint.status
    when 'planning'
      "bg-gray-100 text-gray-800"
    when 'active'
      "bg-blue-100 text-blue-800"
    when 'completed'
      "bg-green-100 text-green-800"
    when 'cancelled'
      "bg-red-100 text-red-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end

  def status_display_name
    case sprint.status
    when 'planning'
      "계획 중"
    when 'active'
      "진행 중"
    when 'completed'
      "완료"
    when 'cancelled'
      "취소됨"
    else
      "알 수 없음"
    end
  end

  def sprint_duration
    return "기간 미설정" unless sprint.start_date && sprint.end_date
    
    duration = (sprint.end_date - sprint.start_date).to_i
    "#{duration}일"
  end

  def days_remaining
    return nil unless sprint.end_date && sprint.status == 'active'
    
    remaining = (sprint.end_date - Date.current).to_i
    
    if remaining > 0
      "#{remaining}일 남음"
    elsif remaining == 0
      "오늘 마감"
    else
      "#{remaining.abs}일 지연"
    end
  end

  def days_remaining_class
    return "" unless sprint.end_date && sprint.status == 'active'
    
    remaining = (sprint.end_date - Date.current).to_i
    
    if remaining > 3
      "text-green-600"
    elsif remaining > 0
      "text-yellow-600"  
    else
      "text-red-600"
    end
  end

  def velocity_status
    return nil unless team_metrics&.velocity
    
    case team_metrics.velocity
    when 0...3
      { text: "낮음", class: "text-red-600" }
    when 3...6
      { text: "보통", class: "text-yellow-600" }
    else
      { text: "높음", class: "text-green-600" }
    end
  end

  def capacity_utilization
    return nil unless team_metrics&.capacity && sprint_plan&.estimated_effort
    
    utilization = (sprint_plan.estimated_effort / team_metrics.capacity * 100).round(1)
    
    {
      percentage: utilization,
      status: case utilization
              when 0...70
                { text: "여유", class: "text-green-600" }
              when 70...90
                { text: "적정", class: "text-blue-600" }
              when 90...110
                { text: "포화", class: "text-yellow-600" }
              else
                { text: "초과", class: "text-red-600" }
              end
    }
  end

  def risk_level
    return nil unless sprint_plan&.risk_score
    
    case sprint_plan.risk_score
    when 0...0.3
      { text: "낮음", class: "bg-green-100 text-green-800" }
    when 0.3...0.7
      { text: "보통", class: "bg-yellow-100 text-yellow-800" }
    else
      { text: "높음", class: "bg-red-100 text-red-800" }
    end
  end

  def task_breakdown
    return {} if sprint.tasks.empty?
    
    {
      todo: sprint.tasks.todo.count,
      in_progress: sprint.tasks.in_progress.count,
      review: sprint.tasks.review.count,
      done: sprint.tasks.done.count
    }
  end

  def priority_breakdown
    return {} if sprint.tasks.empty?
    
    {
      urgent: sprint.tasks.urgent.count,
      high: sprint.tasks.high_priority.count,
      medium: sprint.tasks.medium_priority.count,
      low: sprint.tasks.low_priority.count
    }
  end

  def team_workload_summary
    return nil unless sprint_plan&.workload_distribution
    
    workload = sprint_plan.workload_distribution
    return nil if workload.empty?
    
    total_hours = workload.values.sum
    average_hours = (total_hours.to_f / workload.size).round(1)
    
    {
      total_hours: total_hours,
      average_hours: average_hours,
      team_size: workload.size,
      max_hours: workload.values.max,
      min_hours: workload.values.min
    }
  end

  def burndown_trend
    return nil unless team_metrics&.burndown_data&.any?
    
    data = team_metrics.burndown_data
    return nil if data.length < 2
    
    recent_change = data.last[:remaining] - data[-2][:remaining]
    
    case recent_change
    when Float::INFINITY..-1
      { trend: "개선", class: "text-green-600", icon: "↓" }
    when 0
      { trend: "정체", class: "text-yellow-600", icon: "→" }  
    else
      { trend: "악화", class: "text-red-600", icon: "↑" }
    end
  end
  
  def show_metrics?
    team_metrics.present?
  end
  
  def show_planning?
    sprint_plan.present?
  end
  
  def card_border_class
    case sprint.status
    when 'active'
      "border-l-4 border-l-blue-500"
    when 'completed'
      "border-l-4 border-l-green-500"
    when 'cancelled'
      "border-l-4 border-l-red-500"
    else
      "border-l-4 border-l-gray-300"
    end
  end
end