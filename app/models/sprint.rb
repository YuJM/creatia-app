class Sprint < ApplicationRecord
  # Concerns
  include FlexibleSchedule
  
  # Associations
  belongs_to :service
  has_many :tasks, dependent: :nullify
  has_many :users, -> { distinct }, through: :tasks, source: :assignee
  
  # Serialization
  serialize :schedule, coder: JSON
  
  # Enums
  enum :status, {
    planning: 0,
    active: 1,
    completed: 2,
    cancelled: 3
  }, default: :planning
  
  # Validations
  validates :name, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start_date
  
  # Scopes
  scope :current, -> { active.where('start_date <= ? AND end_date >= ?', Date.current, Date.current) }
  scope :upcoming, -> { planning.where('start_date > ?', Date.current).order(:start_date) }
  scope :past, -> { completed }
  scope :ordered, -> { order(:start_date) }
  
  # Callbacks
  before_validation :set_defaults, on: :create
  
  # Ice Cube를 사용한 반복 스프린트 설정
  def initialize_schedule(duration_weeks = 2)
    schedule_obj = IceCube::Schedule.new(start_date) do |s|
      s.add_recurrence_rule(
        IceCube::Rule.weekly(duration_weeks).day(:monday)
      )
    end
    self.schedule = schedule_obj.to_hash
  end
  
  # 다음 스프린트 날짜들
  def upcoming_sprints(count = 5)
    return [] unless schedule
    
    schedule_obj = IceCube::Schedule.from_hash(schedule)
    schedule_obj.next_occurrences(count, Time.current)
  end
  
  # 현재 스프린트인지 확인
  def current?
    start_date <= Date.current && end_date >= Date.current
  end
  
  # 과거 스프린트인지 확인
  def past?
    end_date < Date.current
  end
  
  # 미래 스프린트인지 확인
  def upcoming?
    start_date > Date.current
  end
  
  # 유연한 업무 시간을 고려한 실제 작업 가능 시간
  def available_working_hours
    return 0 if upcoming?
    
    from_datetime = sprint_datetime(start_date, start_time)
    to_datetime = past? ? sprint_datetime(end_date, end_time) : Time.current
    
    if flexible_hours
      # 유연 근무제: 24시간 기준 (점심시간 제외)
      calculate_flexible_hours(from_datetime, to_datetime)
    else
      # 일반 업무 시간 기준
      WorkingHours.working_time_between(from_datetime, to_datetime) / 1.hour.to_f
    end
  end
  
  # 스프린트 시작 시간 (날짜 + 시간)
  def sprint_start_datetime
    sprint_datetime(start_date, start_time)
  end
  
  # 스프린트 종료 시간 (날짜 + 시간)
  def sprint_end_datetime
    sprint_datetime(end_date, end_time)
  end
  
  # 일일 스탠드업 시간
  def next_standup_time
    return nil unless daily_standup_time
    
    today = Date.current
    standup = today.to_time.change(
      hour: daily_standup_time.hour,
      min: daily_standup_time.min
    )
    
    # 이미 지났으면 다음 업무일
    if standup < Time.current
      next_workday = 1.business_day.from_now
      standup = next_workday.change(
        hour: daily_standup_time.hour,
        min: daily_standup_time.min
      )
    end
    
    standup
  end
  
  # 유연한 근무시간 설정
  def configure_flexible_hours(options = {})
    self.flexible_hours = true
    self.start_time = options[:start_time] || "07:00"  # 이른 출근 가능
    self.end_time = options[:end_time] || "22:00"      # 늦은 퇴근 가능
    self.weekend_work = options[:weekend_work] || false
    save
  end
  
  # Groupdate를 사용한 고급 번다운 차트 데이터
  def burndown_chart_data
    # 일별 완료 스토리 포인트
    daily_completed = tasks
      .group_by_day(:completed_at, range: start_date..end_date, format: "%Y-%m-%d")
      .sum(:story_points)
    
    # 누적 번다운 계산
    remaining_points = planned_points
    burndown = {}
    
    (start_date..end_date).each do |date|
      date_str = date.strftime("%Y-%m-%d")
      completed_today = daily_completed[date_str] || 0
      remaining_points -= completed_today
      burndown[date] = {
        remaining: remaining_points,
        completed: completed_today,
        ideal: ideal_burndown_for_date(date)
      }
    end
    
    burndown
  end
  
  # Groupdate를 사용한 팀원별 기여도
  def team_contribution_data
    tasks
      .joins(:assignee)
      .group_by_day(:completed_at, range: start_date..end_date)
      .group(:assignee)
      .count
  end
  
  # Groupdate를 사용한 일별 진행률
  def daily_progress_data
    tasks
      .group_by_day(:completed_at, range: start_date..end_date)
      .group(:status)
      .count
  end
  
  # 스프린트 일정 조정
  def adjust_schedule(new_start_date: nil, new_end_date: nil, new_start_time: nil, new_end_time: nil)
    transaction do
      self.start_date = new_start_date if new_start_date
      self.end_date = new_end_date if new_end_date
      self.start_time = new_start_time if new_start_time
      self.end_time = new_end_time if new_end_time
      
      # Ice Cube 스케줄도 업데이트
      if schedule && (new_start_date || new_start_time)
        initialize_schedule(duration_in_weeks)
      end
      
      save!
    end
  end
  
  # 스프린트 기간 (주 단위)
  def duration_in_weeks
    return 2 unless start_date && end_date
    ((end_date - start_date).to_i / 7.0).ceil
  end
  
  # 실제 일일 작업 시간 계산
  def daily_working_hours
    return 8 unless start_time && end_time
    
    start_hour = start_time.hour + (start_time.min / 60.0)
    end_hour = end_time.hour + (end_time.min / 60.0)
    
    # 점심시간 1시간 제외
    hours = end_hour - start_hour
    hours > 5 ? hours - 1 : hours
  end
  
  # 스프린트별 커스텀 업무 시간 설정
  def set_custom_working_hours(daily_hours: {})
    # 예: { monday: { start: "10:00", end: "19:00" }, friday: { start: "09:00", end: "15:00" } }
    self.custom_schedule = daily_hours
    save
  end
  
  private
  
  def sprint_datetime(date, time)
    return date.to_time unless time
    
    date.to_time.change(
      hour: time.hour,
      min: time.min
    )
  end
  
  def calculate_flexible_hours(from_datetime, to_datetime)
    total_hours = 0
    current = from_datetime
    
    while current < to_datetime
      # 주말 포함 여부 확인
      if weekend_work || current.on_weekday?
        # 하루 최대 작업 시간 계산
        day_start = current.change(hour: start_time&.hour || 7, min: start_time&.min || 0)
        day_end = current.change(hour: end_time&.hour || 22, min: end_time&.min || 0)
        
        work_start = [current, day_start].max
        work_end = [to_datetime, day_end].min
        
        if work_end > work_start
          day_hours = (work_end - work_start) / 1.hour
          # 6시간 이상 근무 시 점심시간 1시간 제외
          day_hours -= 1 if day_hours > 6
          total_hours += day_hours
        end
      end
      
      current = (current + 1.day).beginning_of_day
    end
    
    total_hours
  end
  
  def ideal_burndown_for_date(date)
    days_total = (end_date - start_date).to_i + 1
    days_passed = (date - start_date).to_i
    planned_points - (planned_points.to_f / days_total * days_passed)
  end
  
  # 팀 벨로시티 계산
  def calculate_velocity
    tasks.completed.sum(:story_points) || 0
  end
  
  def velocity
    calculate_velocity
  end
  
  # 계획된 스토리 포인트
  def planned_points
    tasks.sum(:story_points) || 0
  end
  
  # 완료율
  def completion_percentage
    return 0 if tasks.count == 0
    
    completed_count = tasks.completed.count
    total_count = tasks.count
    
    (completed_count.to_f / total_count * 100).round(1)
  end
  
  # 스토리 포인트 기준 완료율
  def points_completion_percentage
    return 0 if planned_points == 0
    
    (velocity.to_f / planned_points * 100).round(1)
  end
  
  # 스프린트 기간 (일 단위)
  def duration_in_days
    return 0 unless start_date && end_date
    (end_date - start_date).to_i
  end
  
  # 스프린트 진행률
  def progress_percentage
    return 100 if past?
    return 0 if upcoming?
    
    elapsed_days = (Date.current - start_date).to_i
    total_days = duration_in_days
    return 100 if total_days == 0
    
    [(elapsed_days.to_f / total_days * 100).round, 100].min
  end
  
  # 번다운 데이터 생성
  def burndown_data
    data = []
    total_points = planned_points
    ideal_daily_burn = total_points.to_f / (duration_in_days + 1)
    
    (start_date..end_date).each_with_index do |date, index|
      ideal_remaining = total_points - (ideal_daily_burn * index)
      
      actual_remaining = if date <= Date.current
        total_points - tasks.where('completed_at <= ?', date.end_of_day).sum(:story_points)
      else
        nil
      end
      
      data << {
        date: date,
        ideal: ideal_remaining.round(1),
        actual: actual_remaining
      }
    end
    
    data
  end
  
  # 스프린트 활성화 가능 여부
  def can_activate?
    planning? && start_date <= Date.current && end_date >= Date.current
  end
  
  # 스프린트 활성화
  def activate!
    return false unless can_activate?
    active!
  end
  
  # 스프린트 완료
  def complete!
    transaction do
      self.status = :completed
      save!
    end
  end
  
  # 남은 작업일
  def business_days_remaining
    return 0 if past?
    return business_days_total if upcoming?
    
    Date.current.business_days_until(end_date)
  end
  
  # 전체 작업일
  def business_days_total
    start_date.business_days_until(end_date)
  end
  
  # 진행률 (시간 기준)
  def time_progress_percentage
    return 100 if past?
    return 0 if upcoming?
    
    elapsed_days = (Date.current - start_date).to_i + 1
    total_days = (end_date - start_date).to_i + 1
    
    (elapsed_days.to_f / total_days * 100).round(1)
  end
  
  # 팀 용량 계산 (팀원 수 * 업무일 * 일일 업무시간)
  def team_capacity
    team_size = tasks.distinct.count(:assignee_id)
    return 0 if team_size == 0
    
    business_days_total * 9 * team_size # 하루 9시간 기준
  end
  
  # 일일 평균 벨로시티
  def daily_velocity
    elapsed_days = business_days_total - business_days_remaining
    return 0 if elapsed_days <= 0
    
    velocity.to_f / elapsed_days
  end
  
  # 예상 완료 벨로시티
  def projected_velocity
    return velocity if past?
    
    daily_velocity * business_days_total
  end
  
  # 번다운 데이터 (남은 스토리 포인트)
  def burndown_remaining_points
    data = {}
    remaining_points = planned_points
    
    (start_date..end_date).each do |date|
      completed_on_day = tasks.where(completed_at: date.beginning_of_day..date.end_of_day)
                              .sum(:story_points)
      remaining_points -= completed_on_day
      data[date] = remaining_points
    end
    
    data
  end
  
  # 이상적인 번다운 라인
  def ideal_burndown_line
    data = {}
    daily_burn = planned_points.to_f / business_days_total
    remaining = planned_points.to_f
    
    (start_date..end_date).each do |date|
      data[date] = remaining.round(1)
      remaining -= daily_burn if date.on_weekday?
    end
    
    data
  end
  
  # 상태
  def sprint_status
    if past?
      'completed'
    elsif current?
      'active'
    else
      'planned'
    end
  end
  
  private
  
  def end_date_after_start_date
    return unless start_date && end_date
    
    if end_date <= start_date
      errors.add(:end_date, 'must be after start date')
    end
  end
  
  def set_defaults
    self.status ||= 'planned'
    
    # 기본 2주 스프린트 설정
    if start_date && !end_date
      self.end_date = start_date + 13.days # 2주
    end
  end
end