# frozen_string_literal: true

# MongoDB에 저장되는 포모도로 세션 데이터
class PomodoroSessionMongo
  include Mongoid::Document
  include Mongoid::Timestamps

  # Constants
  WORK_DURATION = 25.minutes
  SHORT_BREAK = 5.minutes
  LONG_BREAK = 15.minutes
  SESSIONS_BEFORE_LONG_BREAK = 4

  # Fields
  field :task_id, type: Integer
  field :user_id, type: Integer
  field :organization_id, type: Integer
  field :session_count, type: Integer, default: 0
  field :status, type: String, default: 'in_progress' # in_progress, completed, cancelled, paused
  field :started_at, type: Time
  field :ended_at, type: Time
  field :completed_at, type: Time
  field :paused_at, type: Time
  field :paused_duration, type: Integer, default: 0 # in seconds
  field :actual_duration, type: Integer # in seconds
  field :planned_duration, type: Integer, default: WORK_DURATION.to_i
  field :session_type, type: String, default: 'work' # work, short_break, long_break
  
  # Additional tracking fields
  field :interruptions, type: Array, default: []
  field :productivity_score, type: Float
  field :focus_level, type: Integer # 1-5 scale
  field :notes, type: String
  field :tags, type: Array, default: []
  field :location, type: Hash # { lat: , lng: , name: }
  field :device_info, type: Hash # { device: , browser: , os: }
  field :environment, type: Hash # { noise_level: , lighting: , temperature: }
  field :metadata, type: Hash, default: {}

  # Time tracking arrays for detailed analysis
  field :pause_events, type: Array, default: [] # [{paused_at: , resumed_at: , duration: , reason: }]
  field :focus_events, type: Array, default: [] # [{time: , level: , note: }]
  field :distraction_events, type: Array, default: [] # [{time: , type: , duration: , description: }]

  # Indexes
  index({ user_id: 1, started_at: -1 })
  index({ task_id: 1, started_at: -1 })
  index({ organization_id: 1, started_at: -1 })
  index({ status: 1, started_at: -1 })
  index({ started_at: -1 })
  index({ completed_at: -1 })
  index({ user_id: 1, status: 1, started_at: -1 })
  index({ productivity_score: -1 })
  
  # TTL index - 1년 후 자동 삭제 (선택적)
  # index({ created_at: 1 }, { expire_after_seconds: 31536000 })

  # Validations
  validates :user_id, presence: true
  validates :task_id, presence: true
  validates :status, inclusion: { in: %w[in_progress completed cancelled paused] }
  validates :session_type, inclusion: { in: %w[work short_break long_break] }
  validates :focus_level, inclusion: { in: 1..5 }, allow_nil: true

  # Scopes
  scope :recent, -> { order(started_at: :desc) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_task, ->(task_id) { where(task_id: task_id) }
  scope :by_organization, ->(org_id) { where(organization_id: org_id) }
  scope :by_status, ->(status) { where(status: status) }
  scope :completed, -> { where(status: 'completed') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :today, -> { where(started_at: { '$gte': Time.zone.now.beginning_of_day }) }
  scope :this_week, -> { where(started_at: { '$gte': Time.zone.now.beginning_of_week }) }
  scope :this_month, -> { where(started_at: { '$gte': Time.zone.now.beginning_of_month }) }
  scope :date_range, ->(start_date, end_date) { where(started_at: { '$gte': start_date, '$lte': end_date }) }
  scope :work_sessions, -> { where(session_type: 'work') }
  scope :break_sessions, -> { where(session_type: ['short_break', 'long_break']) }

  # Class methods
  class << self
    # 새 세션 시작
    def start_session(user_id, task_id, organization_id, session_type = 'work')
      session_count = calculate_session_count(user_id)
      
      create!(
        user_id: user_id,
        task_id: task_id,
        organization_id: organization_id,
        session_count: session_count,
        session_type: session_type,
        status: 'in_progress',
        started_at: Time.current,
        planned_duration: duration_for_type(session_type)
      )
    end

    # 시간대별 세션 분포 분석
    def hourly_distribution(user_id = nil)
      pipeline = []
      pipeline << { '$match': { user_id: user_id } } if user_id
      pipeline << {
        '$group': {
          _id: { '$hour': '$started_at' },
          count: { '$sum': 1 },
          avg_productivity: { '$avg': '$productivity_score' }
        }
      }
      pipeline << { '$sort': { _id: 1 } }
      
      collection.aggregate(pipeline).to_a
    end

    # 요일별 완료율 분석
    def weekday_completion_rate(user_id = nil)
      pipeline = []
      pipeline << { '$match': { user_id: user_id } } if user_id
      pipeline << {
        '$group': {
          _id: { '$dayOfWeek': '$started_at' },
          total: { '$sum': 1 },
          completed: {
            '$sum': { '$cond': [{ '$eq': ['$status', 'completed'] }, 1, 0] }
          }
        }
      }
      pipeline << {
        '$project': {
          day: '$_id',
          total: 1,
          completed: 1,
          completion_rate: {
            '$multiply': [{ '$divide': ['$completed', '$total'] }, 100]
          }
        }
      }
      
      collection.aggregate(pipeline).to_a
    end

    # 생산성 트렌드 분석
    def productivity_trend(user_id, days = 30)
      start_date = days.days.ago
      
      by_user(user_id)
        .completed
        .date_range(start_date, Time.current)
        .group_by { |s| s.started_at.to_date }
        .transform_values { |sessions|
          {
            count: sessions.count,
            avg_productivity: sessions.map(&:productivity_score).compact.sum.to_f / sessions.count,
            total_duration: sessions.map(&:actual_duration).compact.sum
          }
        }
    end

    # 최적 포모도로 시간대 찾기
    def optimal_times(user_id)
      completed
        .by_user(user_id)
        .where(:productivity_score.gte => 80)
        .group_by { |s| s.started_at.hour }
        .transform_values(&:count)
        .sort_by { |_, count| -count }
        .first(3)
        .map { |hour, count| 
          {
            hour: hour,
            count: count,
            recommendation: time_recommendation(hour)
          }
        }
    end

    # 집중력 패턴 분석
    def focus_pattern_analysis(user_id, period = :week)
      range = case period
              when :day then 1.day.ago..Time.current
              when :week then 1.week.ago..Time.current
              when :month then 1.month.ago..Time.current
              else 1.week.ago..Time.current
              end

      sessions = by_user(user_id)
                 .completed
                 .date_range(range.first, range.last)
                 .where(:focus_level.ne => nil)

      {
        average_focus: sessions.avg(:focus_level),
        focus_distribution: sessions.group_by(&:focus_level)
                                   .transform_values(&:count),
        high_focus_times: sessions.where(:focus_level.gte => 4)
                                  .group_by { |s| s.started_at.hour }
                                  .transform_values(&:count),
        low_focus_factors: analyze_low_focus_factors(sessions)
      }
    end

    # 중단 패턴 분석
    def interruption_analysis(user_id)
      sessions = by_user(user_id).this_month
      
      {
        total_interruptions: sessions.sum { |s| s.interruptions.count },
        avg_interruptions_per_session: sessions.avg { |s| s.interruptions.count },
        common_interruption_times: analyze_interruption_times(sessions),
        interruption_impact: calculate_interruption_impact(sessions)
      }
    end

    private

    def calculate_session_count(user_id)
      today.by_user(user_id).completed.count + 1
    end

    def duration_for_type(type)
      case type
      when 'work' then WORK_DURATION.to_i
      when 'short_break' then SHORT_BREAK.to_i
      when 'long_break' then LONG_BREAK.to_i
      else WORK_DURATION.to_i
      end
    end

    def time_recommendation(hour)
      case hour
      when 9..11 then "오전 골든타임 - 복잡한 작업 추천"
      when 14..16 then "오후 집중 시간 - 창의적 작업 추천"
      when 17..18 then "마무리 시간 - 정리 작업 추천"
      when 19..21 then "저녁 시간 - 가벼운 작업 추천"
      else "비표준 시간 - 충분한 휴식 권장"
      end
    end

    def analyze_low_focus_factors(sessions)
      low_focus = sessions.where(:focus_level.lte => 2)
      
      factors = {
        time_of_day: {},
        session_count: {},
        interruptions: 0
      }

      low_focus.each do |session|
        hour = session.started_at.hour
        factors[:time_of_day][hour] ||= 0
        factors[:time_of_day][hour] += 1
        
        factors[:session_count][session.session_count] ||= 0
        factors[:session_count][session.session_count] += 1
        
        factors[:interruptions] += session.interruptions.count
      end

      factors
    end

    def analyze_interruption_times(sessions)
      interruption_times = []
      
      sessions.each do |session|
        session.interruptions.each do |interruption|
          if interruption['time']
            hour = Time.parse(interruption['time'].to_s).hour
            interruption_times << hour
          end
        end
      end

      interruption_times.group_by(&:itself)
                       .transform_values(&:count)
                       .sort_by { |_, count| -count }
    end

    def calculate_interruption_impact(sessions)
      interrupted = sessions.select { |s| s.interruptions.any? }
      uninterrupted = sessions.select { |s| s.interruptions.empty? }

      {
        interrupted_avg_productivity: interrupted.map(&:productivity_score).compact.sum.to_f / interrupted.count,
        uninterrupted_avg_productivity: uninterrupted.map(&:productivity_score).compact.sum.to_f / uninterrupted.count,
        productivity_difference: (uninterrupted.map(&:productivity_score).compact.sum.to_f / uninterrupted.count) - 
                               (interrupted.map(&:productivity_score).compact.sum.to_f / interrupted.count)
      }
    rescue
      { error: "Not enough data" }
    end
  end

  # Instance methods

  # 세션 완료
  def complete!(focus_level = nil, notes = nil)
    return false if completed?

    self.status = 'completed'
    self.completed_at = Time.current
    self.ended_at = Time.current
    self.actual_duration = calculate_actual_duration
    self.focus_level = focus_level if focus_level
    self.notes = notes if notes
    self.productivity_score = calculate_productivity_score
    
    save
  end

  # 세션 취소
  def cancel!(reason = nil)
    return false if completed? || cancelled?

    self.status = 'cancelled'
    self.ended_at = Time.current
    self.actual_duration = calculate_actual_duration
    self.metadata[:cancel_reason] = reason if reason
    
    save
  end

  # 세션 일시정지
  def pause!(reason = nil)
    return false unless in_progress?

    self.status = 'paused'
    self.paused_at = Time.current
    
    pause_event = {
      paused_at: Time.current,
      reason: reason
    }
    self.pause_events << pause_event
    
    save
  end

  # 세션 재개
  def resume!
    return false unless paused?

    if paused_at
      pause_duration = Time.current - paused_at
      self.paused_duration += pause_duration.to_i
      
      # 마지막 pause_event 업데이트
      if pause_events.last && !pause_events.last['resumed_at']
        pause_events.last['resumed_at'] = Time.current
        pause_events.last['duration'] = pause_duration.to_i
      end
    end

    self.status = 'in_progress'
    self.paused_at = nil
    
    save
  end

  # 중단 기록
  def add_interruption(type, description = nil)
    interruption = {
      time: Time.current,
      type: type,
      description: description,
      session_time: Time.current - started_at
    }
    
    self.interruptions << interruption
    save
  end

  # 집중도 기록
  def record_focus_level(level, note = nil)
    focus_event = {
      time: Time.current,
      level: level,
      note: note,
      session_time: Time.current - started_at
    }
    
    self.focus_events << focus_event
    save
  end

  # 방해 요소 기록
  def record_distraction(type, duration = nil, description = nil)
    distraction = {
      time: Time.current,
      type: type,
      duration: duration,
      description: description,
      session_time: Time.current - started_at
    }
    
    self.distraction_events << distraction
    save
  end

  # 남은 시간
  def time_remaining
    return 0 if completed? || cancelled?
    return nil unless in_progress?

    elapsed = Time.current - started_at - paused_duration
    remaining = planned_duration - elapsed

    remaining > 0 ? remaining : 0
  end

  # 진행률
  def progress_percentage
    return 100 if completed?
    return 0 unless started_at

    elapsed = Time.current - started_at - paused_duration
    percentage = (elapsed.to_f / planned_duration * 100).round

    [percentage, 100].min
  end

  # 다음 세션 타입 결정
  def next_session_type
    return 'long_break' if should_take_long_break?
    return 'short_break' if session_type == 'work'
    'work'
  end

  # Helper methods
  def completed?
    status == 'completed'
  end

  def cancelled?
    status == 'cancelled'
  end

  def in_progress?
    status == 'in_progress'
  end

  def paused?
    status == 'paused'
  end

  # 관련 PostgreSQL 모델과의 연동
  def task
    @task ||= Task.find_by(id: task_id)
  end

  def user
    @user ||= User.find_by(id: user_id)
  end

  def organization
    @organization ||= Organization.find_by(id: organization_id)
  end

  private

  def calculate_actual_duration
    return 0 unless started_at
    
    end_time = ended_at || Time.current
    (end_time - started_at - paused_duration).to_i
  end

  def calculate_productivity_score
    return 0 unless completed?

    base_score = 100.0

    # 완료율 기반
    if actual_duration && planned_duration > 0
      completion_rate = [actual_duration.to_f / planned_duration, 1.0].min
      base_score *= completion_rate
    end

    # 집중도 기반
    if focus_level
      base_score *= (focus_level.to_f / 5)
    end

    # 중단 횟수 기반
    if interruptions.any?
      interruption_penalty = [interruptions.count * 5, 30].min
      base_score -= interruption_penalty
    end

    # 시간대 보너스
    if started_at.hour.between?(9, 11) || started_at.hour.between?(14, 16)
      base_score *= 1.1
    end

    [base_score.round, 100].min
  end

  def should_take_long_break?
    today_completed = self.class.today
                                .by_user(user_id)
                                .completed
                                .work_sessions
                                .count

    (today_completed % SESSIONS_BEFORE_LONG_BREAK) == 0 && today_completed > 0
  end
end