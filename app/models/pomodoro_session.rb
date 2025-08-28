class PomodoroSession < ApplicationRecord
  # Associations
  belongs_to :task
  belongs_to :user
  
  # Constants
  WORK_DURATION = 25.minutes
  SHORT_BREAK = 5.minutes
  LONG_BREAK = 15.minutes
  SESSIONS_BEFORE_LONG_BREAK = 4
  
  # Enums
  enum :status, {
    in_progress: 0,
    completed: 1,
    cancelled: 2,
    paused: 3
  }, default: :in_progress
  
  # Validations
  validates :session_count, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  # Scopes
  scope :today, -> { where(started_at: Date.current.beginning_of_day..Date.current.end_of_day) }
  scope :this_week, -> { where(started_at: Date.current.beginning_of_week..Date.current.end_of_week) }
  scope :last_week, -> { where(started_at: 1.week.ago.beginning_of_week..1.week.ago.end_of_week) }
  scope :completed, -> { where(status: :completed) }
  scope :in_progress, -> { where(status: :in_progress) }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_task, ->(task) { where(task: task) }
  scope :ordered, -> { order(started_at: :desc) }
  
  # Callbacks
  before_validation :set_defaults, on: :create
  before_save :calculate_duration, if: :completed_at_changed?
  
  # 다음 세션 시작 시간 계산 (업무 시간 내에서만)
  def next_session_start_time
    if during_business_hours?
      Time.current + break_duration
    else
      next_business_day_start
    end
  end
  
  # 세션 완료 처리
  def complete!
    return false if completed?
    
    self.status = :completed
    self.completed_at = Time.current
    self.ended_at = Time.current
    self.actual_duration = (ended_at - started_at).to_i if started_at && ended_at
    save
  end
  
  # 세션 취소 처리
  def cancel!
    return false if completed? || cancelled?
    
    self.status = :cancelled
    self.completed_at = Time.current
    self.ended_at = Time.current
    self.actual_duration = (ended_at - started_at).to_i if started_at && ended_at
    save
  end
  
  # 세션 시작 처리
  def start!
    return false if in_progress? || completed?
    
    self.status = :in_progress
    self.started_at = Time.current
    save
  end
  
  # 세션 일시정지
  def pause!
    return false unless in_progress?
    
    self.status = :paused
    self.paused_at = Time.current
    save
  end
  
  # 세션 재개
  def resume!
    return false unless paused?
    
    if paused_at
      pause_time = Time.current - paused_at
      self.paused_duration ||= 0
      self.paused_duration += pause_time.to_i
    end
    
    self.status = :in_progress
    self.paused_at = nil
    save
  end
  
  # 세션이 중단되었는지 확인
  def interrupted?
    return false unless completed_at && started_at
    
    duration_minutes = (completed_at - started_at) / 60
    duration_minutes < 25
  end
  
  # 세션 시간 계산
  def duration
    return nil unless completed_at && started_at
    
    completed_at - started_at
  end
  
  # 포모도로 사이클에서 몇 번째 세션인지
  def session_in_cycle
    return 0 if session_count.nil? || session_count == 0
    
    ((session_count - 1) % SESSIONS_BEFORE_LONG_BREAK) + 1
  end
  
  # 긴 휴식 시간인지 확인
  def long_break_next?
    # 오늘 완료한 세션 수를 기반으로 판단
    today_count = self.class.by_user(user).today.completed.count
    # 4개 완료 후 다음 세션은 긴 휴식
    (today_count % SESSIONS_BEFORE_LONG_BREAK) == 0 && today_count > 0
  end
  
  # 오늘 완료한 세션 수
  def todays_completed_sessions
    self.class.by_user(user)
              .today
              .completed
              .count
  end
  
  # 이번 주 완료한 세션 수
  def weekly_completed_sessions
    self.class.by_user(user)
              .this_week
              .completed
              .count
  end
  
  # 작업별 총 포모도로 시간
  def total_task_time
    self.class.by_task(task)
              .completed
              .sum { |session| session.duration || 0 }
  end
  
  # 생산성 점수 계산 (완료율 및 업무시간 기반)
  def productivity_score
    return 0 unless completed?
    
    base_score = 100
    
    # 업무 시간 내 보너스
    if during_business_hours?
      base_score *= 1.2
    end
    
    # 점심시간 페널티  
    lunch_start = started_at.change(hour: 12, min: 0)
    lunch_end = started_at.change(hour: 13, min: 0)
    if started_at.between?(lunch_start, lunch_end)
      base_score *= 0.8
    end
    
    # 야근/새벽 페널티 (피로도)
    if !during_business_hours?
      hour = started_at.hour
      base_score *= case hour
                    when 0..6 then 0.5  # 새벽
                    when 19..21 then 0.9 # 저녁 야근
                    when 22..23 then 0.7 # 늦은 밤
                    else 0.8            # 주말
                    end
    end
    
    [base_score.round, 120].min
  end
  
  # Groupdate를 활용한 세션 패턴 분석 (클래스 메서드)
  class << self
    # 시간대별 세션 분포
    def hourly_distribution
      group_by_hour_of_day(:started_at, format: "%l %P", time_zone: "Asia/Seoul").count
    end
    
    # 요일별 세션 수
    def weekday_distribution
      group_by_day_of_week(:started_at, format: "%a").count
    end
    
    # 월별 추세
    def monthly_trend(months = 6)
      group_by_month(:started_at, last: months).count
    end
    
    # 업무시간 vs 야근 세션 비율
    def business_hours_ratio
      total = count
      return 0 if total == 0
      
      business_hours_count = where("EXTRACT(HOUR FROM started_at) BETWEEN 9 AND 18")
                            .where("EXTRACT(DOW FROM started_at) BETWEEN 1 AND 5")
                            .count
      
      (business_hours_count.to_f / total * 100).round(1)
    end
    
    # 평균 일일 세션 수
    def average_daily_sessions(user = nil)
      scope = user ? where(user: user) : all
      
      daily_counts = scope.group_by_day(:started_at, last: 30).count.values
      return 0 if daily_counts.empty?
      
      (daily_counts.sum.to_f / daily_counts.size).round(1)
    end
    
    # 최적 포모도로 시간대 분석
    def optimal_pomodoro_times(user = nil)
      scope = user ? where(user: user) : all
      
      # 완료된 세션만 분석
      completed_by_hour = scope.completed
                               .group_by_hour_of_day(:started_at)
                               .count
      
      # 상위 3개 시간대
      completed_by_hour.sort_by { |_, count| -count }
                      .first(3)
                      .map { |hour, count| 
                        { 
                          hour: hour, 
                          count: count,
                          recommendation: productivity_recommendation(hour.to_i)
                        }
                      }
    end
    
    private
    
    def productivity_recommendation(hour)
      case hour
      when 9..11
        "오전 집중 시간 - 복잡한 작업 추천"
      when 14..16
        "오후 집중 시간 - 창의적 작업 추천"  
      when 17..18
        "마무리 시간 - 간단한 작업 추천"
      else
        "비표준 시간 - 충분한 휴식 필요"
      end
    end
  end
  
  # 다음 세션 타입
  def next_session_type
    # session_count가 있으면 그것을 기준으로 판단
    if session_count && (session_count % SESSIONS_BEFORE_LONG_BREAK) == 0 && session_count > 0
      :long_break
    elsif long_break_next?
      :long_break
    else
      :short_break
    end
  end
  
  # 세션 완료까지 남은 시간
  def time_remaining
    return 0 if completed? || cancelled?
    return nil unless in_progress?
    
    elapsed = Time.current - started_at
    # 일시정지된 시간은 제외
    elapsed -= (paused_duration || 0)
    remaining = WORK_DURATION - elapsed
    
    remaining > 0 ? remaining : 0
  end
  
  # 세션 진행률
  def progress_percentage
    return 100 if completed?
    return 0 unless in_progress?
    
    elapsed = Time.current - started_at
    # 일시정지된 시간은 제외
    elapsed -= (paused_duration || 0)
    percentage = (elapsed / WORK_DURATION * 100).round
    
    [percentage, 100].min
  end
  
  private
  
  def during_business_hours?
    Time.current.on_weekday? && Time.current.during_business_hours?
  end
  
  def next_business_day_start
    next_business_day = 1.business_day.from_now
    
    Time.zone.local(
      next_business_day.year,
      next_business_day.month,
      next_business_day.day,
      9, # 오전 9시 시작
      0,
      0
    )
  end
  
  def break_duration
    session_count && session_count % SESSIONS_BEFORE_LONG_BREAK == 0 ? LONG_BREAK : SHORT_BREAK
  end
  
  def set_defaults
    self.session_count ||= calculate_session_count
    self.started_at ||= Time.current
    self.status ||= :in_progress
  end
  
  def calculate_session_count
    today_count = self.class.by_user(user).today.completed.count
    today_count + 1
  end
  
  def calculate_duration
    return unless started_at && completed_at
    
    self.duration = (completed_at - started_at).to_i
  end
end