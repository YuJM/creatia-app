# frozen_string_literal: true

class RoadmapTimelineComponent < ViewComponent::Base
  def initialize(roadmap:, timeline_data:, view_mode: 'quarterly')
    @roadmap = roadmap
    @timeline_data = timeline_data
    @view_mode = view_mode
  end

  private

  attr_reader :roadmap, :timeline_data, :view_mode

  def timeline_milestones
    timeline_data[:milestones] || []
  end

  def timeline_span
    timeline_data[:timeline_span] || {}
  end

  def view_mode_options
    [
      { value: 'monthly', label: '월별 보기', icon: '📅' },
      { value: 'quarterly', label: '분기별 보기', icon: '📊' },
      { value: 'yearly', label: '연간 보기', icon: '📈' }
    ]
  end

  def milestone_positions
    return [] if timeline_milestones.empty? || timeline_span[:start_date].blank?

    start_date = Date.parse(timeline_span[:start_date].to_s)
    end_date = Date.parse(timeline_span[:end_date].to_s)
    total_days = (end_date - start_date).to_i
    
    timeline_milestones.map do |milestone|
      milestone_date = Date.parse(milestone[:target_date].to_s)
      days_from_start = (milestone_date - start_date).to_i
      
      {
        milestone: milestone,
        position: total_days > 0 ? (days_from_start.to_f / total_days * 100).round(2) : 0,
        date: milestone_date
      }
    end.sort_by { |item| item[:position] }
  end

  def milestone_status_class(milestone)
    case milestone[:status]
    when 'completed'
      'bg-green-500 text-white'
    when 'in_progress'
      'bg-blue-500 text-white'
    when 'at_risk'
      'bg-yellow-500 text-white'
    when 'delayed'
      'bg-red-500 text-white'
    else
      'bg-gray-500 text-white'
    end
  end

  def milestone_risk_indicator(milestone)
    case milestone[:risk_level]
    when 'low'
      { icon: '✅', class: 'text-green-600', label: '안전' }
    when 'medium'
      { icon: '⚠️', class: 'text-yellow-600', label: '주의' }
    when 'high'
      { icon: '🚨', class: 'text-red-600', label: '위험' }
    when 'critical'
      { icon: '💥', class: 'text-red-800', label: '심각' }
    else
      { icon: 'ℹ️', class: 'text-gray-600', label: '정보없음' }
    end
  end

  def progress_color(progress)
    case progress
    when 0...25
      'bg-red-500'
    when 25...50
      'bg-yellow-500'
    when 50...75
      'bg-blue-500'
    when 75..100
      'bg-green-500'
    else
      'bg-gray-400'
    end
  end

  def formatted_date(date_string)
    Date.parse(date_string.to_s).strftime('%Y.%m.%d')
  rescue
    '날짜 없음'
  end

  def days_until_milestone(milestone)
    target_date = Date.parse(milestone[:target_date].to_s)
    days = (target_date - Date.current).to_i
    
    if days < 0
      "#{days.abs}일 지연"
    elsif days == 0
      "오늘"
    else
      "D-#{days}"
    end
  rescue
    '날짜 오류'
  end

  def timeline_svg_viewbox
    width = 1000
    height = 200
    "0 0 #{width} #{height}"
  end

  def generate_timeline_svg
    return '' if milestone_positions.empty?

    width = 1000
    height = 200
    padding = 50
    timeline_y = height / 2

    # 타임라인 기본 라인
    timeline_line = %Q{
      <line x1="#{padding}" y1="#{timeline_y}" 
            x2="#{width - padding}" y2="#{timeline_y}" 
            stroke="#e5e7eb" stroke-width="4"/>
    }

    # 마일스톤 포인트들
    milestone_points = milestone_positions.map.with_index do |item, index|
      x_pos = padding + (item[:position] / 100.0 * (width - 2 * padding))
      y_offset = index.even? ? -30 : 30
      point_y = timeline_y
      label_y = timeline_y + y_offset
      
      color = case item[:milestone][:status]
              when 'completed' then '#10b981'
              when 'in_progress' then '#3b82f6'
              when 'at_risk' then '#f59e0b'
              when 'delayed' then '#ef4444'
              else '#6b7280'
              end

      %Q{
        <circle cx="#{x_pos}" cy="#{point_y}" r="8" 
                fill="#{color}" stroke="#ffffff" stroke-width="2"/>
        <line x1="#{x_pos}" y1="#{point_y}" 
              x2="#{x_pos}" y2="#{label_y}" 
              stroke="#{color}" stroke-width="2"/>
        <text x="#{x_pos}" y="#{label_y + (y_offset > 0 ? 20 : -10)}" 
              text-anchor="middle" font-size="12" fill="#374151">
          #{item[:milestone][:name]}
        </text>
        <text x="#{x_pos}" y="#{label_y + (y_offset > 0 ? 35 : 5)}" 
              text-anchor="middle" font-size="10" fill="#6b7280">
          #{formatted_date(item[:milestone][:target_date])}
        </text>
      }
    end.join

    %Q{
      <svg viewBox="#{timeline_svg_viewbox}" class="timeline-svg w-full h-48">
        #{timeline_line}
        #{milestone_points}
      </svg>
    }
  end

  def quarter_labels
    return [] unless timeline_span[:start_date] && timeline_span[:end_date]

    start_date = Date.parse(timeline_span[:start_date].to_s)
    end_date = Date.parse(timeline_span[:end_date].to_s)
    
    quarters = []
    current_date = start_date.beginning_of_quarter
    
    while current_date <= end_date
      quarter_num = (current_date.month - 1) / 3 + 1
      quarters << {
        label: "#{current_date.year} Q#{quarter_num}",
        start_date: current_date,
        end_date: [current_date.end_of_quarter, end_date].min
      }
      current_date = current_date.end_of_quarter + 1.day
    end
    
    quarters
  end

  def milestone_epic_labels(milestone)
    return [] unless milestone[:epic_labels]
    
    milestone[:epic_labels].map do |name, color|
      {
        name: name,
        color: color || '#6b7280'
      }
    end
  end

  def show_timeline_navigation?
    timeline_span[:total_weeks] && timeline_span[:total_weeks] > 12
  end

  def timeline_health_status
    at_risk_count = timeline_milestones.count { |m| m[:risk_level] == 'high' || m[:risk_level] == 'critical' }
    total_count = timeline_milestones.count
    
    return { status: 'unknown', class: 'text-gray-600', message: '마일스톤이 없습니다' } if total_count == 0
    
    risk_ratio = at_risk_count.to_f / total_count
    
    case risk_ratio
    when 0
      { status: 'healthy', class: 'text-green-600', message: '모든 마일스톤이 정상 진행 중입니다' }
    when 0...0.3
      { status: 'good', class: 'text-blue-600', message: '대부분의 마일스톤이 정상입니다' }
    when 0.3...0.6
      { status: 'warning', class: 'text-yellow-600', message: '일부 마일스톤에 주의가 필요합니다' }
    else
      { status: 'critical', class: 'text-red-600', message: '많은 마일스톤이 위험 상태입니다' }
    end
  end

  def completion_summary
    return { completed: 0, total: 0, percentage: 0 } if timeline_milestones.empty?

    completed = timeline_milestones.count { |m| m[:status] == 'completed' }
    total = timeline_milestones.count
    percentage = (completed.to_f / total * 100).round(1)
    
    {
      completed: completed,
      total: total,
      percentage: percentage
    }
  end

  def overdue_milestones
    timeline_milestones.select do |milestone|
      target_date = Date.parse(milestone[:target_date].to_s)
      target_date < Date.current && milestone[:status] != 'completed'
    end
  rescue
    []
  end

  def upcoming_milestones
    timeline_milestones.select do |milestone|
      target_date = Date.parse(milestone[:target_date].to_s)
      target_date >= Date.current && target_date <= 2.weeks.from_now.to_date
    end.sort_by { |m| Date.parse(m[:target_date].to_s) }
  rescue
    []
  end

  def milestone_tooltip_data(milestone)
    {
      title: milestone[:name],
      progress: "#{milestone[:progress]}% 완료",
      tasks: "#{milestone[:completed_tasks]}/#{milestone[:tasks_count]} 작업",
      risk: milestone_risk_indicator(milestone)[:label],
      days_remaining: days_until_milestone(milestone)
    }
  end

  def render_milestone_card(milestone, position)
    risk = milestone_risk_indicator(milestone)
    
    %Q{
      <div class="milestone-card absolute bg-white rounded-lg shadow-lg p-4 border-l-4 #{milestone_border_color(milestone[:status])}"
           style="left: #{position[:position]}%; transform: translateX(-50%); top: 120px; width: 200px;"
           data-milestone-id="#{milestone[:id]}">
        <div class="flex items-center justify-between mb-2">
          <h4 class="font-medium text-gray-900 text-sm truncate flex-1">#{milestone[:name]}</h4>
          <span class="#{risk[:class]} ml-2">#{risk[:icon]}</span>
        </div>
        
        <div class="space-y-2">
          <div class="flex justify-between text-xs text-gray-600">
            <span>진행률</span>
            <span>#{milestone[:progress]}%</span>
          </div>
          
          <div class="w-full bg-gray-200 rounded-full h-1.5">
            <div class="#{progress_color(milestone[:progress])} h-1.5 rounded-full" 
                 style="width: #{milestone[:progress]}%"></div>
          </div>
          
          <div class="flex justify-between text-xs text-gray-500">
            <span>#{formatted_date(milestone[:target_date])}</span>
            <span class="#{milestone[:status] == 'completed' ? 'text-green-600' : days_until_milestone(milestone).include?('지연') ? 'text-red-600' : 'text-blue-600'}">
              #{days_until_milestone(milestone)}
            </span>
          </div>
          
          <div class="text-xs text-gray-500">
            #{milestone[:completed_tasks]}/#{milestone[:tasks_count]} 작업 완료
          </div>
        </div>
      </div>
    }.html_safe
  end

  def milestone_border_color(status)
    case status
    when 'completed' then 'border-green-500'
    when 'in_progress' then 'border-blue-500'
    when 'at_risk' then 'border-yellow-500'
    when 'delayed' then 'border-red-500'
    else 'border-gray-500'
    end
  end
end