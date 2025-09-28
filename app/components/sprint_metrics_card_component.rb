# frozen_string_literal: true

class SprintMetricsCardComponent < ViewComponent::Base
  def initialize(sprint:, team_metrics:)
    @sprint = sprint
    @team_metrics = team_metrics
  end

  private

  attr_reader :sprint, :team_metrics

  def velocity_chart_data
    return [] unless team_metrics.burndown_data.present?
    
    team_metrics.burndown_data.last(7).map do |data|
      {
        date: data[:date].strftime('%m/%d'),
        remaining: data[:remaining],
        ideal: data[:ideal]
      }
    end
  end

  def velocity_status
    case team_metrics.velocity
    when 0...3
      { text: "낮음", class: "text-red-600 bg-red-50", icon: "📉" }
    when 3...6
      { text: "보통", class: "text-yellow-600 bg-yellow-50", icon: "📊" }
    when 6...10
      { text: "높음", class: "text-green-600 bg-green-50", icon: "📈" }
    else
      { text: "매우 높음", class: "text-emerald-600 bg-emerald-50", icon: "🚀" }
    end
  end

  def capacity_status
    case team_metrics.capacity
    when 0...100
      { text: "부족", class: "text-red-600 bg-red-50", description: "추가 리소스 필요" }
    when 100...200
      { text: "적정", class: "text-green-600 bg-green-50", description: "균형잡힌 용량" }
    when 200...300
      { text: "충분", class: "text-blue-600 bg-blue-50", description: "여유 있는 용량" }
    else
      { text: "과다", class: "text-yellow-600 bg-yellow-50", description: "과도한 용량" }
    end
  end

  def burndown_trend_data
    return {} unless team_metrics.burndown_data.present? && team_metrics.burndown_data.size >= 2
    
    recent_data = team_metrics.burndown_data.last(3)
    return {} if recent_data.size < 2
    
    actual_change = recent_data.last[:remaining] - recent_data.first[:remaining]
    ideal_change = recent_data.last[:ideal] - recent_data.first[:ideal]
    
    {
      actual_change: actual_change,
      ideal_change: ideal_change,
      trend: actual_change <= ideal_change ? "좋음" : "나쁨",
      trend_class: actual_change <= ideal_change ? "text-green-600" : "text-red-600"
    }
  end

  def completion_forecast
    return nil unless team_metrics.burndown_data.present? && team_metrics.burndown_data.size >= 3
    
    # 최근 3일간의 완료 속도 계산
    recent_data = team_metrics.burndown_data.last(3)
    completed_per_day = (recent_data.first[:remaining] - recent_data.last[:remaining]).to_f / (recent_data.size - 1)
    
    return nil if completed_per_day <= 0
    
    remaining_tasks = recent_data.last[:remaining]
    days_to_completion = (remaining_tasks / completed_per_day).ceil
    forecast_date = Date.current + days_to_completion.days
    
    {
      days: days_to_completion,
      date: forecast_date,
      on_time: forecast_date <= sprint.end_date
    }
  end

  def team_performance_indicators
    indicators = []
    
    # 속도 지표
    velocity_status_data = velocity_status
    indicators << {
      label: "팀 속도",
      value: "#{team_metrics.velocity.round(1)} 작업/주",
      status: velocity_status_data[:text],
      class: velocity_status_data[:class],
      icon: velocity_status_data[:icon]
    }
    
    # 용량 활용도
    capacity_status_data = capacity_status
    indicators << {
      label: "용량 활용",
      value: "#{team_metrics.capacity.round(1)}시간",
      status: capacity_status_data[:text],
      class: capacity_status_data[:class],
      description: capacity_status_data[:description]
    }
    
    # 완료율
    completion_rate = team_metrics.completion_rate || 0
    completion_status = case completion_rate
                       when 0...25 then { text: "시작", class: "text-gray-600 bg-gray-50" }
                       when 25...50 then { text: "진행", class: "text-blue-600 bg-blue-50" }
                       when 50...75 then { text: "활발", class: "text-green-600 bg-green-50" }
                       when 75...90 then { text: "마무리", class: "text-emerald-600 bg-emerald-50" }
                       else { text: "완료", class: "text-purple-600 bg-purple-50" }
                       end
    
    indicators << {
      label: "완료율",
      value: "#{completion_rate.round(1)}%",
      status: completion_status[:text],
      class: completion_status[:class]
    }
    
    indicators
  end

  def burndown_chart_points
    return [] unless team_metrics.burndown_data.present?
    
    data = team_metrics.burndown_data
    max_remaining = data.map { |d| d[:remaining] }.max
    return [] if max_remaining == 0
    
    # SVG 좌표계로 변환 (200x100 크기)
    width = 200
    height = 100
    
    data.map.with_index do |point, index|
      x = (index.to_f / (data.size - 1)) * width
      y = height - (point[:remaining].to_f / max_remaining) * height
      
      { x: x.round(2), y: y.round(2), remaining: point[:remaining] }
    end
  end

  def ideal_line_points
    return [] unless team_metrics.burndown_data.present?
    
    data = team_metrics.burndown_data
    max_remaining = data.map { |d| d[:remaining] }.max
    return [] if max_remaining == 0
    
    width = 200
    height = 100
    
    data.map.with_index do |point, index|
      x = (index.to_f / (data.size - 1)) * width
      y = height - (point[:ideal].to_f / max_remaining) * height
      
      { x: x.round(2), y: y.round(2) }
    end
  end

  def risk_warnings
    warnings = []
    
    # 번다운 트렌드가 나쁜 경우
    trend_data = burndown_trend_data
    if trend_data.present? && trend_data[:trend] == "나쁨"
      warnings << {
        type: "burndown",
        message: "번다운 차트가 이상적인 선보다 위에 있습니다",
        severity: "medium"
      }
    end
    
    # 예상 완료일이 늦는 경우
    forecast = completion_forecast
    if forecast.present? && !forecast[:on_time]
      days_late = (forecast[:date] - sprint.end_date).to_i
      warnings << {
        type: "schedule",
        message: "현재 속도로는 #{days_late}일 늦게 완료될 예정입니다",
        severity: "high"
      }
    end
    
    # 속도가 너무 낮은 경우
    if team_metrics.velocity < 2
      warnings << {
        type: "velocity",
        message: "팀 속도가 평균보다 낮습니다",
        severity: "medium"
      }
    end
    
    warnings
  end

  def warning_severity_class(severity)
    case severity
    when "high"
      "bg-red-50 border-red-200 text-red-800"
    when "medium"
      "bg-yellow-50 border-yellow-200 text-yellow-800"
    else
      "bg-blue-50 border-blue-200 text-blue-800"
    end
  end

  def show_burndown_chart?
    team_metrics.burndown_data.present? && team_metrics.burndown_data.size >= 2
  end

  def show_completion_forecast?
    completion_forecast.present?
  end

  def show_trend_analysis?
    burndown_trend_data.present?
  end

  def show_risk_warnings?
    risk_warnings.any?
  end

  def chart_svg_path(points)
    return "" if points.empty?
    
    path_data = points.map.with_index do |point, index|
      command = index == 0 ? "M" : "L"
      "#{command} #{point[:x]} #{point[:y]}"
    end
    
    path_data.join(" ")
  end
end