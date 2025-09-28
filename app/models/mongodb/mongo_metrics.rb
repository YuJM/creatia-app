# app/models/mongodb/mongo_metrics.rb
class Mongodb::MongoMetrics
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # ===== Core References =====
  field :organization_id, type: String  # UUID from PostgreSQL
  field :service_id, type: String       # UUID from PostgreSQL (optional)
  field :user_id, type: String          # UUID from PostgreSQL (optional)
  field :team_id, type: String          # UUID from PostgreSQL (optional)
  
  # ===== Metric Identification =====
  field :metric_type, type: String # sprint_velocity, task_completion_rate, user_productivity, etc.
  field :metric_category, type: String # performance, productivity, quality, engagement
  field :scope, type: String # organization, service, team, user, sprint, task
  field :scope_id, type: String # ID of the scope entity
  
  # ===== Time Series Data =====
  field :timestamp, type: DateTime
  field :date, type: Date
  field :hour, type: Integer
  field :day_of_week, type: String
  field :week_of_year, type: Integer
  field :month, type: Integer
  field :quarter, type: Integer
  field :year, type: Integer
  
  # ===== Metric Values =====
  field :value, type: Float
  field :previous_value, type: Float
  field :target_value, type: Float
  field :unit, type: String # points, hours, count, percentage, etc.
  
  # ===== Aggregation Data =====
  field :daily_aggregate, type: Hash, default: {}
  # {
  #   sum: Float,
  #   avg: Float,
  #   min: Float,
  #   max: Float,
  #   count: Integer,
  #   std_dev: Float
  # }
  
  field :weekly_aggregate, type: Hash, default: {}
  field :monthly_aggregate, type: Hash, default: {}
  
  # ===== Context & Metadata =====
  field :dimensions, type: Hash, default: {}
  # {
  #   sprint_id: 'sprint_123',
  #   task_type: 'feature',
  #   priority: 'high',
  #   assignee_role: 'developer'
  # }
  
  field :tags, type: Array, default: []
  field :source, type: String # system, manual, integration
  field :collection_method, type: String # periodic, event_based, manual
  
  # ===== Quality Indicators =====
  field :confidence_level, type: Float, default: 1.0 # 0-1
  field :accuracy_score, type: Float # 0-100
  field :data_freshness, type: Integer # seconds since collection
  
  # ===== Alerts & Thresholds =====
  field :alert_thresholds, type: Hash, default: {}
  # {
  #   warning: { operator: 'gt', value: 80 },
  #   critical: { operator: 'gt', value: 95 }
  # }
  
  field :anomaly_detected, type: Boolean, default: false
  field :anomaly_score, type: Float # 0-100
  
  # ===== Business Impact =====
  field :business_impact, type: String # low, medium, high, critical
  field :kpi_contribution, type: Float # -100 to 100
  field :actionable, type: Boolean, default: true
  
  # ===== Indexes =====
  index({ organization_id: 1, metric_type: 1, timestamp: -1 })
  index({ user_id: 1, date: -1 })
  index({ service_id: 1, metric_category: 1, timestamp: -1 })
  index({ scope: 1, scope_id: 1, timestamp: -1 })
  index({ metric_type: 1, date: -1 })
  index({ timestamp: -1 })
  
  # Compound index for time series queries
  index({ 
    organization_id: 1, 
    metric_type: 1, 
    year: 1, 
    month: 1, 
    date: 1 
  })
  
  # TTL: 6개월 후 자동 삭제
  index({ timestamp: 1 }, { expire_after_seconds: 15552000 })
  
  # ===== Validations =====
  validates :organization_id, presence: true
  validates :metric_type, presence: true
  validates :metric_category, presence: true
  validates :scope, presence: true
  validates :value, presence: true, numericality: true
  validates :timestamp, presence: true
  
  validates :metric_category, inclusion: { 
    in: %w[performance productivity quality engagement health cost] 
  }
  validates :scope, inclusion: { 
    in: %w[organization service team user sprint task epic milestone] 
  }
  validates :business_impact, inclusion: { 
    in: %w[low medium high critical] 
  }
  
  # ===== Scopes =====
  scope :recent, -> { order(timestamp: :desc) }
  scope :by_type, ->(type) { where(metric_type: type) }
  scope :by_category, ->(category) { where(metric_category: category) }
  scope :by_scope, ->(scope, scope_id) { where(scope: scope, scope_id: scope_id) }
  scope :today, -> { where(date: Date.current) }
  scope :this_week, -> { where(:date.gte => Date.current.beginning_of_week) }
  scope :this_month, -> { where(:date.gte => Date.current.beginning_of_month) }
  scope :anomalies, -> { where(anomaly_detected: true) }
  scope :actionable, -> { where(actionable: true) }
  
  # ===== Class Methods =====
  class << self
    # 실시간 메트릭 수집
    def collect_sprint_velocity(sprint_id)
      sprint = Mongodb::MongoSprint.find(sprint_id)
      return unless sprint
      
      velocity = calculate_sprint_velocity(sprint)
      
      create!(
        organization_id: sprint.organization_id,
        service_id: sprint.service_id,
        metric_type: 'sprint_velocity',
        metric_category: 'performance',
        scope: 'sprint',
        scope_id: sprint_id,
        value: velocity,
        unit: 'points_per_day',
        timestamp: Time.current,
        date: Date.current,
        source: 'system',
        collection_method: 'event_based',
        dimensions: {
          sprint_name: sprint.name,
          team_size: sprint.team_members.size,
          sprint_length: sprint.working_days
        }
      )
    end
    
    def collect_user_productivity(user_id, date = Date.current)
      # 포모도로 세션 기반 생산성 계산
      sessions = Mongodb::MongoPomodoroSession.where(
        user_id: user_id,
        session_date: date
      ).completed
      
      return if sessions.empty?
      
      productivity_score = sessions.map(&:focus_score).sum / sessions.size.to_f
      
      create!(
        organization_id: sessions.first.organization_id,
        user_id: user_id,
        metric_type: 'daily_productivity',
        metric_category: 'productivity',
        scope: 'user',
        scope_id: user_id,
        value: productivity_score,
        unit: 'percentage',
        timestamp: Time.current,
        date: date,
        source: 'system',
        collection_method: 'periodic',
        dimensions: {
          sessions_count: sessions.size,
          total_work_minutes: sessions.sum(&:actual_work_minutes),
          interruptions: sessions.sum { |s| s.interruptions.size }
        }
      )
    end
    
    def collect_task_completion_metrics(organization_id)
      # 최근 7일간 태스크 완료 메트릭
      tasks = Mongodb::MongoTask.where(
        organization_id: organization_id,
        :completed_at.gte => 7.days.ago
      )
      
      return if tasks.empty?
      
      # 평균 완료 시간 계산
      avg_completion_time = tasks.map do |task|
        next unless task.started_at && task.completed_at
        (task.completed_at - task.started_at) / 1.day
      end.compact.sum / tasks.size.to_f
      
      create!(
        organization_id: organization_id,
        metric_type: 'task_completion_time',
        metric_category: 'performance',
        scope: 'organization',
        scope_id: organization_id,
        value: avg_completion_time,
        unit: 'days',
        timestamp: Time.current,
        date: Date.current,
        source: 'system',
        collection_method: 'periodic',
        dimensions: {
          total_tasks: tasks.size,
          avg_story_points: tasks.avg(:story_points)&.round(1),
          completion_rate: (tasks.where(status: 'done').size / tasks.size.to_f * 100).round(1)
        }
      )
    end
    
    # 메트릭 대시보드용 집계 데이터
    def dashboard_metrics(organization_id, timeframe = 'week')
      case timeframe
      when 'day'
        date_range = Date.current
        group_by = :hour
      when 'week'
        date_range = Date.current.beginning_of_week..Date.current.end_of_week
        group_by = :date
      when 'month'
        date_range = Date.current.beginning_of_month..Date.current.end_of_month
        group_by = :date
      when 'quarter'
        date_range = Date.current.beginning_of_quarter..Date.current.end_of_quarter
        group_by = :week_of_year
      end
      
      metrics = where(
        organization_id: organization_id,
        :date.in => date_range
      )
      
      {
        performance: metrics.by_category('performance').group_by(&group_by),
        productivity: metrics.by_category('productivity').group_by(&group_by),
        quality: metrics.by_category('quality').group_by(&group_by),
        engagement: metrics.by_category('engagement').group_by(&group_by),
        summary: {
          total_metrics: metrics.count,
          anomalies_count: metrics.anomalies.count,
          avg_kpi_contribution: metrics.avg(:kpi_contribution)&.round(2)
        }
      }
    end
    
    private
    
    def calculate_sprint_velocity(sprint)
      return 0 unless sprint.start_date && sprint.completed_points
      
      days_elapsed = [(Date.current - sprint.start_date).to_i, 1].max
      sprint.completed_points.to_f / days_elapsed
    end
  end
  
  # ===== Instance Methods =====
  def trend_direction
    return 'stable' unless previous_value
    
    change_percentage = ((value - previous_value) / previous_value.abs) * 100
    
    case change_percentage
    when -Float::INFINITY..-10
      'declining'
    when -10..10
      'stable'
    when 10..Float::INFINITY
      'improving'
    else
      'stable'
    end
  end
  
  def alert_status
    return 'normal' if alert_thresholds.empty?
    
    critical_threshold = alert_thresholds.dig('critical', 'value')
    warning_threshold = alert_thresholds.dig('warning', 'value')
    
    if critical_threshold && meets_threshold?('critical')
      'critical'
    elsif warning_threshold && meets_threshold?('warning')
    'warning'
    else
      'normal'
    end
  end
  
  def meets_threshold?(level)
    threshold_config = alert_thresholds[level]
    return false unless threshold_config
    
    operator = threshold_config['operator']
    threshold_value = threshold_config['value']
    
    case operator
    when 'gt'
      value > threshold_value
    when 'lt'
      value < threshold_value
    when 'eq'
      value == threshold_value
    when 'gte'
      value >= threshold_value
    when 'lte'
      value <= threshold_value
    else
      false
    end
  end
  
  def formatted_value
    case unit
    when 'percentage'
      "#{value.round(1)}%"
    when 'hours'
      "#{value.round(1)}h"
    when 'days'
      "#{value.round(1)}d"
    when 'points'
      "#{value.round(1)} pts"
    when 'count'
      value.to_i.to_s
    else
      value.to_s
    end
  end
end