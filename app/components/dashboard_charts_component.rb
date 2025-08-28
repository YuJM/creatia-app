# frozen_string_literal: true

class DashboardChartsComponent < ViewComponent::Base
  def initialize(chart_data:)
    @chart_data = chart_data
  end

  private

  attr_reader :chart_data

  def velocity_chart_data
    return [] unless chart_data[:velocity_trend].present?
    
    chart_data[:velocity_trend].map do |point|
      {
        label: point[:week],
        value: point[:velocity],
        tasks_completed: point[:tasks_completed]
      }
    end
  end

  def burndown_chart_data
    return {} unless chart_data[:burndown_data].present?
    
    data = chart_data[:burndown_data]
    
    {
      labels: data.map { |point| point[:date] },
      actual: data.map { |point| point[:remaining] },
      ideal: calculate_ideal_burndown_line(data)
    }
  end

  def workload_distribution_data
    return [] unless chart_data[:workload_distribution].present?
    
    chart_data[:workload_distribution].map do |user_id, hours|
      user = User.find_by(id: user_id)
      next unless user
      
      {
        user: user.email,
        hours: hours.round(1),
        percentage: calculate_workload_percentage(hours),
        status: workload_status(hours)
      }
    end.compact.sort_by { |data| -data[:hours] }
  end

  def completion_rates_data
    return {} unless chart_data[:completion_rates].present?
    
    data = chart_data[:completion_rates]
    
    {
      by_priority: format_priority_data(data[:by_priority]),
      by_assignee: format_assignee_data(data[:by_assignee]),
      by_day: format_daily_data(data[:by_day])
    }
  end

  def velocity_trend_summary
    data = velocity_chart_data
    return nil if data.size < 2
    
    recent_velocity = data.last(2).map { |point| point[:value] }
    trend = recent_velocity.last > recent_velocity.first ? "증가" : "감소"
    
    {
      trend: trend,
      current: data.last[:value].round(1),
      change: (recent_velocity.last - recent_velocity.first).round(1),
      trend_class: trend == "증가" ? "text-green-600" : "text-red-600"
    }
  end

  def burndown_analysis
    data = burndown_chart_data
    return nil if data[:actual].empty? || data[:ideal].empty?
    
    actual_remaining = data[:actual].last
    ideal_remaining = data[:ideal].last
    
    {
      on_track: actual_remaining <= ideal_remaining,
      variance: actual_remaining - ideal_remaining,
      completion_forecast: calculate_completion_forecast(data[:actual])
    }
  end

  def workload_balance_score
    data = workload_distribution_data
    return nil if data.empty?
    
    hours = data.map { |item| item[:hours] }
    average = hours.sum / hours.size
    variance = hours.sum { |h| (h - average) ** 2 } / hours.size
    
    # 정규화된 균형 점수 (0-100)
    balance_score = [100 - (Math.sqrt(variance) / average * 100), 0].max.round(1)
    
    {
      score: balance_score,
      status: case balance_score
              when 80..100 then "우수"
              when 60...80 then "양호" 
              when 40...60 then "보통"
              else "개선 필요"
              end,
      overloaded_count: data.count { |item| item[:hours] > 40 }
    }
  end

  def show_velocity_chart?
    velocity_chart_data.any?
  end

  def show_burndown_chart?
    burndown_chart_data[:actual]&.any?
  end

  def show_workload_chart?
    workload_distribution_data.any?
  end

  def show_completion_chart?
    completion_rates_data[:by_day]&.any?
  end

  # SVG 차트 생성 메서드들
  def velocity_chart_svg
    return "" unless show_velocity_chart?
    
    data = velocity_chart_data
    max_value = data.map { |point| point[:value] }.max
    
    generate_line_chart_svg(
      data.map { |point| point[:value] },
      data.map { |point| point[:label] },
      max_value,
      "velocity-chart"
    )
  end

  def burndown_chart_svg
    return "" unless show_burndown_chart?
    
    data = burndown_chart_data
    max_value = [data[:actual].max, data[:ideal].max].compact.max
    
    generate_multi_line_chart_svg(
      [
        { data: data[:actual], color: "#ef4444", name: "실제" },
        { data: data[:ideal], color: "#3b82f6", name: "이상적" }
      ],
      data[:labels],
      max_value,
      "burndown-chart"
    )
  end

  def workload_chart_svg
    return "" unless show_workload_chart?
    
    data = workload_distribution_data
    
    generate_bar_chart_svg(
      data.map { |item| item[:hours] },
      data.map { |item| truncate(item[:user], length: 15) },
      data.map { |item| item[:hours] }.max,
      "workload-chart"
    )
  end

  private

  def calculate_ideal_burndown_line(data)
    return [] if data.empty?
    
    total_tasks = data.first[:remaining]
    days_count = data.size
    
    data.map.with_index do |_, index|
      remaining_ratio = [(days_count - index - 1).to_f / (days_count - 1), 0].max
      (total_tasks * remaining_ratio).round
    end
  end

  def calculate_workload_percentage(hours)
    total_hours = chart_data[:workload_distribution]&.values&.sum || 1
    (hours / total_hours * 100).round(1)
  end

  def workload_status(hours)
    case hours
    when 0...20 then "여유"
    when 20...35 then "적정"
    when 35...45 then "포화"
    else "과부하"
    end
  end

  def format_priority_data(data)
    return {} unless data.present?
    
    %w[urgent high medium low].map do |priority|
      priority_data = data[priority]
      next unless priority_data
      
      {
        priority: priority,
        label: priority_label(priority),
        completed: priority_data[:completed],
        total: priority_data[:total],
        rate: priority_data[:rate],
        color: priority_color(priority)
      }
    end.compact
  end

  def format_assignee_data(data)
    return [] unless data.present?
    
    data.map do |email, assignee_data|
      {
        assignee: email,
        completed: assignee_data[:completed],
        total: assignee_data[:total],
        rate: assignee_data[:rate]
      }
    end.sort_by { |item| -item[:rate] }
  end

  def format_daily_data(data)
    return [] unless data.present?
    
    data.sort_by { |item| Date.parse(item[:date]) rescue Date.current }
  end

  def calculate_completion_forecast(actual_data)
    return nil if actual_data.size < 3
    
    # 최근 3일 데이터로 완료 속도 계산
    recent_data = actual_data.last(3)
    completion_rate = (recent_data.first - recent_data.last).to_f / (recent_data.size - 1)
    
    return nil if completion_rate <= 0
    
    days_to_completion = (recent_data.last / completion_rate).ceil
    forecast_date = Date.current + days_to_completion.days
    
    {
      days: days_to_completion,
      date: forecast_date,
      daily_rate: completion_rate.round(1)
    }
  end

  def priority_label(priority)
    {
      'urgent' => '긴급',
      'high' => '높음', 
      'medium' => '보통',
      'low' => '낮음'
    }[priority] || priority
  end

  def priority_color(priority)
    {
      'urgent' => '#ef4444',
      'high' => '#f97316',
      'medium' => '#eab308', 
      'low' => '#22c55e'
    }[priority] || '#6b7280'
  end

  # SVG 차트 생성 유틸리티 메서드들
  def generate_line_chart_svg(data_points, labels, max_value, chart_id)
    return "" if data_points.empty?
    
    width = 400
    height = 200
    padding = 40
    
    points = data_points.map.with_index do |value, index|
      x = padding + (index.to_f / (data_points.size - 1)) * (width - 2 * padding)
      y = height - padding - (value.to_f / max_value) * (height - 2 * padding)
      "#{x.round(2)},#{y.round(2)}"
    end
    
    <<~SVG
      <svg width="#{width}" height="#{height}" viewBox="0 0 #{width} #{height}" class="#{chart_id}">
        <polyline points="#{points.join(' ')}" 
                  fill="none" 
                  stroke="#3b82f6" 
                  stroke-width="2"/>
        
        #{points.map.with_index do |point, index|
          x, y = point.split(',').map(&:to_f)
          <<~CIRCLE
            <circle cx="#{x}" cy="#{y}" r="4" fill="#3b82f6"/>
            <text x="#{x}" y="#{height - 10}" text-anchor="middle" font-size="12" fill="#6b7280">
              #{labels[index]}
            </text>
          CIRCLE
        end.join}
      </svg>
    SVG
  end

  def generate_multi_line_chart_svg(datasets, labels, max_value, chart_id)
    return "" if datasets.empty?
    
    width = 400
    height = 200
    padding = 40
    
    lines = datasets.map do |dataset|
      points = dataset[:data].map.with_index do |value, index|
        x = padding + (index.to_f / (dataset[:data].size - 1)) * (width - 2 * padding)
        y = height - padding - (value.to_f / max_value) * (height - 2 * padding)
        "#{x.round(2)},#{y.round(2)}"
      end
      
      <<~LINE
        <polyline points="#{points.join(' ')}" 
                  fill="none" 
                  stroke="#{dataset[:color]}" 
                  stroke-width="2"
                  stroke-dasharray="#{dataset[:name] == '이상적' ? '5,5' : 'none'}"/>
      LINE
    end
    
    <<~SVG
      <svg width="#{width}" height="#{height}" viewBox="0 0 #{width} #{height}" class="#{chart_id}">
        #{lines.join}
      </svg>
    SVG
  end

  def generate_bar_chart_svg(data_points, labels, max_value, chart_id)
    return "" if data_points.empty?
    
    width = 400
    height = 200
    padding = 40
    bar_width = (width - 2 * padding) / data_points.size * 0.8
    
    bars = data_points.map.with_index do |value, index|
      x = padding + index * (width - 2 * padding) / data_points.size
      bar_height = (value.to_f / max_value) * (height - 2 * padding)
      y = height - padding - bar_height
      
      color = value > 40 ? "#ef4444" : value > 30 ? "#f59e0b" : "#3b82f6"
      
      <<~BAR
        <rect x="#{x}" y="#{y}" width="#{bar_width}" height="#{bar_height}" fill="#{color}"/>
        <text x="#{x + bar_width/2}" y="#{height - 5}" text-anchor="middle" font-size="10" fill="#6b7280">
          #{labels[index]}
        </text>
      BAR
    end
    
    <<~SVG
      <svg width="#{width}" height="#{height}" viewBox="0 0 #{width} #{height}" class="#{chart_id}">
        #{bars.join}
      </svg>
    SVG
  end
end