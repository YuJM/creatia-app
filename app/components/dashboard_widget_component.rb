# frozen_string_literal: true

class DashboardWidgetComponent < ViewComponent::Base
  def initialize(widget_id:, widget_config:, user:, widget_data: nil)
    @widget_id = widget_id
    @widget_config = widget_config
    @user = user
    @widget_data = widget_data
    @widget_definition = get_widget_definition(widget_id)
  end

  private

  attr_reader :widget_id, :widget_config, :user, :widget_data, :widget_definition

  def widget_enabled?
    widget_config[:enabled] != false
  end

  def widget_position
    widget_config[:position] || {}
  end

  def widget_settings
    widget_config[:settings] || widget_definition[:default_config] || {}
  end

  def widget_name
    widget_definition[:name] || widget_id.humanize
  end

  def widget_description
    widget_definition[:description] || ''
  end

  def widget_category
    widget_definition[:category] || 'general'
  end

  def widget_size
    widget_definition[:size] || 'medium'
  end

  def widget_configurable?
    widget_definition[:configurable] != false
  end

  def widget_classes
    base_classes = %w[dashboard-widget bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden]
    base_classes << "widget-#{widget_size}"
    base_classes << "widget-category-#{widget_category}"
    base_classes << 'widget-disabled' unless widget_enabled?
    base_classes.join(' ')
  end

  def widget_style
    position = widget_position
    return '' unless position.present?

    styles = []
    styles << "grid-column: #{position[:col] + 1} / #{position[:col] + (position[:width] || 1) + 1}"
    styles << "grid-row: #{position[:row] + 1} / #{position[:row] + (position[:height] || 1) + 1}"
    
    styles.join('; ')
  end

  def widget_content
    return cached_widget_content if should_use_cache?
    
    case widget_id.to_s
    when 'metrics'
      render_metrics_widget
    when 'tasks_summary'
      render_tasks_summary_widget
    when 'recent_activity'
      render_recent_activity_widget
    when 'sprint_progress'
      render_sprint_progress_widget
    when 'calendar'
      render_calendar_widget
    when 'team_workload'
      render_team_workload_widget
    when 'notifications'
      render_notifications_widget
    when 'quick_actions'
      render_quick_actions_widget
    else
      render_default_widget
    end
  end

  def should_use_cache?
    widget_settings[:cache_enabled] && !Rails.env.development?
  end

  def cached_widget_content
    cache_key = "widget_#{widget_id}_user_#{user.id}"
    cache_expires = widget_settings[:cache_duration] || 5.minutes
    
    Rails.cache.fetch(cache_key, expires_in: cache_expires) do
      widget_content
    end
  end

  def render_metrics_widget
    metrics_data = widget_data || calculate_metrics_data
    
    content_tag :div, class: "widget-content p-6" do
      content_tag :div, class: "grid grid-cols-3 gap-4" do
        metrics_data.map do |metric_name, metric_data|
          next unless widget_settings["show_#{metric_name}".to_sym] != false
          
          render_metric_card(metric_name, metric_data)
        end.compact.join.html_safe
      end
    end
  end

  def render_metric_card(metric_name, metric_data)
    content_tag :div, class: "text-center" do
      concat content_tag(:div, metric_data[:icon], class: "text-2xl mb-2")
      concat content_tag(:div, metric_data[:value], class: "text-xl font-bold text-gray-900")
      concat content_tag(:div, metric_data[:label], class: "text-sm text-gray-600")
      
      if metric_data[:change]
        change_class = metric_data[:change] >= 0 ? "text-green-600" : "text-red-600"
        concat content_tag(:div, "#{metric_data[:change] > 0 ? '+' : ''}#{metric_data[:change]}%", 
                         class: "text-xs #{change_class} mt-1")
      end
    end
  end

  def render_tasks_summary_widget
    tasks_data = widget_data || calculate_tasks_data
    
    content_tag :div, class: "widget-content p-6" do
      concat render_tasks_overview(tasks_data)
      concat render_priority_tasks(tasks_data[:priority_tasks]) if widget_settings[:show_priority]
    end
  end

  def render_tasks_overview(tasks_data)
    content_tag :div, class: "mb-4" do
      content_tag :div, class: "grid grid-cols-2 gap-4" do
        [
          { key: :total, label: "전체", value: tasks_data[:total], class: "text-blue-600" },
          { key: :in_progress, label: "진행중", value: tasks_data[:in_progress], class: "text-yellow-600" },
          { key: :overdue, label: "지연", value: tasks_data[:overdue], class: "text-red-600" },
          { key: :completed_today, label: "오늘완료", value: tasks_data[:completed_today], class: "text-green-600" }
        ].map do |item|
          content_tag :div, class: "text-center" do
            concat content_tag(:div, item[:value], class: "text-lg font-bold #{item[:class]}")
            concat content_tag(:div, item[:label], class: "text-xs text-gray-600")
          end
        end.join.html_safe
      end
    end
  end

  def render_priority_tasks(priority_tasks)
    return '' if priority_tasks.empty?
    
    content_tag :div, class: "border-t pt-4" do
      concat content_tag(:h4, "우선순위 작업", class: "text-sm font-medium text-gray-700 mb-2")
      concat(content_tag :div, class: "space-y-2" do
        priority_tasks.first(widget_settings[:max_items] || 5).map do |task|
          render_task_item(task)
        end.join.html_safe
      end)
    end
  end

  def render_task_item(task)
    content_tag :div, class: "flex items-center justify-between py-1" do
      concat(content_tag :div, class: "flex items-center space-x-2 flex-1" do
        concat content_tag(:span, priority_icon(task[:priority]), class: "text-sm")
        concat content_tag(:span, task[:title], class: "text-sm text-gray-900 truncate")
      end)
      concat content_tag(:span, task[:due_date]&.strftime("%m/%d") || "", class: "text-xs text-gray-500")
    end
  end

  def render_recent_activity_widget
    activity_data = widget_data || calculate_activity_data
    
    content_tag :div, class: "widget-content p-6" do
      content_tag :div, class: "space-y-3" do
        activity_data.first(widget_settings[:max_items] || 10).map do |activity|
          render_activity_item(activity)
        end.join.html_safe
      end
    end
  end

  def render_activity_item(activity)
    content_tag :div, class: "flex items-start space-x-3" do
      concat content_tag(:div, activity_icon(activity[:type]), class: "flex-shrink-0 text-sm mt-1")
      concat(content_tag :div, class: "flex-1 min-w-0" do
        concat content_tag(:p, activity[:message], class: "text-sm text-gray-900")
        concat content_tag(:p, activity[:time], class: "text-xs text-gray-500 mt-1")
      end)
    end
  end

  def render_sprint_progress_widget
    sprint_data = widget_data || calculate_sprint_data
    
    content_tag :div, class: "widget-content p-6" do
      if sprint_data.present?
        concat render_sprint_header(sprint_data)
        concat render_sprint_burndown(sprint_data) if widget_settings[:show_burndown]
        concat render_sprint_stats(sprint_data)
      else
        render_no_active_sprint
      end
    end
  end

  def render_sprint_header(sprint_data)
    content_tag :div, class: "mb-4" do
      concat content_tag(:h3, sprint_data[:name], class: "text-lg font-medium text-gray-900")
      concat(content_tag :div, class: "flex items-center justify-between text-sm text-gray-600" do
        concat content_tag(:span, "D-#{sprint_data[:days_remaining]}")
        concat content_tag(:span, "#{sprint_data[:progress]}% 완료")
      end)
    end
  end

  def render_sprint_burndown(sprint_data)
    return '' unless sprint_data[:burndown_data]
    
    content_tag :div, class: "mb-4" do
      concat content_tag(:h4, "번다운 차트", class: "text-sm font-medium text-gray-700 mb-2")
      concat render_simple_chart(sprint_data[:burndown_data])
    end
  end

  def render_sprint_stats(sprint_data)
    content_tag :div, class: "grid grid-cols-2 gap-4 text-center" do
      [
        { label: "남은 작업", value: sprint_data[:remaining_tasks], class: "text-blue-600" },
        { label: "완료 작업", value: sprint_data[:completed_tasks], class: "text-green-600" }
      ].map do |stat|
        content_tag :div do
          concat content_tag(:div, stat[:value], class: "text-lg font-bold #{stat[:class]}")
          concat content_tag(:div, stat[:label], class: "text-xs text-gray-600")
        end
      end.join.html_safe
    end
  end

  def render_no_active_sprint
    content_tag :div, class: "text-center py-8 text-gray-500" do
      concat content_tag(:div, "📋", class: "text-3xl mb-2")
      concat content_tag(:p, "진행 중인 스프린트가 없습니다")
    end
  end

  def render_calendar_widget
    calendar_data = widget_data || calculate_calendar_data
    
    content_tag :div, class: "widget-content p-6" do
      concat render_calendar_header(calendar_data)
      concat render_calendar_grid(calendar_data)
    end
  end

  def render_calendar_header(calendar_data)
    content_tag :div, class: "flex items-center justify-between mb-4" do
      concat content_tag(:h3, calendar_data[:current_month], class: "text-lg font-medium text-gray-900")
      concat(content_tag :div, class: "flex space-x-2" do
        concat button_tag("‹", class: "px-2 py-1 text-sm bg-gray-100 rounded", 
                         data: { action: "click->dashboard-widget#previousMonth" })
        concat button_tag("›", class: "px-2 py-1 text-sm bg-gray-100 rounded", 
                         data: { action: "click->dashboard-widget#nextMonth" })
      end)
    end
  end

  def render_calendar_grid(calendar_data)
    content_tag :div, class: "calendar-grid text-xs" do
      concat render_calendar_days_header
      concat render_calendar_dates(calendar_data[:dates])
    end
  end

  def render_calendar_days_header
    content_tag :div, class: "grid grid-cols-7 gap-1 mb-2" do
      %w[일 월 화 수 목 금 토].map do |day|
        content_tag :div, day, class: "text-center font-medium text-gray-600 py-1"
      end.join.html_safe
    end
  end

  def render_calendar_dates(dates)
    content_tag :div, class: "grid grid-cols-7 gap-1" do
      dates.map do |date_info|
        class_names = %w[text-center py-1 rounded]
        class_names << 'bg-blue-100 text-blue-800' if date_info[:has_events]
        class_names << 'text-gray-400' unless date_info[:current_month]
        
        content_tag :div, date_info[:day], class: class_names.join(' ')
      end.join.html_safe
    end
  end

  def render_team_workload_widget
    workload_data = widget_data || calculate_workload_data
    
    content_tag :div, class: "widget-content p-6" do
      content_tag :div, class: "space-y-3" do
        workload_data.first(5).map do |member_data|
          render_workload_item(member_data)
        end.join.html_safe
      end
    end
  end

  def render_workload_item(member_data)
    content_tag :div, class: "flex items-center justify-between" do
      concat content_tag(:span, member_data[:name], class: "text-sm font-medium text-gray-900")
      concat(content_tag :div, class: "flex items-center space-x-2" do
        concat(content_tag :div, class: "w-20 bg-gray-200 rounded-full h-2" do
          width_percentage = [member_data[:utilization], 100].min
          color_class = member_data[:utilization] > 90 ? 'bg-red-500' : 'bg-blue-500'
          content_tag :div, '', class: "#{color_class} h-2 rounded-full", style: "width: #{width_percentage}%"
        end)
        concat content_tag(:span, "#{member_data[:utilization]}%", class: "text-xs text-gray-600")
      end)
    end
  end

  def render_notifications_widget
    notifications_data = widget_data || calculate_notifications_data
    
    content_tag :div, class: "widget-content p-6" do
      if notifications_data.any?
        content_tag :div, class: "space-y-2" do
          notifications_data.first(widget_settings[:max_items] || 5).map do |notification|
            render_notification_item(notification)
          end.join.html_safe
        end
      else
        render_no_notifications
      end
    end
  end

  def render_notification_item(notification)
    content_tag :div, class: "flex items-start space-x-2 p-2 hover:bg-gray-50 rounded" do
      concat content_tag(:div, notification_icon(notification[:type]), class: "flex-shrink-0 text-sm mt-1")
      concat(content_tag :div, class: "flex-1 min-w-0" do
        concat content_tag(:p, notification[:message], class: "text-sm text-gray-900")
        concat content_tag(:p, notification[:time], class: "text-xs text-gray-500 mt-1")
      end)
    end
  end

  def render_no_notifications
    content_tag :div, class: "text-center py-4 text-gray-500" do
      concat content_tag(:div, "🔔", class: "text-2xl mb-2")
      concat content_tag(:p, "새 알림이 없습니다", class: "text-sm")
    end
  end

  def render_quick_actions_widget
    content_tag :div, class: "widget-content p-6" do
      content_tag :div, class: "grid grid-cols-2 gap-3" do
        quick_actions.map do |action|
          next unless widget_settings[action[:key]] != false
          
          render_quick_action_button(action)
        end.compact.join.html_safe
      end
    end
  end

  def render_quick_action_button(action)
    content_tag :button, 
                class: "flex flex-col items-center p-3 bg-gray-50 hover:bg-gray-100 rounded-lg transition-colors",
                data: { action: "click->dashboard-widget#quickAction", quick_action: action[:id] } do
      concat content_tag(:div, action[:icon], class: "text-xl mb-1")
      concat content_tag(:span, action[:label], class: "text-xs text-gray-700")
    end
  end

  def render_default_widget
    content_tag :div, class: "widget-content p-6 text-center" do
      concat content_tag(:div, "📊", class: "text-3xl mb-2")
      concat content_tag(:h3, widget_name, class: "text-lg font-medium text-gray-900 mb-1")
      concat content_tag(:p, widget_description, class: "text-sm text-gray-600")
    end
  end

  def render_simple_chart(data)
    # 간단한 SVG 차트 생성
    return '' if data.empty?
    
    max_value = data.map { |point| point[:value] }.max
    width = 200
    height = 60
    
    points = data.map.with_index do |point, index|
      x = (index.to_f / (data.length - 1)) * width
      y = height - (point[:value].to_f / max_value * height)
      "#{x.round(2)},#{y.round(2)}"
    end.join(' ')
    
    content_tag :svg, width: width, height: height, viewBox: "0 0 #{width} #{height}", class: "w-full h-16" do
      concat tag(:polyline, points: points, fill: "none", stroke: "#3b82f6", stroke_width: "2")
    end
  end

  def get_widget_definition(widget_id)
    # 위젯 정의를 반환하는 메서드 (실제로는 설정에서 로드)
    definitions = {
      metrics: { name: "팀 메트릭", category: "analytics", size: "large", configurable: true },
      tasks_summary: { name: "내 작업 요약", category: "tasks", size: "medium", configurable: true },
      recent_activity: { name: "최근 활동", category: "activity", size: "medium", configurable: true },
      sprint_progress: { name: "스프린트 진행률", category: "sprints", size: "large", configurable: true },
      calendar: { name: "캘린더", category: "planning", size: "large", configurable: true },
      team_workload: { name: "팀 업무량", category: "team", size: "medium", configurable: true },
      notifications: { name: "알림", category: "communication", size: "small", configurable: false },
      quick_actions: { name: "빠른 작업", category: "productivity", size: "small", configurable: true }
    }
    
    definitions[widget_id.to_sym] || {}
  end

  def calculate_metrics_data
    {
      velocity: { icon: "🚀", value: "12.5", label: "작업/주", change: 8.3 },
      completion_rate: { icon: "✅", value: "87%", label: "완료율", change: -2.1 },
      cycle_time: { icon: "⏱️", value: "3.2일", label: "처리시간", change: -5.4 }
    }
  end

  def calculate_tasks_data
    {
      total: 24,
      in_progress: 8,
      overdue: 3,
      completed_today: 5,
      priority_tasks: [
        { id: 1, title: "UI 컴포넌트 개발", priority: "urgent", due_date: Date.current + 1.day },
        { id: 2, title: "API 연동 테스트", priority: "high", due_date: Date.current + 2.days },
        { id: 3, title: "사용자 피드백 반영", priority: "medium", due_date: Date.current + 3.days }
      ]
    }
  end

  def calculate_activity_data
    [
      { type: "task_completed", message: "UI 컴포넌트 개발이 완료되었습니다", time: "10분 전" },
      { type: "comment", message: "김개발님이 댓글을 남겼습니다", time: "1시간 전" },
      { type: "assignment", message: "새 작업이 배정되었습니다", time: "2시간 전" },
      { type: "status_change", message: "스프린트 상태가 변경되었습니다", time: "3시간 전" }
    ]
  end

  def calculate_sprint_data
    return nil # 활성 스프린트가 없는 경우
    
    {
      name: "Sprint 2024-03",
      days_remaining: 5,
      progress: 65,
      remaining_tasks: 12,
      completed_tasks: 18,
      burndown_data: [
        { value: 30 }, { value: 25 }, { value: 20 }, { value: 15 }, { value: 12 }
      ]
    }
  end

  def calculate_calendar_data
    {
      current_month: Date.current.strftime("%Y년 %m월"),
      dates: (1..30).map do |day|
        {
          day: day,
          current_month: true,
          has_events: [5, 12, 18, 25].include?(day)
        }
      end
    }
  end

  def calculate_workload_data
    [
      { name: "김개발", utilization: 85 },
      { name: "이디자인", utilization: 92 },
      { name: "박매니저", utilization: 78 },
      { name: "최기획", utilization: 95 },
      { name: "한테스터", utilization: 67 }
    ]
  end

  def calculate_notifications_data
    [
      { type: "urgent", message: "긴급: 서버 점검이 예정되어 있습니다", time: "5분 전" },
      { type: "info", message: "새로운 기능이 출시되었습니다", time: "1시간 전" },
      { type: "reminder", message: "회의가 30분 후 시작됩니다", time: "2시간 전" }
    ]
  end

  def quick_actions
    [
      { id: "create_task", key: :show_create_task, icon: "➕", label: "작업 생성" },
      { id: "create_sprint", key: :show_create_sprint, icon: "📋", label: "스프린트 생성" },
      { id: "reports", key: :show_reports, icon: "📊", label: "리포트" },
      { id: "settings", key: :show_settings, icon: "⚙️", label: "설정" }
    ]
  end

  def priority_icon(priority)
    case priority.to_s
    when 'urgent' then '🚨'
    when 'high' then '🔥'
    when 'medium' then '📋'
    when 'low' then '📄'
    else '📋'
    end
  end

  def activity_icon(type)
    case type.to_s
    when 'task_completed' then '✅'
    when 'comment' then '💬'
    when 'assignment' then '👤'
    when 'status_change' then '🔄'
    else 'ℹ️'
    end
  end

  def notification_icon(type)
    case type.to_s
    when 'urgent' then '🚨'
    when 'info' then 'ℹ️'
    when 'reminder' then '⏰'
    when 'warning' then '⚠️'
    else '🔔'
    end
  end
end