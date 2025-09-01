# app/models/mongodb/mongo_pomodoro_session.rb
class Mongodb::MongoPomodoroSession
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # ===== Core References =====
  field :organization_id, type: String  # UUID from PostgreSQL
  field :user_id, type: String          # UUID from PostgreSQL User
  field :task_id, type: String          # MongoDB Task ID (optional)
  
  # ===== Session Info =====
  field :session_type, type: String, default: 'pomodoro' # pomodoro, short_break, long_break
  field :duration_minutes, type: Integer, default: 25
  field :status, type: String, default: 'running' # running, completed, cancelled, paused
  
  # ===== Timeline =====
  field :started_at, type: DateTime
  field :completed_at, type: DateTime
  field :paused_at, type: DateTime
  field :total_pause_time, type: Integer, default: 0 # seconds
  field :actual_work_minutes, type: Integer
  
  # ===== Productivity Data =====
  field :interruptions, type: Array, default: []
  # [{
  #   timestamp: DateTime,
  #   type: 'internal|external',
  #   reason: String,
  #   duration_seconds: Integer
  # }]
  
  field :focus_score, type: Float # 0-100, 집중도 점수
  field :productivity_rating, type: Integer # 1-5, 사용자 주관적 평가
  field :energy_level, type: Integer # 1-5, 에너지 레벨
  
  # ===== Goals & Notes =====
  field :session_goal, type: String
  field :notes, type: String
  field :completed_goal, type: Boolean, default: false
  
  # ===== Context =====
  field :location, type: String # home, office, cafe, etc.
  field :environment_noise, type: String # quiet, moderate, noisy
  field :tools_used, type: Array, default: [] # ['vscode', 'figma', 'browser']
  
  # ===== Streak Tracking =====
  field :daily_session_number, type: Integer, default: 1
  field :weekly_session_number, type: Integer, default: 1
  field :current_streak, type: Integer, default: 1
  
  # ===== Analytics =====
  field :time_zone, type: String
  field :day_of_week, type: String
  field :hour_started, type: Integer
  field :session_date, type: Date
  
  # ===== Indexes =====
  index({ user_id: 1, session_date: -1 })
  index({ user_id: 1, task_id: 1 })
  index({ organization_id: 1, started_at: -1 })
  index({ status: 1, completed_at: 1 })
  
  # TTL: 90일 후 자동 삭제
  index({ completed_at: 1 }, { expire_after_seconds: 7776000 })
  
  # ===== Validations =====
  validates :user_id, presence: true
  validates :organization_id, presence: true
  validates :session_type, inclusion: { in: %w[pomodoro short_break long_break] }
  validates :status, inclusion: { in: %w[running completed cancelled paused] }
  validates :duration_minutes, presence: true, numericality: { greater_than: 0 }
  
  # ===== Scopes =====
  scope :today, -> { where(session_date: Date.current) }
  scope :this_week, -> { where(:session_date.gte => Date.current.beginning_of_week) }
  scope :completed, -> { where(status: 'completed') }
  scope :for_task, ->(task_id) { where(task_id: task_id) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  
  # ===== Class Methods =====
  class << self
    def daily_stats(user_id, date = Date.current)
      sessions = where(user_id: user_id, session_date: date)
      
      {
        total_sessions: sessions.count,
        completed_sessions: sessions.completed.count,
        total_work_minutes: sessions.completed.sum(:actual_work_minutes),
        average_focus_score: sessions.completed.avg(:focus_score)&.round(1),
        interruptions_count: sessions.sum { |s| s.interruptions.size },
        productivity_score: calculate_daily_productivity(sessions.completed)
      }
    end
    
    def weekly_trends(user_id, date = Date.current)
      week_start = date.beginning_of_week
      week_end = date.end_of_week
      
      sessions = where(
        user_id: user_id,
        :session_date.gte => week_start,
        :session_date.lte => week_end
      ).completed
      
      # 요일별 데이터
      daily_data = sessions.group_by(&:day_of_week).transform_values do |day_sessions|
        {
          sessions: day_sessions.count,
          work_minutes: day_sessions.sum(&:actual_work_minutes),
          avg_focus: day_sessions.map(&:focus_score).sum / day_sessions.size
        }
      end
      
      {
        week_range: "#{week_start.strftime('%m/%d')} - #{week_end.strftime('%m/%d')}",
        total_work_hours: (sessions.sum(:actual_work_minutes) / 60.0).round(1),
        daily_breakdown: daily_data,
        best_day: daily_data.max_by { |_, data| data[:avg_focus] }&.first,
        most_productive_hour: most_productive_hour(sessions)
      }
    end
    
    private
    
    def calculate_daily_productivity(sessions)
      return 0 if sessions.empty?
      
      # 완료된 세션 수, 평균 집중도, 목표 달성률을 종합하여 계산
      completion_rate = sessions.count { |s| s.completed_goal } / sessions.size.to_f
      avg_focus = sessions.map(&:focus_score).sum / sessions.size.to_f
      session_consistency = [sessions.size / 8.0, 1.0].min # 하루 8세션을 100%로 가정
      
      ((completion_rate * 0.4) + (avg_focus / 100 * 0.4) + (session_consistency * 0.2)) * 100
    end
    
    def most_productive_hour(sessions)
      return nil if sessions.empty?
      
      hour_data = sessions.group_by(&:hour_started).transform_values do |hour_sessions|
        hour_sessions.map(&:focus_score).sum / hour_sessions.size.to_f
      end
      
      hour_data.max_by { |_, avg_focus| avg_focus }&.first
    end
  end
  
  # ===== Instance Methods =====
  def start_session!
    self.started_at = Time.current
    self.session_date = Date.current
    self.status = 'running'
    self.day_of_week = Date.current.strftime('%A').downcase
    self.hour_started = Time.current.hour
    self.time_zone = Time.zone.name
    save!
  end
  
  def complete_session!(productivity_rating: nil, notes: nil, completed_goal: false)
    self.completed_at = Time.current
    self.status = 'completed'
    self.actual_work_minutes = calculate_actual_work_time
    self.productivity_rating = productivity_rating if productivity_rating
    self.notes = notes if notes
    self.completed_goal = completed_goal
    
    # 집중도 점수 계산
    self.focus_score = calculate_focus_score
    
    save!
  end
  
  def pause_session!
    self.paused_at = Time.current
    self.status = 'paused'
    save!
  end
  
  def resume_session!
    if paused_at.present?
      pause_duration = Time.current - paused_at
      self.total_pause_time += pause_duration.to_i
      self.paused_at = nil
    end
    
    self.status = 'running'
    save!
  end
  
  def add_interruption(type, reason, duration_seconds = 60)
    self.interruptions << {
      timestamp: Time.current,
      type: type,
      reason: reason,
      duration_seconds: duration_seconds
    }
    save!
  end
  
  def cancel_session!(reason = nil)
    self.status = 'cancelled'
    self.notes = reason if reason
    save!
  end
  
  def time_remaining
    return 0 unless running?
    
    elapsed = Time.current - started_at - total_pause_time
    remaining = (duration_minutes * 60) - elapsed
    [remaining, 0].max
  end
  
  def running?
    status == 'running'
  end
  
  def completed?
    status == 'completed'
  end
  
  private
  
  def calculate_actual_work_time
    return 0 unless started_at && completed_at
    
    total_time = completed_at - started_at
    interruption_time = interruptions.sum { |i| i[:duration_seconds] }
    
    actual_seconds = total_time - total_pause_time - interruption_time
    (actual_seconds / 60.0).round
  end
  
  def calculate_focus_score
    return 0 unless completed?
    
    # 기본 점수에서 방해 요소들 차감
    base_score = 100
    
    # 일시정지 페널티
    pause_penalty = [(total_pause_time / 60.0) * 2, 30].min
    
    # 인터럽션 페널티
    interruption_penalty = [interruptions.size * 5, 40].min
    
    # 시간 초과 페널티
    overtime_penalty = if actual_work_minutes > duration_minutes
      [(actual_work_minutes - duration_minutes) * 1.5, 25].min
    else
      0
    end
    
    final_score = base_score - pause_penalty - interruption_penalty - overtime_penalty
    [final_score, 0].max
  end
end