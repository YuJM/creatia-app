# frozen_string_literal: true

class SprintPlanComponent < ViewComponent::Base
  def initialize(sprint:, sprint_plan:, dependency_analysis: nil, risk_assessment: nil)
    @sprint = sprint
    @sprint_plan = sprint_plan
    @dependency_analysis = dependency_analysis || {}
    @risk_assessment = risk_assessment
  end

  private

  attr_reader :sprint, :sprint_plan, :dependency_analysis, :risk_assessment

  def workload_distribution_data
    return [] unless sprint_plan.workload_distribution.present?
    
    sprint_plan.workload_distribution.map do |user_id, hours|
      user = User.find_by(id: user_id)
      next unless user
      
      {
        user: user,
        hours: hours.round(1),
        percentage: (hours.to_f / total_workload * 100).round(1),
        status: workload_status(hours),
        tasks_count: user_tasks_count(user)
      }
    end.compact.sort_by { |data| -data[:hours] }
  end

  def total_workload
    @total_workload ||= sprint_plan.workload_distribution.values.sum
  end

  def average_workload
    return 0 if workload_distribution_data.empty?
    
    (total_workload / workload_distribution_data.size).round(1)
  end

  def workload_status(hours)
    case hours
    when 0...20
      { text: "여유", class: "bg-green-100 text-green-800" }
    when 20...35
      { text: "적정", class: "bg-blue-100 text-blue-800" }
    when 35...45
      { text: "포화", class: "bg-yellow-100 text-yellow-800" }
    else
      { text: "과부하", class: "bg-red-100 text-red-800" }
    end
  end

  def user_tasks_count(user)
    sprint.tasks.where(assigned_user: user).count
  end

  def critical_path_tasks
    return [] unless dependency_analysis[:critical_path]
    
    task_ids = dependency_analysis[:critical_path]
    Task.where(id: task_ids).includes(:assigned_user).order(:position)
  end

  def dependency_complexity_status
    return nil unless dependency_analysis[:complexity_score]
    
    score = dependency_analysis[:complexity_score]
    
    case score
    when 0...0.3
      { text: "단순", class: "text-green-600", description: "의존성이 적어 관리가 용이합니다" }
    when 0.3...0.7
      { text: "보통", class: "text-yellow-600", description: "적당한 의존성으로 주의가 필요합니다" }
    else
      { text: "복잡", class: "text-red-600", description: "높은 의존성으로 세심한 관리가 필요합니다" }
    end
  end

  def risk_indicators
    return [] unless risk_assessment
    
    indicators = []
    
    if risk_assessment.high_complexity?
      indicators << {
        type: "complexity",
        text: "높은 복잡도",
        description: "작업의 복잡도가 평균보다 높습니다",
        severity: "high"
      }
    end
    
    if risk_assessment.timeline_risk > 0.7
      indicators << {
        type: "timeline", 
        text: "일정 위험",
        description: "마감일 내 완료가 어려울 수 있습니다",
        severity: "high"
      }
    end
    
    if risk_assessment.resource_availability < 0.6
      indicators << {
        type: "resource",
        text: "리소스 부족",
        description: "필요한 인력이 부족할 수 있습니다", 
        severity: "medium"
      }
    end
    
    indicators
  end

  def risk_severity_class(severity)
    case severity
    when "high"
      "bg-red-50 border-red-200 text-red-800"
    when "medium"
      "bg-yellow-50 border-yellow-200 text-yellow-800"
    else
      "bg-blue-50 border-blue-200 text-blue-800"
    end
  end

  def estimated_completion_date
    return nil unless sprint_plan.estimated_effort && average_daily_capacity > 0
    
    days_needed = (sprint_plan.estimated_effort / average_daily_capacity).ceil
    sprint.start_date + days_needed.days
  end

  def average_daily_capacity
    return 0 if workload_distribution_data.empty?
    
    working_days = calculate_working_days
    return 0 if working_days <= 0
    
    total_workload / working_days
  end

  def calculate_working_days
    return 0 unless sprint.start_date && sprint.end_date
    
    days = 0
    current_date = sprint.start_date
    
    while current_date <= sprint.end_date
      days += 1 unless current_date.weekend?
      current_date += 1.day
    end
    
    days
  end

  def completion_probability
    return nil unless risk_assessment
    
    # 기본 확률에서 리스크 요소들을 차감
    base_probability = 0.8
    
    risk_factors = [
      risk_assessment.complexity_score * 0.2,
      risk_assessment.timeline_risk * 0.3,
      (1 - risk_assessment.resource_availability) * 0.2
    ]
    
    probability = base_probability - risk_factors.sum
    [(probability * 100).round, 10].max # 최소 10%
  end

  def completion_probability_class
    return "" unless completion_probability
    
    case completion_probability
    when 80..100
      "text-green-600"
    when 60...80
      "text-yellow-600"
    else
      "text-red-600"
    end
  end

  def milestone_tasks
    sprint.tasks.where.not(due_date: nil)
                .order(:due_date)
                .limit(5)
                .includes(:assigned_user)
  end

  def bottleneck_users
    return [] if workload_distribution_data.empty?
    
    threshold = average_workload * 1.3
    workload_distribution_data.select { |data| data[:hours] > threshold }
  end

  def recommendations
    recommendations = []
    
    # 과부하된 사용자가 있는 경우
    if bottleneck_users.any?
      recommendations << {
        type: "workload",
        title: "업무 재분배 권장",
        message: "일부 팀원의 업무량이 과도합니다. 작업을 재분배하는 것을 고려하세요.",
        priority: "high",
        affected_users: bottleneck_users.map { |data| data[:user].email }
      }
    end
    
    # 높은 의존성 복잡도
    if dependency_analysis[:complexity_score] && dependency_analysis[:complexity_score] > 0.7
      recommendations << {
        type: "dependency",
        title: "의존성 관리 강화",
        message: "작업간 의존성이 복잡합니다. 정기적인 동기화 회의를 권장합니다.",
        priority: "medium"
      }
    end
    
    # 리스크가 높은 경우
    if risk_assessment&.high_risk?
      recommendations << {
        type: "risk",
        title: "리스크 완화 조치",
        message: "스프린트 리스크가 높습니다. 범위를 축소하거나 추가 리소스를 확보하세요.",
        priority: "high"
      }
    end
    
    recommendations
  end

  def recommendation_priority_class(priority)
    case priority
    when "high"
      "border-l-red-500 bg-red-50"
    when "medium"
      "border-l-yellow-500 bg-yellow-50"
    else
      "border-l-blue-500 bg-blue-50"
    end
  end

  def show_detailed_analysis?
    dependency_analysis.present? || risk_assessment.present?
  end

  def show_workload_distribution?
    sprint_plan.workload_distribution.present? && !sprint_plan.workload_distribution.empty?
  end

  def show_critical_path?
    critical_path_tasks.any?
  end

  def show_recommendations?
    recommendations.any?
  end
end