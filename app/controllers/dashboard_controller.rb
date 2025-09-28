# frozen_string_literal: true

class DashboardController < TenantBaseController
  before_action :set_date_range, only: [:index, :metrics, :charts]
  
  # GET /dashboard
  # 실시간 메트릭 대시보드 메인 페이지
  def index
    authorize! :index, :dashboard
    
    # 현재 활성 스프린트
    @active_sprint = Sprint.where(
      organization_id: current_organization.id.to_s,
      status: 'active'
    ).first
    
    # 대시보드 메트릭 계산
    @dashboard_metrics = calculate_dashboard_metrics
    
    # 최근 활동
    @recent_activities = recent_activities.limit(10)
    
    # 알림 및 경고
    @alerts = calculate_dashboard_alerts
    
    respond_to do |format|
      format.html # dashboard.html.erb
      format.json do
        render_serialized(DashboardDataSerializer, {
          data: {
            metrics: @dashboard_metrics,
            active_sprint: @active_sprint ? SprintSerializer.new(@active_sprint).serializable_hash : nil,
            recent_activities: serialize_activities(@recent_activities),
            alerts: @alerts
          }
        })
      end
    end
  end
  
  # GET /dashboard/metrics
  # 실시간 메트릭 데이터 API (Turbo Streams 지원)
  def metrics
    authorize! :show, :dashboard
    
    # 캐시된 메트릭 조회 또는 새로 계산
    @dashboard_metrics = Rails.cache.fetch(
      dashboard_cache_key, 
      expires_in: 2.minutes
    ) do
      calculate_dashboard_metrics
    end
    
    # 차트 데이터
    @chart_data = {
      velocity_trend: calculate_velocity_trend,
      burndown_data: calculate_team_burndown_data,
      workload_distribution: calculate_workload_distribution,
      completion_rates: calculate_completion_rates
    }
    
    respond_to do |format|
      format.json do
        render_serialized(DashboardDataSerializer, {
          metrics: @dashboard_metrics,
          charts: @chart_data,
          last_updated: Time.current.iso8601
        })
      end
      
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("dashboard_metrics",
            DashboardMetricsComponent.new(
              dashboard_metrics: @dashboard_metrics,
              chart_data: @chart_data
            )
          ),
          turbo_stream.replace("dashboard_charts", 
            DashboardChartsComponent.new(chart_data: @chart_data)
          ),
          turbo_stream.replace("last_updated",
            partial: "shared/last_updated", 
            locals: { timestamp: Time.current }
          )
        ]
      end
    end
  end
  
  # GET /dashboard/charts
  # 차트 데이터 전용 엔드포인트
  def charts
    authorize! :show, :dashboard
    
    chart_type = params[:chart_type]
    date_range = params[:range] || '7d'
    
    @chart_data = case chart_type
                  when 'velocity'
                    calculate_velocity_trend(parse_date_range(date_range))
                  when 'burndown'
                    calculate_team_burndown_data(parse_date_range(date_range))
                  when 'workload'
                    calculate_workload_distribution
                  when 'completion'
                    calculate_completion_rates(parse_date_range(date_range))
                  else
                    calculate_all_chart_data(parse_date_range(date_range))
                  end
    
    respond_to do |format|
      format.json do
        render_serialized(DashboardDataSerializer, {
          data: {
            chart_type: chart_type,
            data: @chart_data,
            range: date_range,
            generated_at: Time.current.iso8601
          }
        })
      end
      
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "chart_#{chart_type}",
          partial: "dashboard/charts/#{chart_type}",
          locals: { data: @chart_data, range: date_range }
        )
      end
    end
  end
  
  # GET /dashboard/alerts
  # 실시간 알림 및 경고 상태
  def alerts
    authorize! :show, :dashboard
    
    @alerts = calculate_dashboard_alerts
    @notifications = recent_notifications.limit(5)
    
    respond_to do |format|
      format.json do
        render_serialized(DashboardDataSerializer, {
          alerts: @alerts,
          data: {
            notifications: serialize_notifications(@notifications),
            alert_count: @alerts.count { |a| a[:severity] != 'info' }
          }
        })
      end
      
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("dashboard_alerts",
            DashboardAlertsComponent.new(alerts: @alerts)
          ),
          turbo_stream.replace("notification_badge",
            partial: "shared/notification_badge",
            locals: { count: @alerts.count { |a| a[:severity] == 'high' } }
          )
        ]
      end
    end
  end
  
  # POST /dashboard/alerts/:id/dismiss
  # 알림 해제
  def dismiss_alert
    authorize! :update, :dashboard
    
    alert_id = params[:id]
    alert_type = params[:alert_type]
    
    # 알림 해제 로직 (캐시에서 제거 또는 데이터베이스 업데이트)
    dismiss_dashboard_alert(alert_id, alert_type)
    
    respond_to do |format|
      format.json do
        render_serialized(SuccessSerializer, { 
          message: "알림이 해제되었습니다.",
          data: { dismissed_at: Time.current.iso8601 }
        })
      end
      
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove("alert_#{alert_id}"),
          turbo_stream.replace("flash_messages",
            partial: "shared/flash_messages"
          )
        ]
      end
    end
  end
  
  private
  
  def set_date_range
    @start_date = params[:start_date]&.to_date || 30.days.ago.to_date
    @end_date = params[:end_date]&.to_date || Date.current
  end
  
  def dashboard_cache_key
    "dashboard_metrics_#{current_organization.id}_#{Date.current.strftime('%Y%m%d_%H')}"
  end
  
  # 대시보드 메트릭 계산
  def calculate_dashboard_metrics
    tasks = Task.where(
      organization_id: current_organization.id.to_s,
      created_at: @start_date..@end_date
    )
    sprints = Sprint.where(
      organization_id: current_organization.id.to_s,
      start_date: @start_date..@end_date
    )
    team_members = current_organization.users.active
    
    # TeamMetrics 구조체 사용
    TeamMetrics.new(
      # 기본 통계
      velocity: calculate_organization_velocity(sprints),
      capacity: calculate_organization_capacity(team_members),
      
      # 완료 지표
      completion_rate: calculate_overall_completion_rate(tasks),
      tasks_completed_today: tasks.where(
        status: 'done',
        :updated_at.gte => Date.current.beginning_of_day,
        :updated_at.lte => Date.current.end_of_day
      ).count,
      tasks_completed_week: tasks.where(
        status: 'done',
        :updated_at.gte => 1.week.ago,
        :updated_at.lte => Time.current
      ).count,
      
      # 업무 분배
      workload_distribution: calculate_current_workload_distribution(team_members),
      
      # 번다운 데이터
      burndown_data: calculate_organization_burndown_data,
      
      # 추가 지표
      average_cycle_time: calculate_average_cycle_time(tasks),
      overdue_tasks_count: tasks.where(
        :deadline.lt => Time.current,
        status: { '$ne' => 'done' }
      ).count,
      high_priority_tasks_count: tasks.where(
        priority: { '$in' => ['urgent', 'high'] }
      ).count
    )
  end
  
  def calculate_organization_velocity(sprints)
    return 0.0 if sprints.empty?
    
    # 완료된 스프린트들의 평균 완료 작업 수
    completed_sprints = sprints.where(status: 'completed')
    return 0.0 if completed_sprints.empty?
    
    total_completed_tasks = completed_sprints.map do |sprint|
      Task.where(sprint_id: sprint.id, status: 'done').count
    end.sum
    (total_completed_tasks.to_f / completed_sprints.count).round(1)
  end
  
  def calculate_organization_capacity(team_members)
    # 팀 전체 주간 작업 가능 시간 (시간 단위)
    working_days_per_week = 5
    hours_per_day = 8
    
    (team_members.count * working_days_per_week * hours_per_day).to_f
  end
  
  def calculate_overall_completion_rate(tasks)
    return 0.0 if tasks.empty?
    
    completed_tasks = tasks.where(status: 'done').count
    (completed_tasks.to_f / tasks.count * 100).round(1)
  end
  
  def calculate_current_workload_distribution(team_members)
    distribution = {}
    
    team_members.each do |member|
      # 현재 진행 중인 작업들의 예상 시간 합계
      active_tasks = Task.where(
        organization_id: current_organization.id.to_s,
        assigned_user: member,
        status: { '$in' => ['todo', 'in_progress', 'review'] }
      )
      estimated_hours = active_tasks.sum { |task| task.estimated_hours || 4.0 }
      
      distribution[member.id] = estimated_hours.round(1)
    end
    
    distribution
  end
  
  def calculate_organization_burndown_data
    # 최근 30일간의 조직 전체 번다운 데이터
    data = []
    
    (30.days.ago.to_date..Date.current).each do |date|
      remaining_tasks = Task.where(
        organization_id: current_organization.id.to_s,
        :created_at.lte => date.end_of_day
      ).where(
        '$or' => [
          { status: { '$ne' => 'done' } },
          { :updated_at.gt => date.end_of_day }
        ]
      ).count
      
      # 이상적인 번다운 계산 (선형 감소)
      total_days = 30
      elapsed_days = (date - 30.days.ago.to_date).to_i
      total_initial_tasks = Task.where(
        organization_id: current_organization.id.to_s,
        :created_at.gte => 30.days.ago.beginning_of_day,
        :created_at.lte => 30.days.ago.end_of_day
      ).count
      
      ideal_remaining = total_initial_tasks * [(total_days - elapsed_days).to_f / total_days, 0].max
      
      data << {
        date: date,
        remaining: remaining_tasks,
        ideal: ideal_remaining.round
      }
    end
    
    data
  end
  
  def calculate_average_cycle_time(tasks)
    completed_tasks = tasks.where(status: 'done').where(:created_at.exists => true)
    return 0.0 if completed_tasks.empty?
    
    total_cycle_time = completed_tasks.sum do |task|
      (task.updated_at - task.created_at) / 1.day
    end
    
    (total_cycle_time / completed_tasks.count).round(1)
  end
  
  # 차트 데이터 계산 메서드들
  def calculate_velocity_trend(date_range = nil)
    range = date_range || (@start_date..@end_date)
    
    # 주별 속도 트렌드
    data = []
    range.beginning_of_week.step(range.end_of_week, 1.week) do |week_start|
      week_end = [week_start.end_of_week, Date.current].min
      
      tasks_completed = Task.where(
        organization_id: current_organization.id.to_s,
        status: 'done',
        :updated_at.gte => week_start.beginning_of_day,
        :updated_at.lte => week_end.end_of_day
      ).count
      
      data << {
        week: week_start.strftime('%-m/%-d'),
        tasks_completed: tasks_completed,
        velocity: tasks_completed.to_f / 7 # 일일 평균
      }
    end
    
    data
  end
  
  def calculate_team_burndown_data(date_range = nil)
    range = date_range || (@start_date..@end_date)
    
    data = []
    range.each do |date|
      remaining = Task.where(
        organization_id: current_organization.id.to_s,
        :created_at.lte => date.end_of_day
      ).where(
        '$or' => [
          { status: { '$ne' => 'done' } },
          { :updated_at.gt => date.end_of_day }
        ]
      ).count
      
      data << {
        date: date.strftime('%-m/%-d'),
        remaining: remaining
      }
    end
    
    data
  end
  
  def calculate_completion_rates(date_range = nil)
    range = date_range || (@start_date..@end_date)
    
    # 우선순위별, 상태별 완료율
    data = {
      by_priority: {},
      by_assignee: {},
      by_day: []
    }
    
    # 우선순위별 완료율
    %w[low medium high urgent].each do |priority|
      priority_tasks = Task.where(
        organization_id: current_organization.id.to_s,
        priority: priority,
        :created_at.gte => range.begin,
        :created_at.lte => range.end
      )
      completed = priority_tasks.where(status: 'done').count
      total = priority_tasks.count
      
      data[:by_priority][priority] = {
        completed: completed,
        total: total,
        rate: total > 0 ? (completed.to_f / total * 100).round(1) : 0.0
      }
    end
    
    # 담당자별 완료율 (활성 멤버만)
    current_organization.users.active.each do |user|
      user_tasks = Task.where(
        organization_id: current_organization.id.to_s,
        assigned_user: user,
        :created_at.gte => range.begin,
        :created_at.lte => range.end
      )
      completed = user_tasks.where(status: 'done').count
      total = user_tasks.count
      
      data[:by_assignee][user.email] = {
        completed: completed,
        total: total,
        rate: total > 0 ? (completed.to_f / total * 100).round(1) : 0.0
      } if total > 0
    end
    
    # 일별 완료율
    range.each do |date|
      day_tasks = Task.where(
        organization_id: current_organization.id.to_s,
        :created_at.gte => date.beginning_of_day,
        :created_at.lte => date.end_of_day
      )
      completed = day_tasks.where(status: 'done').count
      total = day_tasks.count
      
      data[:by_day] << {
        date: date.strftime('%-m/%-d'),
        completed: completed,
        total: total,
        rate: total > 0 ? (completed.to_f / total * 100).round(1) : 0.0
      } if total > 0
    end
    
    data
  end
  
  def calculate_all_chart_data(date_range)
    {
      velocity: calculate_velocity_trend(date_range),
      burndown: calculate_team_burndown_data(date_range),
      workload: calculate_workload_distribution,
      completion: calculate_completion_rates(date_range)
    }
  end
  
  # 알림 및 경고 계산
  def calculate_dashboard_alerts
    alerts = []
    
    # 지연된 작업 경고
    overdue_count = Task.where(
      organization_id: current_organization.id.to_s,
      :deadline.lt => Time.current,
      status: { '$ne' => 'done' }
    ).count
    if overdue_count > 0
      alerts << {
        id: "overdue_tasks",
        type: "overdue",
        severity: overdue_count > 5 ? "high" : "medium",
        title: "지연된 작업",
        message: "#{overdue_count}개의 작업이 마감일을 초과했습니다",
        action: "지연 작업 보기",
        url: tasks_path(overdue: true),
        created_at: Time.current
      }
    end
    
    # 높은 우선순위 작업 알림
    urgent_count = Task.where(
      organization_id: current_organization.id.to_s,
      priority: 'urgent',
      status: { '$ne' => 'done' }
    ).count
    if urgent_count > 0
      alerts << {
        id: "urgent_tasks",
        type: "priority",
        severity: "high",
        title: "긴급 작업",
        message: "#{urgent_count}개의 긴급 작업이 대기 중입니다",
        action: "긴급 작업 보기",
        url: tasks_path(priority: 'urgent'),
        created_at: Time.current
      }
    end
    
    # 활성 스프린트 진행 상황 확인
    active_sprint = Sprint.where(
      organization_id: current_organization.id.to_s,
      status: 'active'
    ).first
    if active_sprint
      total_tasks = Task.where(sprint_id: active_sprint.id).count
      completed_tasks = Task.where(sprint_id: active_sprint.id, status: 'done').count
      progress = total_tasks > 0 ? (completed_tasks.to_f / total_tasks * 100).round(1) : 0
      days_remaining = (active_sprint.end_date - Date.current).to_i rescue 0
      
      if days_remaining <= 2 && progress < 80
        alerts << {
          id: "sprint_behind",
          type: "sprint",
          severity: "medium",
          title: "스프린트 진행 지연",
          message: "#{active_sprint.name} 스프린트가 예상보다 느리게 진행되고 있습니다 (#{progress}% 완료)",
          action: "스프린트 보기",
          url: sprint_path(active_sprint),
          created_at: Time.current
        }
      end
    end
    
    # 팀 워크로드 불균형 확인
    workload = calculate_current_workload_distribution(current_organization.users.active)
    if workload.present? && workload.values.any? { |hours| hours > 50 }
      overloaded_members = workload.select { |_, hours| hours > 50 }.keys
      
      alerts << {
        id: "workload_imbalance",
        type: "workload",
        severity: "medium", 
        title: "업무 과부하 감지",
        message: "#{overloaded_members.size}명의 팀원이 과도한 업무량을 담당하고 있습니다",
        action: "업무 분배 보기",
        url: dashboard_path(tab: 'workload'),
        created_at: Time.current
      }
    end
    
    alerts.sort_by { |alert| [alert[:severity] == "high" ? 0 : 1, alert[:created_at]] }.reverse
  end
  
  # 최근 활동 조회
  def recent_activities
    # 최근 활동들을 시간순으로 정렬
    # (실제로는 Activity 모델이나 Paper Trail 등을 사용)
    activities = []
    
    # 최근 완료된 작업들
    recent_completed_tasks = Task.where(
      organization_id: current_organization.id.to_s,
      status: 'done',
      :updated_at.gte => 24.hours.ago,
      :updated_at.lte => Time.current
    ).order(updated_at: :desc).limit(5)
    
    recent_completed_tasks.each do |task|
      activities << {
        type: 'task_completed',
        title: "작업 완료",
        description: "#{task.assigned_user&.email || '담당자 없음'}이 '#{task.title}' 작업을 완료했습니다",
        timestamp: task.updated_at,
        url: task_path(task)
      }
    end
    
    # 새로 생성된 작업들
    recent_new_tasks = Task.where(
      organization_id: current_organization.id.to_s,
      :created_at.gte => 24.hours.ago,
      :created_at.lte => Time.current
    ).order(created_at: :desc).limit(3)
    
    recent_new_tasks.each do |task|
      activities << {
        type: 'task_created',
        title: "새 작업 생성",
        description: "'#{task.title}' 작업이 생성되었습니다",
        timestamp: task.created_at,
        url: task_path(task)
      }
    end
    
    activities.sort_by { |activity| activity[:timestamp] }.reverse
  end
  
  # 최근 알림 조회
  def recent_notifications
    # 실제로는 Noticed gem이나 알림 시스템 사용
    # 여기서는 샘플 데이터 반환
    []
  end
  
  # 유틸리티 메서드들
  def parse_date_range(range_string)
    case range_string
    when '7d'
      7.days.ago.to_date..Date.current
    when '30d'
      30.days.ago.to_date..Date.current
    when '90d'
      90.days.ago.to_date..Date.current
    else
      30.days.ago.to_date..Date.current
    end
  end
  
  def dismiss_dashboard_alert(alert_id, alert_type)
    # 알림 해제 로직 (캐시 또는 데이터베이스)
    Rails.cache.delete("dismissed_alert_#{current_organization.id}_#{alert_id}")
  end
  
  def serialize_activities(activities)
    activities.map do |activity|
      activity.transform_keys(&:to_s).merge(
        'timestamp_formatted' => activity[:timestamp].strftime('%H:%M'),
        'time_ago' => time_ago_in_words(activity[:timestamp])
      )
    end
  end
  
  def serialize_notifications(notifications)
    notifications.map(&:to_h)
  end
end