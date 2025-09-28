# frozen_string_literal: true

# 대시보드 분석 데이터를 사전 집계하여 MongoDB에 저장
class DashboardMetrics
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields - 기본 정보
  field :organization_id, type: Integer
  field :team_id, type: Integer
  field :user_id, type: Integer
  field :service_id, type: Integer
  field :date, type: Date
  field :period_type, type: String # daily, weekly, monthly, quarterly, yearly
  field :period_start, type: Date
  field :period_end, type: Date

  # Task 메트릭
  field :tasks_created, type: Integer, default: 0
  field :tasks_completed, type: Integer, default: 0
  field :tasks_in_progress, type: Integer, default: 0
  field :tasks_cancelled, type: Integer, default: 0
  field :tasks_overdue, type: Integer, default: 0
  
  # Task 상태별 카운트
  field :task_status_distribution, type: Hash, default: {}
  field :task_priority_distribution, type: Hash, default: {}
  
  # 시간 메트릭
  field :total_hours_tracked, type: Float, default: 0.0
  field :average_task_duration, type: Float, default: 0.0
  field :estimated_vs_actual_ratio, type: Float, default: 1.0
  
  # 포모도로 메트릭
  field :pomodoro_sessions_completed, type: Integer, default: 0
  field :pomodoro_sessions_cancelled, type: Integer, default: 0
  field :average_pomodoro_productivity, type: Float, default: 0.0
  field :pomodoro_focus_level_avg, type: Float, default: 0.0
  field :pomodoro_interruptions_total, type: Integer, default: 0
  
  # 팀 메트릭
  field :team_velocity, type: Float, default: 0.0
  field :team_capacity, type: Float, default: 0.0
  field :team_utilization, type: Float, default: 0.0
  field :team_member_count, type: Integer, default: 0
  field :active_member_count, type: Integer, default: 0
  
  # 생산성 메트릭
  field :productivity_score, type: Float, default: 0.0
  field :completion_rate, type: Float, default: 0.0
  field :on_time_delivery_rate, type: Float, default: 0.0
  field :rework_rate, type: Float, default: 0.0
  
  # Sprint 메트릭
  field :sprint_completion_rate, type: Float, default: 0.0
  field :sprint_velocity, type: Float, default: 0.0
  field :sprint_burndown, type: Array, default: []
  
  # 멤버별 상세 메트릭
  field :member_metrics, type: Array, default: []
  # [{
  #   user_id: Integer,
  #   tasks_completed: Integer,
  #   hours_tracked: Float,
  #   productivity_score: Float,
  #   pomodoro_sessions: Integer
  # }]
  
  # 시간대별 활동 분포
  field :hourly_activity_distribution, type: Hash, default: {}
  field :weekday_activity_distribution, type: Hash, default: {}
  
  # 트렌드 데이터
  field :trend_data, type: Hash, default: {}
  field :comparison_data, type: Hash, default: {} # 이전 기간 대비
  
  # 메타데이터
  field :metadata, type: Hash, default: {}
  field :calculated_at, type: Time

  # Indexes
  index({ organization_id: 1, date: -1, period_type: 1 })
  index({ team_id: 1, date: -1, period_type: 1 })
  index({ user_id: 1, date: -1, period_type: 1 })
  index({ service_id: 1, date: -1, period_type: 1 })
  index({ period_type: 1, date: -1 })
  index({ calculated_at: -1 })
  
  # 복합 유니크 인덱스
  index({ organization_id: 1, date: 1, period_type: 1 }, { unique: true, sparse: true })
  index({ team_id: 1, date: 1, period_type: 1 }, { unique: true, sparse: true })
  index({ user_id: 1, date: 1, period_type: 1 }, { unique: true, sparse: true })

  # Validations
  validates :date, presence: true
  validates :period_type, inclusion: { in: %w[daily weekly monthly quarterly yearly] }
  validate :validate_entity_presence

  # Scopes
  scope :daily, -> { where(period_type: 'daily') }
  scope :weekly, -> { where(period_type: 'weekly') }
  scope :monthly, -> { where(period_type: 'monthly') }
  scope :by_organization, ->(org_id) { where(organization_id: org_id) }
  scope :by_team, ->(team_id) { where(team_id: team_id) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_service, ->(service_id) { where(service_id: service_id) }
  scope :recent, -> { order(date: :desc) }
  scope :date_range, ->(start_date, end_date) { where(date: { '$gte': start_date, '$lte': end_date }) }

  # Class methods
  class << self
    # 일일 메트릭 계산
    def calculate_daily_metrics(date = Date.current)
      Organization.find_each do |org|
        calculate_organization_metrics(org, date, 'daily')
        
        org.teams.find_each do |team|
          calculate_team_metrics(team, date, 'daily')
        end
        
        org.users.find_each do |user|
          calculate_user_metrics(user, date, 'daily')
        end
        
        org.services.find_each do |service|
          calculate_service_metrics(service, date, 'daily')
        end
      end
    end

    # 주간 메트릭 계산
    def calculate_weekly_metrics(date = Date.current)
      week_start = date.beginning_of_week
      week_end = date.end_of_week
      
      Organization.find_each do |org|
        aggregate_period_metrics(org, week_start, week_end, 'weekly')
      end
    end

    # 월간 메트릭 계산
    def calculate_monthly_metrics(date = Date.current)
      month_start = date.beginning_of_month
      month_end = date.end_of_month
      
      Organization.find_each do |org|
        aggregate_period_metrics(org, month_start, month_end, 'monthly')
      end
    end

    # 조직 메트릭 계산
    def calculate_organization_metrics(organization, date, period_type)
      metrics = find_or_initialize_by(
        organization_id: organization.id,
        date: date,
        period_type: period_type
      )
      
      # Task 메트릭
      tasks = organization.tasks.where(created_at: date.beginning_of_day..date.end_of_day)
      metrics.tasks_created = tasks.count
      metrics.tasks_completed = tasks.done.count
      metrics.tasks_in_progress = tasks.in_progress.count
      metrics.tasks_cancelled = tasks.where(status: 'cancelled').count
      metrics.tasks_overdue = organization.tasks.overdue.count
      
      # 상태 분포
      metrics.task_status_distribution = tasks.group(:status).count
      metrics.task_priority_distribution = tasks.group(:priority).count
      
      # 포모도로 메트릭 (MongoDB)
      pomodoro_stats = calculate_pomodoro_metrics(organization.id, date, 'organization')
      metrics.merge!(pomodoro_stats)
      
      # 팀 메트릭
      metrics.team_member_count = organization.users.count
      metrics.active_member_count = organization.users.joins(:tasks)
                                                    .where(tasks: { updated_at: date.beginning_of_day..date.end_of_day })
                                                    .distinct.count
      
      # 생산성 메트릭
      metrics.productivity_score = calculate_productivity_score(metrics)
      metrics.completion_rate = calculate_completion_rate(metrics)
      
      # 멤버별 메트릭
      metrics.member_metrics = calculate_member_metrics(organization, date)
      
      # 시간대별 활동
      metrics.hourly_activity_distribution = calculate_hourly_distribution(organization, date)
      
      metrics.calculated_at = Time.current
      metrics.save!
    end

    # 팀 메트릭 계산
    def calculate_team_metrics(team, date, period_type)
      metrics = find_or_initialize_by(
        team_id: team.id,
        organization_id: team.organization_id,
        date: date,
        period_type: period_type
      )
      
      # 팀 Task 메트릭
      tasks = team.tasks.where(created_at: date.beginning_of_day..date.end_of_day)
      metrics.tasks_created = tasks.count
      metrics.tasks_completed = tasks.done.count
      
      # 팀 벨로시티
      metrics.team_velocity = calculate_team_velocity(team, date)
      metrics.team_capacity = calculate_team_capacity(team, date)
      metrics.team_utilization = metrics.team_capacity > 0 ? 
                                (metrics.team_velocity / metrics.team_capacity * 100) : 0
      
      metrics.calculated_at = Time.current
      metrics.save!
    end

    # 사용자 메트릭 계산
    def calculate_user_metrics(user, date, period_type)
      metrics = find_or_initialize_by(
        user_id: user.id,
        organization_id: user.current_organization_id,
        date: date,
        period_type: period_type
      )
      
      # 개인 Task 메트릭
      tasks = user.tasks.where(updated_at: date.beginning_of_day..date.end_of_day)
      metrics.tasks_completed = tasks.done.count
      metrics.tasks_in_progress = tasks.in_progress.count
      
      # 포모도로 세션
      pomodoro_stats = PomodoroSessionMongo.by_user(user.id)
                                           .where(started_at: date.beginning_of_day..date.end_of_day)
      
      metrics.pomodoro_sessions_completed = pomodoro_stats.completed.count
      metrics.pomodoro_sessions_cancelled = pomodoro_stats.cancelled.count
      metrics.average_pomodoro_productivity = pomodoro_stats.completed.avg(:productivity_score) || 0
      
      # 개인 생산성
      metrics.productivity_score = calculate_user_productivity(user, date)
      
      metrics.calculated_at = Time.current
      metrics.save!
    end

    # 서비스 메트릭 계산
    def calculate_service_metrics(service, date, period_type)
      metrics = find_or_initialize_by(
        service_id: service.id,
        organization_id: service.organization_id,
        date: date,
        period_type: period_type
      )
      
      # 서비스별 Task 메트릭
      tasks = service.tasks.where(created_at: date.beginning_of_day..date.end_of_day)
      metrics.tasks_created = tasks.count
      metrics.tasks_completed = tasks.done.count
      
      metrics.calculated_at = Time.current
      metrics.save!
    end

    # 기간 집계 메트릭
    def aggregate_period_metrics(organization, start_date, end_date, period_type)
      daily_metrics = by_organization(organization.id)
                     .daily
                     .date_range(start_date, end_date)
      
      return if daily_metrics.empty?
      
      aggregated = find_or_initialize_by(
        organization_id: organization.id,
        date: start_date,
        period_type: period_type
      )
      
      aggregated.period_start = start_date
      aggregated.period_end = end_date
      
      # 합계 계산
      aggregated.tasks_created = daily_metrics.sum(:tasks_created)
      aggregated.tasks_completed = daily_metrics.sum(:tasks_completed)
      aggregated.pomodoro_sessions_completed = daily_metrics.sum(:pomodoro_sessions_completed)
      
      # 평균 계산
      aggregated.productivity_score = daily_metrics.avg(:productivity_score)
      aggregated.completion_rate = daily_metrics.avg(:completion_rate)
      
      # 트렌드 데이터
      aggregated.trend_data = calculate_trend_data(daily_metrics)
      
      # 이전 기간 대비
      aggregated.comparison_data = calculate_comparison_data(organization, start_date, end_date, period_type)
      
      aggregated.calculated_at = Time.current
      aggregated.save!
    end

    # 대시보드 데이터 조회
    def dashboard_data(organization_id, date = Date.current, period = 'daily')
      metrics = by_organization(organization_id)
               .where(date: date, period_type: period)
               .first
      
      return default_metrics if metrics.nil?
      
      format_dashboard_data(metrics)
    end

    # 트렌드 데이터 조회
    def trend_data(organization_id, period = 'daily', days = 30)
      end_date = Date.current
      start_date = end_date - days.days
      
      by_organization(organization_id)
        .where(period_type: period)
        .date_range(start_date, end_date)
        .map { |m| format_trend_point(m) }
    end

    private

    def calculate_pomodoro_metrics(entity_id, date, entity_type)
      scope = case entity_type
              when 'organization'
                PomodoroSessionMongo.by_organization(entity_id)
              when 'team'
                # Team 기반 조회 로직
                PomodoroSessionMongo.where(organization_id: entity_id)
              when 'user'
                PomodoroSessionMongo.by_user(entity_id)
              end
      
      sessions = scope.where(started_at: date.beginning_of_day..date.end_of_day)
      
      {
        pomodoro_sessions_completed: sessions.completed.count,
        pomodoro_sessions_cancelled: sessions.cancelled.count,
        average_pomodoro_productivity: sessions.completed.avg(:productivity_score) || 0,
        pomodoro_focus_level_avg: sessions.completed.avg(:focus_level) || 0,
        pomodoro_interruptions_total: sessions.sum { |s| s.interruptions.count }
      }
    end

    def calculate_productivity_score(metrics)
      score = 0.0
      weights = {
        completion_rate: 0.3,
        on_time_rate: 0.2,
        pomodoro_productivity: 0.2,
        focus_level: 0.15,
        interruption_penalty: 0.15
      }
      
      # 완료율 점수
      if metrics.tasks_created > 0
        completion_rate = metrics.tasks_completed.to_f / metrics.tasks_created
        score += completion_rate * 100 * weights[:completion_rate]
      end
      
      # 포모도로 생산성
      score += metrics.average_pomodoro_productivity * weights[:pomodoro_productivity]
      
      # 집중도
      score += (metrics.pomodoro_focus_level_avg * 20) * weights[:focus_level]
      
      # 중단 페널티
      if metrics.pomodoro_sessions_completed > 0
        interruption_rate = metrics.pomodoro_interruptions_total.to_f / metrics.pomodoro_sessions_completed
        interruption_penalty = [100 - (interruption_rate * 10), 0].max
        score += interruption_penalty * weights[:interruption_penalty]
      end
      
      [score.round(1), 100].min
    end

    def calculate_completion_rate(metrics)
      return 0 if metrics.tasks_created == 0
      (metrics.tasks_completed.to_f / metrics.tasks_created * 100).round(1)
    end

    def calculate_team_velocity(team, date)
      # Story points 또는 태스크 수 기반 벨로시티
      team.tasks.done
          .where(completed_at: date.beginning_of_day..date.end_of_day)
          .sum(:story_points) || 0
    end

    def calculate_team_capacity(team, date)
      # 팀 멤버 수 * 업무 시간
      team.users.count * 8 # 8시간 기준
    end

    def calculate_user_productivity(user, date)
      tasks_completed = user.tasks.done
                           .where(completed_at: date.beginning_of_day..date.end_of_day)
                           .count
      
      pomodoros = PomodoroSessionMongo.by_user(user.id)
                                      .completed
                                      .where(started_at: date.beginning_of_day..date.end_of_day)
      
      base_score = tasks_completed * 10
      base_score += pomodoros.count * 5
      base_score += pomodoros.avg(:productivity_score) || 0
      
      [base_score, 100].min
    end

    def calculate_member_metrics(organization, date)
      organization.users.map do |user|
        tasks = user.tasks.where(updated_at: date.beginning_of_day..date.end_of_day)
        pomodoros = PomodoroSessionMongo.by_user(user.id)
                                       .where(started_at: date.beginning_of_day..date.end_of_day)
        
        {
          user_id: user.id,
          user_name: user.name,
          tasks_completed: tasks.done.count,
          hours_tracked: pomodoros.sum(:actual_duration).to_f / 3600,
          productivity_score: calculate_user_productivity(user, date),
          pomodoro_sessions: pomodoros.completed.count
        }
      end
    end

    def calculate_hourly_distribution(organization, date)
      activities = UserActionLog.by_organization(organization.id)
                                .where(created_at: date.beginning_of_day..date.end_of_day)
      
      distribution = {}
      24.times { |hour| distribution[hour] = 0 }
      
      activities.each do |activity|
        hour = activity.created_at.hour
        distribution[hour] += 1
      end
      
      distribution
    end

    def calculate_trend_data(daily_metrics)
      {
        tasks_completed: daily_metrics.map { |m| { date: m.date, value: m.tasks_completed } },
        productivity_score: daily_metrics.map { |m| { date: m.date, value: m.productivity_score } },
        pomodoro_sessions: daily_metrics.map { |m| { date: m.date, value: m.pomodoro_sessions_completed } }
      }
    end

    def calculate_comparison_data(organization, start_date, end_date, period_type)
      period_length = (end_date - start_date).to_i
      previous_start = start_date - period_length.days
      previous_end = start_date - 1.day
      
      previous_metrics = by_organization(organization.id)
                        .where(period_type: 'daily')
                        .date_range(previous_start, previous_end)
      
      return {} if previous_metrics.empty?
      
      current_total_tasks = daily_metrics.sum(:tasks_completed)
      previous_total_tasks = previous_metrics.sum(:tasks_completed)
      
      {
        tasks_completed_change: percentage_change(previous_total_tasks, current_total_tasks),
        productivity_change: percentage_change(
          previous_metrics.avg(:productivity_score),
          daily_metrics.avg(:productivity_score)
        )
      }
    end

    def percentage_change(old_value, new_value)
      return 0 if old_value == 0
      ((new_value - old_value) / old_value * 100).round(1)
    end

    def default_metrics
      {
        tasks_completed: 0,
        tasks_in_progress: 0,
        productivity_score: 0,
        team_velocity: 0,
        pomodoro_sessions: 0
      }
    end

    def format_dashboard_data(metrics)
      {
        summary: {
          tasks_completed: metrics.tasks_completed,
          productivity_score: metrics.productivity_score,
          team_velocity: metrics.team_velocity,
          active_members: metrics.active_member_count
        },
        charts: {
          task_distribution: metrics.task_status_distribution,
          hourly_activity: metrics.hourly_activity_distribution,
          member_performance: metrics.member_metrics
        },
        trends: metrics.trend_data,
        comparison: metrics.comparison_data
      }
    end

    def format_trend_point(metric)
      {
        date: metric.date,
        tasks_completed: metric.tasks_completed,
        productivity: metric.productivity_score,
        pomodoros: metric.pomodoro_sessions_completed
      }
    end
  end

  private

  def validate_entity_presence
    unless organization_id || team_id || user_id || service_id
      errors.add(:base, "At least one entity (organization, team, user, or service) must be present")
    end
  end
end