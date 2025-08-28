# frozen_string_literal: true

class RoadmapGanttComponent < ViewComponent::Base
  def initialize(gantt_data:, dependencies:, critical_path:, service:)
    @gantt_data = gantt_data
    @dependencies = dependencies
    @critical_path = critical_path
    @service = service
  end

  private

  attr_reader :gantt_data, :dependencies, :critical_path, :service

  def gantt_tasks
    gantt_data[:tasks] || []
  end

  def date_range
    return { start_date: Date.current, end_date: 1.month.from_now.to_date } if gantt_tasks.empty?

    start_dates = gantt_tasks.map { |task| Date.parse(task[:start_date].to_s) }
    end_dates = gantt_tasks.map { |task| Date.parse(task[:end_date].to_s) }

    {
      start_date: start_dates.min,
      end_date: end_dates.max
    }
  end

  def total_days
    (date_range[:end_date] - date_range[:start_date]).to_i + 1
  end

  def weeks_in_range
    weeks = []
    current_date = date_range[:start_date].beginning_of_week
    end_date = date_range[:end_date].end_of_week

    while current_date <= end_date
      weeks << {
        start_date: current_date,
        end_date: [current_date.end_of_week, end_date].min,
        week_number: current_date.strftime('W%U'),
        month_year: current_date.strftime('%Y-%m')
      }
      current_date += 1.week
    end

    weeks
  end

  def task_bar_data(task)
    task_start = Date.parse(task[:start_date].to_s)
    task_end = Date.parse(task[:end_date].to_s)
    
    days_from_start = (task_start - date_range[:start_date]).to_i
    task_duration = (task_end - task_start).to_i + 1
    
    left_percentage = total_days > 0 ? (days_from_start.to_f / total_days * 100).round(2) : 0
    width_percentage = total_days > 0 ? (task_duration.to_f / total_days * 100).round(2) : 0

    {
      left: left_percentage,
      width: width_percentage,
      start_date: task_start,
      end_date: task_end,
      duration: task_duration
    }
  end

  def task_status_class(task)
    case task[:status]
    when 'done'
      'bg-green-500'
    when 'in_progress'
      'bg-blue-500'
    when 'todo'
      'bg-gray-400'
    when 'blocked'
      'bg-red-500'
    else
      'bg-gray-300'
    end
  end

  def task_priority_indicator(task)
    case task[:priority]
    when 'urgent'
      { icon: '🚨', class: 'text-red-600', label: '긴급' }
    when 'high'
      { icon: '🔥', class: 'text-orange-600', label: '높음' }
    when 'medium'
      { icon: '📋', class: 'text-blue-600', label: '보통' }
    when 'low'
      { icon: '📄', class: 'text-gray-600', label: '낮음' }
    else
      { icon: '📄', class: 'text-gray-400', label: '미정' }
    end
  end

  def is_critical_path_task(task_id)
    critical_path.any? { |cp| cp[:task_id] == task_id }
  end

  def task_dependencies_for(task_id)
    dependencies.select { |dep| dep[:to] == task_id }
  end

  def task_dependents_for(task_id)
    dependencies.select { |dep| dep[:from] == task_id }
  end

  def grouped_tasks_by_epic
    return { '기타' => gantt_tasks } if gantt_tasks.empty?

    grouped = gantt_tasks.group_by { |task| task[:epic_label] || '기타' }
    
    # Epic별로 정렬 (진행 중인 Epic 우선)
    grouped.sort_by do |epic_name, tasks|
      in_progress_count = tasks.count { |t| t[:status] == 'in_progress' }
      [-in_progress_count, epic_name]
    end.to_h
  end

  def epic_progress(tasks)
    return 0 if tasks.empty?

    total_progress = tasks.sum { |task| task[:progress] || 0 }
    (total_progress.to_f / tasks.count).round(1)
  end

  def epic_status_summary(tasks)
    status_counts = tasks.group_by { |task| task[:status] }.transform_values(&:count)
    
    {
      total: tasks.count,
      done: status_counts['done'] || 0,
      in_progress: status_counts['in_progress'] || 0,
      todo: status_counts['todo'] || 0,
      blocked: status_counts['blocked'] || 0
    }
  end

  def render_dependency_lines
    return '' if dependencies.empty?

    lines = dependencies.map do |dep|
      from_task = gantt_tasks.find { |t| t[:id] == dep[:from] }
      to_task = gantt_tasks.find { |t| t[:id] == dep[:to] }
      
      next unless from_task && to_task

      from_bar = task_bar_data(from_task)
      to_bar = task_bar_data(to_task)
      
      from_x = from_bar[:left] + from_bar[:width]
      to_x = to_bar[:left]
      
      # 의존성 화살표 SVG 생성
      render_dependency_arrow(from_x, to_x, dep)
    end.compact.join

    %Q{
      <svg class="dependency-lines absolute inset-0 pointer-events-none" style="z-index: 1;">
        #{lines}
      </svg>
    }.html_safe
  end

  def render_dependency_arrow(from_x, to_x, dependency)
    # 간단한 화살표 라인
    arrow_color = dependency[:type] == 'critical' ? '#ef4444' : '#6b7280'
    
    %Q{
      <line x1="#{from_x}%" y1="50%" x2="#{to_x}%" y2="50%" 
            stroke="#{arrow_color}" stroke-width="2" stroke-dasharray="5,5"/>
      <polygon points="#{to_x-1},48 #{to_x},50 #{to_x-1},52" 
               fill="#{arrow_color}"/>
    }
  end

  def gantt_chart_svg_viewbox
    "0 0 100 #{gantt_tasks.count * 3 + 5}"
  end

  def time_scale_markers
    markers = []
    current_date = date_range[:start_date]
    
    while current_date <= date_range[:end_date]
      if current_date.day == 1 # 매월 1일
        days_from_start = (current_date - date_range[:start_date]).to_i
        position = total_days > 0 ? (days_from_start.to_f / total_days * 100).round(2) : 0
        
        markers << {
          position: position,
          label: current_date.strftime('%m월'),
          date: current_date,
          is_month_start: true
        }
      end
      current_date += 1.day
    end
    
    markers
  end

  def today_marker_position
    return 0 unless date_range[:start_date] <= Date.current && Date.current <= date_range[:end_date]
    
    days_from_start = (Date.current - date_range[:start_date]).to_i
    total_days > 0 ? (days_from_start.to_f / total_days * 100).round(2) : 0
  end

  def task_tooltip_data(task)
    bar_data = task_bar_data(task)
    priority = task_priority_indicator(task)
    
    {
      title: task[:title],
      duration: "#{bar_data[:duration]}일",
      progress: "#{task[:progress]}%",
      status: task[:status].humanize,
      priority: priority[:label],
      assignees: task[:assignees]&.join(', ') || '담당자 없음',
      start_date: formatted_date(task[:start_date]),
      end_date: formatted_date(task[:end_date]),
      dependencies: task_dependencies_for(task[:id]).count,
      dependents: task_dependents_for(task[:id]).count
    }
  end

  def formatted_date(date_string)
    Date.parse(date_string.to_s).strftime('%Y.%m.%d')
  rescue
    '날짜 없음'
  end

  def gantt_summary_stats
    return { total: 0, on_track: 0, at_risk: 0, delayed: 0 } if gantt_tasks.empty?

    stats = {
      total: gantt_tasks.count,
      done: gantt_tasks.count { |t| t[:status] == 'done' },
      in_progress: gantt_tasks.count { |t| t[:status] == 'in_progress' },
      todo: gantt_tasks.count { |t| t[:status] == 'todo' },
      blocked: gantt_tasks.count { |t| t[:status] == 'blocked' },
      critical_path: critical_path.count,
      high_priority: gantt_tasks.count { |t| %w[urgent high].include?(t[:priority]) },
      completion_rate: 0
    }
    
    stats[:completion_rate] = gantt_tasks.empty? ? 0 : (stats[:done].to_f / stats[:total] * 100).round(1)
    stats
  end

  def overdue_tasks
    gantt_tasks.select do |task|
      end_date = Date.parse(task[:end_date].to_s)
      end_date < Date.current && task[:status] != 'done'
    end
  rescue
    []
  end

  def task_row_height
    40 # px
  end

  def chart_height
    gantt_tasks.count * task_row_height + 100 # 헤더와 여백 포함
  end

  def render_task_row(task, index)
    bar_data = task_bar_data(task)
    status_class = task_status_class(task)
    priority = task_priority_indicator(task)
    is_critical = is_critical_path_task(task[:id])
    is_overdue = overdue_tasks.include?(task)
    
    row_y = index * task_row_height + 50 # 헤더 아래서부터 시작
    
    %Q{
      <g class="task-row" data-task-id="#{task[:id]}">
        <!-- 배경 (hover 효과용) -->
        <rect x="0" y="#{row_y}" width="100%" height="#{task_row_height}" 
              fill="transparent" class="hover:fill-gray-50 cursor-pointer"/>
        
        <!-- Task Bar -->
        <rect x="#{bar_data[:left]}%" y="#{row_y + 8}" 
              width="#{bar_data[:width]}%" height="24"
              fill="#{task[:color] || '#3b82f6'}"
              class="task-bar #{is_critical ? 'critical-path' : ''} #{is_overdue ? 'overdue' : ''}"
              rx="4"/>
        
        <!-- Progress Bar -->
        <rect x="#{bar_data[:left]}%" y="#{row_y + 8}" 
              width="#{bar_data[:width] * (task[:progress] || 0) / 100.0}%" height="24"
              fill="#{task[:color] || '#3b82f6'}"
              opacity="0.7" rx="4"/>
        
        <!-- Task Label -->
        <text x="#{bar_data[:left] > 50 ? bar_data[:left] - 1 : bar_data[:left] + bar_data[:width] + 1}%" 
              y="#{row_y + 20}" 
              font-size="12" 
              fill="#374151"
              text-anchor="#{bar_data[:left] > 50 ? 'end' : 'start'}"
              class="task-label">
          #{priority[:icon]} #{task[:title]}
        </text>
        
        <!-- Critical Path Indicator -->
        #{if is_critical
            %Q{<rect x="#{bar_data[:left]}%" y="#{row_y + 4}" width="#{bar_data[:width]}%" height="2" fill="#ef4444"/>}
          else
            ''
          end}
        
        <!-- Overdue Indicator -->
        #{if is_overdue
            %Q{<text x="#{bar_data[:left] + bar_data[:width] + 2}%" y="#{row_y + 15}" font-size="10" fill="#ef4444">⚠️</text>}
          else
            ''
          end}
      </g>
    }
  end

  def render_time_scale
    markers = time_scale_markers
    
    scale_lines = markers.map do |marker|
      %Q{
        <line x1="#{marker[:position]}%" y1="0" x2="#{marker[:position]}%" y2="100%" 
              stroke="#e5e7eb" stroke-width="1"/>
        <text x="#{marker[:position]}%" y="20" font-size="12" fill="#6b7280" text-anchor="middle">
          #{marker[:label]}
        </text>
      }
    end.join

    # Today marker
    today_position = today_marker_position
    today_line = if today_position > 0
                   %Q{
                     <line x1="#{today_position}%" y1="0" x2="#{today_position}%" y2="100%" 
                           stroke="#ef4444" stroke-width="2" stroke-dasharray="5,5"/>
                     <text x="#{today_position}%" y="35" font-size="10" fill="#ef4444" text-anchor="middle">
                       오늘
                     </text>
                   }
                 else
                   ''
                 end

    scale_lines + today_line
  end

  def generate_gantt_svg
    return '' if gantt_tasks.empty?

    task_rows = gantt_tasks.map.with_index { |task, index| render_task_row(task, index) }.join
    time_scale = render_time_scale
    
    %Q{
      <svg viewBox="0 0 100 #{gantt_tasks.count * 4 + 10}" class="gantt-chart w-full" style="height: #{chart_height}px;">
        <!-- 배경 그리드 -->
        <defs>
          <pattern id="grid" width="10" height="4" patternUnits="userSpaceOnUse">
            <path d="M 10 0 L 0 0 0 4" fill="none" stroke="#f3f4f6" stroke-width="1"/>
          </pattern>
        </defs>
        <rect width="100%" height="100%" fill="url(#grid)"/>
        
        <!-- Time Scale -->
        #{time_scale}
        
        <!-- Task Rows -->
        #{task_rows}
        
        <!-- Dependencies -->
        #{render_dependency_lines}
      </svg>
    }.html_safe
  end

  def legend_items
    [
      { color: '#10b981', label: '완료', status: 'done' },
      { color: '#3b82f6', label: '진행중', status: 'in_progress' },
      { color: '#6b7280', label: '대기', status: 'todo' },
      { color: '#ef4444', label: '블록됨', status: 'blocked' },
      { color: '#ef4444', label: '임계경로', extra: 'critical-path' },
      { color: '#f59e0b', label: '지연위험', extra: 'overdue' }
    ]
  end

  def milestone_markers
    # 서비스의 마일스톤들을 간트 차트에 표시
    service.milestones.where('target_date BETWEEN ? AND ?', date_range[:start_date], date_range[:end_date])
           .map do |milestone|
      days_from_start = (milestone.target_date - date_range[:start_date]).to_i
      position = total_days > 0 ? (days_from_start.to_f / total_days * 100).round(2) : 0
      
      {
        name: milestone.name,
        position: position,
        date: milestone.target_date,
        status: milestone.status
      }
    end
  end

  def render_milestone_markers
    return '' if milestone_markers.empty?

    markers = milestone_markers.map do |milestone|
      color = case milestone[:status]
              when 'completed' then '#10b981'
              when 'at_risk' then '#f59e0b'
              when 'delayed' then '#ef4444'
              else '#6b7280'
              end

      %Q{
        <line x1="#{milestone[:position]}%" y1="0" x2="#{milestone[:position]}%" y2="100%" 
              stroke="#{color}" stroke-width="3"/>
        <polygon points="#{milestone[:position]},45 #{milestone[:position] - 1},40 #{milestone[:position] + 1},40" 
                 fill="#{color}"/>
        <text x="#{milestone[:position]}%" y="40" font-size="10" fill="#{color}" text-anchor="middle" 
              transform="rotate(-45 #{milestone[:position]} 40)">
          📍 #{milestone[:name]}
        </text>
      }
    end.join

    markers
  end
end