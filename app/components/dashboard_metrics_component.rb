# frozen_string_literal: true

class DashboardMetricsComponent < ViewComponent::Base
  def initialize(dashboard_metrics:, chart_data: nil)
    @dashboard_metrics = dashboard_metrics
    @chart_data = chart_data || {}
  end

  private

  attr_reader :dashboard_metrics, :chart_data

  def velocity_status
    velocity = dashboard_metrics.velocity
    
    case velocity
    when 0...5
      { 
        text: "낮음", 
        class: "text-red-600 bg-red-50 border-red-200", 
        icon: "📉",
        description: "팀 속도가 평균 이하입니다" 
      }
    when 5...10
      { 
        text: "보통", 
        class: "text-yellow-600 bg-yellow-50 border-yellow-200", 
        icon: "📊",
        description: "적정 수준의 팀 속도입니다" 
      }
    when 10...15
      { 
        text: "높음", 
        class: "text-green-600 bg-green-50 border-green-200", 
        icon: "📈",
        description: "우수한 팀 속도입니다" 
      }
    else
      { 
        text: "매우 높음", 
        class: "text-emerald-600 bg-emerald-50 border-emerald-200", 
        icon: "🚀",
        description: "탁월한 팀 속도입니다" 
      }
    end
  end

  def capacity_utilization
    return nil unless dashboard_metrics.workload_distribution.present?
    
    total_workload = dashboard_metrics.workload_distribution.values.sum
    capacity = dashboard_metrics.capacity
    
    return nil if capacity <= 0
    
    utilization = (total_workload / capacity * 100).round(1)
    
    {
      percentage: utilization,
      status: case utilization
              when 0...60
                { text: "여유", class: "text-green-600 bg-green-50", description: "여유 있는 용량입니다" }
              when 60...80
                { text: "적정", class: "text-blue-600 bg-blue-50", description: "적절한 용량 활용입니다" }
              when 80...95
                { text: "포화", class: "text-yellow-600 bg-yellow-50", description: "용량이 거의 찬 상태입니다" }
              else
                { text: "초과", class: "text-red-600 bg-red-50", description: "용량을 초과한 상태입니다" }
              end
    }
  end

  def completion_trend
    return nil unless dashboard_metrics.burndown_data.present? && dashboard_metrics.burndown_data.size >= 3
    
    recent_data = dashboard_metrics.burndown_data.last(3)
    trend_slope = calculate_trend_slope(recent_data)
    
    case trend_slope
    when Float::INFINITY..-0.5
      { trend: "빠름", class: "text-green-600", icon: "⬇️", description: "작업 완료 속도가 빠릅니다" }
    when -0.5...0.5
      { trend: "보통", class: "text-blue-600", icon: "➡️", description: "일정한 속도로 진행 중입니다" }
    else
      { trend: "느림", class: "text-red-600", icon: "⬆️", description: "작업 완료 속도가 느립니다" }
    end
  end

  def workload_balance
    return nil unless dashboard_metrics.workload_distribution.present?
    
    workloads = dashboard_metrics.workload_distribution.values
    return nil if workloads.empty?
    
    average = workloads.sum.to_f / workloads.size
    variance = workloads.sum { |w| (w - average) ** 2 } / workloads.size
    std_deviation = Math.sqrt(variance)
    
    coefficient_of_variation = average > 0 ? (std_deviation / average) : 0
    
    case coefficient_of_variation
    when 0...0.3
      { 
        status: "균형", 
        class: "text-green-600 bg-green-50",
        description: "업무가 균등하게 분배되어 있습니다",
        score: (100 - coefficient_of_variation * 100).round(1)
      }
    when 0.3...0.6
      { 
        status: "보통", 
        class: "text-yellow-600 bg-yellow-50",
        description: "업무 분배에 약간의 불균형이 있습니다",
        score: (100 - coefficient_of_variation * 100).round(1)
      }
    else
      { 
        status: "불균형", 
        class: "text-red-600 bg-red-50",
        description: "업무 분배가 불균형합니다",
        score: (100 - coefficient_of_variation * 100).round(1)
      }
    end
  end

  def overdue_alert_level
    overdue_count = dashboard_metrics.overdue_tasks_count
    
    case overdue_count
    when 0
      { level: "safe", class: "text-green-600", message: "지연된 작업이 없습니다" }
    when 1..3
      { level: "warning", class: "text-yellow-600", message: "#{overdue_count}개 작업이 지연되었습니다" }
    when 4..10
      { level: "danger", class: "text-red-600", message: "#{overdue_count}개 작업이 지연되었습니다" }
    else
      { level: "critical", class: "text-red-700", message: "#{overdue_count}개 작업이 심각하게 지연되었습니다" }
    end
  end

  def cycle_time_status
    cycle_time = dashboard_metrics.average_cycle_time
    
    case cycle_time
    when 0...3
      { 
        status: "빠름", 
        class: "text-green-600", 
        description: "평균 #{cycle_time}일로 매우 빠른 처리 속도입니다" 
      }
    when 3...7
      { 
        status: "보통", 
        class: "text-blue-600", 
        description: "평균 #{cycle_time}일로 적절한 처리 속도입니다" 
      }
    when 7...14
      { 
        status: "느림", 
        class: "text-yellow-600", 
        description: "평균 #{cycle_time}일로 다소 느린 처리 속도입니다" 
      }
    else
      { 
        status: "매우 느림", 
        class: "text-red-600", 
        description: "평균 #{cycle_time}일로 매우 느린 처리 속도입니다" 
      }
    end
  end

  def priority_task_summary
    high_priority_count = dashboard_metrics.high_priority_tasks_count
    
    {
      count: high_priority_count,
      urgency_level: case high_priority_count
                    when 0
                      { text: "없음", class: "text-green-600" }
                    when 1..3
                      { text: "보통", class: "text-yellow-600" }
                    when 4..7
                      { text: "높음", class: "text-red-600" }
                    else
                      { text: "매우 높음", class: "text-red-700" }
                    end
    }
  end

  def today_progress
    today_completed = dashboard_metrics.tasks_completed_today
    week_completed = dashboard_metrics.tasks_completed_week
    
    daily_average = week_completed / 7.0
    
    {
      today: today_completed,
      average: daily_average.round(1),
      performance: case today_completed <=> daily_average
                  when 1
                    { status: "우수", class: "text-green-600", icon: "📈" }
                  when 0
                    { status: "평균", class: "text-blue-600", icon: "📊" }
                  else
                    { status: "저조", class: "text-yellow-600", icon: "📉" }
                  end
    }
  end

  def burndown_velocity
    return nil unless dashboard_metrics.burndown_data.present? && dashboard_metrics.burndown_data.size >= 7
    
    recent_week = dashboard_metrics.burndown_data.last(7)
    tasks_completed = recent_week.first[:remaining] - recent_week.last[:remaining]
    
    {
      weekly_completion: tasks_completed,
      daily_average: (tasks_completed / 7.0).round(1),
      trend: case tasks_completed
            when 0...10
              { text: "느림", class: "text-red-600" }
            when 10...20
              { text: "보통", class: "text-blue-600" }
            else
              { text: "빠름", class: "text-green-600" }
            end
    }
  end

  def show_capacity_utilization?
    capacity_utilization.present?
  end

  def show_completion_trend?
    completion_trend.present?
  end

  def show_workload_balance?
    workload_balance.present?
  end

  def show_burndown_velocity?
    burndown_velocity.present?
  end

  # 차트 데이터 관련 메서드들
  def velocity_chart_points
    return [] unless chart_data[:velocity].present?
    
    chart_data[:velocity].map { |point| point[:velocity] }
  end

  def velocity_chart_labels  
    return [] unless chart_data[:velocity].present?
    
    chart_data[:velocity].map { |point| point[:week] }
  end

  def burndown_chart_data
    return {} unless chart_data[:burndown_data].present?
    
    {
      labels: chart_data[:burndown_data].map { |point| point[:date] },
      remaining: chart_data[:burndown_data].map { |point| point[:remaining] },
      ideal: chart_data[:burndown_data].map { |point| point[:ideal] || 0 }
    }
  end

  private

  def calculate_trend_slope(data_points)
    return 0 if data_points.size < 2
    
    # 간단한 선형 회귀 기울기 계산
    n = data_points.size
    sum_x = (0...n).sum
    sum_y = data_points.sum { |point| point[:remaining] }
    sum_xy = data_points.each_with_index.sum { |point, i| point[:remaining] * i }
    sum_x2 = (0...n).sum { |i| i * i }
    
    denominator = (n * sum_x2 - sum_x * sum_x)
    return 0 if denominator == 0
    
    (n * sum_xy - sum_x * sum_y).to_f / denominator
  end
end