module TimeTrackable
  extend ActiveSupport::Concern
  
  included do
    # 시간 추적 필드
    # started_at: datetime
    # completed_at: datetime
    # estimated_hours: decimal
    # actual_hours: decimal
    # deadline: datetime
    
    # Validations
    validate :deadline_must_be_future, on: :create, if: -> { deadline? && deadline_changed? }
    validate :completed_at_must_be_after_started_at
    
    # Scopes
    scope :overdue, -> { where("deadline < ? AND completed_at IS NULL", Time.current) }
    scope :due_soon, -> { where(deadline: Time.current..24.hours.from_now).where(completed_at: nil) }
    scope :completed, -> { where.not(completed_at: nil) }
    scope :in_progress, -> { where.not(started_at: nil).where(completed_at: nil) }
    scope :upcoming, -> { where(deadline: Time.current..7.days.from_now).where(completed_at: nil) }
    scope :without_deadline, -> { where(deadline: nil) }
    scope :by_urgency, -> {
      select("*, 
        CASE 
          WHEN deadline IS NULL THEN 4
          WHEN deadline < NOW() THEN 0
          WHEN deadline < NOW() + INTERVAL '2 hours' THEN 0
          WHEN deadline < NOW() + INTERVAL '24 hours' THEN 1
          WHEN deadline < NOW() + INTERVAL '3 days' THEN 2
          ELSE 3
        END AS urgency_score")
      .order('urgency_score ASC, deadline ASC')
    }
    
    # Callbacks
    before_save :calculate_actual_hours, if: :will_save_change_to_completed_at?
  end
  
  # 자연어로 마감일 설정 (한국어 지원)
  def set_deadline_from_natural_language(text)
    return if text.blank?
    
    # 먼저 한국어 파서 시도
    parsed_time = ChronicKorean.parse(text)
    
    # 실패하면 기본 Chronic 파서 사용
    parsed_time ||= Chronic.parse(text)
    
    if parsed_time
      self.deadline = parsed_time
    else
      errors.add(:deadline, "시간을 파싱할 수 없습니다: #{text}")
    end
  end
  
  # 자연어 예시 제공
  def natural_language_examples
    [
      "내일 오후 3시",
      "다음주 월요일",
      "3일 후",
      "2시간 후",
      "다음달 15일",
      "오늘 저녁 6시",
      "tomorrow at 3pm",
      "next friday",
      "in 2 hours"
    ]
  end
  
  # 업무 시간 기준 마감일 계산
  def calculate_business_deadline(hours_from_now)
    self.deadline = hours_from_now.business_hours.from_now
  end
  
  # 업무 시간 기준 마감일까지 남은 시간
  def business_hours_until_deadline
    return nil unless deadline
    return 0 if deadline < Time.current
    
    WorkingHours.working_time_between(Time.current, deadline) / 1.hour.to_f
  end
  
  # 마감일 초과 여부
  def is_overdue?
    deadline.present? && deadline < Time.current && completed_at.nil?
  end
  
  # 실제 소요 시간 계산 (업무 시간 기준)
  def calculate_actual_business_hours
    return nil unless started_at && completed_at
    
    # Working Hours gem을 사용한 업무 시간만 계산
    WorkingHours.working_time_between(started_at, completed_at) / 1.hour.to_f
  end
  
  # 남은 업무일 계산
  def business_days_remaining
    return nil unless deadline
    
    if deadline > Time.current
      # Business Time gem을 사용한 업무일 계산
      Date.current.business_days_until(deadline.to_date)
    else
      0
    end
  end
  
  # 진행률 계산
  def progress_percentage
    return 0 unless estimated_hours && estimated_hours > 0
    return 100 if completed_at
    
    if started_at && actual_hours
      [(actual_hours / estimated_hours * 100).round, 100].min
    else
      0
    end
  end
  
  # 상태 확인 메서드
  def overdue?
    deadline && deadline < Time.current && !completed_at
  end
  
  def due_soon?
    deadline && deadline.between?(Time.current, 24.hours.from_now) && !completed_at
  end
  
  def in_progress?
    started_at && !completed_at
  end
  
  def completed?
    completed_at.present?
  end
  
  def not_started?
    started_at.nil?
  end
  
  # 시작 시간 기록
  def start_tracking!
    return false if started_at
    
    update(started_at: Time.current)
  end
  
  # 완료 시간 기록
  def complete_tracking!
    return false if completed_at
    return false unless started_at
    
    self.completed_at = Time.current
    self.actual_hours = calculate_actual_business_hours
    save
  end
  
  # 일시 정지 (선택적 기능)
  def pause_tracking!
    return false unless in_progress?
    
    # 일시정지 로직 구현 (필요시)
    true
  end
  
  # 재개 (선택적 기능)
  def resume_tracking!
    return false if completed?
    
    # 재개 로직 구현 (필요시)
    true
  end
  
  # 마감일까지 남은 시간 (human-friendly)
  def time_until_deadline
    return nil unless deadline
    
    time_diff = deadline - Time.current
    
    if time_diff < 0
      "마감일이 #{distance_of_time_in_words(Time.current, deadline)} 지연되었습니다"
    else
      "#{distance_of_time_in_words(Time.current, deadline)} 후"
    end
  end
  
  # 마감일 포맷팅
  def format_deadline(format = :default)
    return "—" unless deadline
    
    # Local Time gem을 활용하여 사용자 시간대에 맞게 자동 변환
    case format
    when :short
      deadline.in_time_zone.strftime("%m/%d %H:%M")
    when :long
      I18n.l(deadline.in_time_zone, format: :long) rescue deadline.in_time_zone.strftime("%Y년 %m월 %d일 %H:%M")
    when :date_only
      deadline.in_time_zone.strftime("%Y-%m-%d")
    when :time_only
      deadline.in_time_zone.strftime("%H:%M")
    when :relative
      time_until_deadline
    else
      deadline.in_time_zone.strftime("%Y-%m-%d %H:%M")
    end
  end
  
  # 긴급도 레벨
  def urgency_level
    return :low unless deadline
    
    time_remaining = deadline - Time.current
    
    if time_remaining < 0
      :critical  # 지연됨
    elsif time_remaining < 2.hours
      :critical  # 2시간 이내
    elsif time_remaining < 24.hours
      :high      # 24시간 이내
    elsif time_remaining < 3.days
      :medium    # 3일 이내
    else
      :low       # 3일 초과
    end
  end
  
  # 긴급도에 따른 CSS 클래스
  def urgency_class
    case urgency_level
    when :critical
      "text-red-500"
    when :high
      "text-orange-500"
    when :medium
      "text-yellow-500"
    when :low
      "text-green-500"
    else
      "text-gray-500"
    end
  end
  
  private
  
  def deadline_must_be_future
    return unless deadline
    
    if deadline <= Time.current
      errors.add(:deadline, "마감일은 현재 시간 이후여야 합니다")
    end
  end
  
  def completed_at_must_be_after_started_at
    return unless started_at && completed_at
    
    if completed_at < started_at
      errors.add(:completed_at, "완료 시간은 시작 시간 이후여야 합니다")
    end
  end
  
  def calculate_actual_hours
    return unless started_at && completed_at
    
    # WorkingHours를 사용하여 실제 업무 시간만 계산
    working_seconds = WorkingHours.working_time_between(started_at, completed_at)
    self.actual_hours = working_seconds / 1.hour.to_f
  end
  
  def distance_of_time_in_words(from_time, to_time, options = {})
    from_time = from_time.to_time if from_time.respond_to?(:to_time)
    to_time = to_time.to_time if to_time.respond_to?(:to_time)
    from_time, to_time = to_time, from_time if from_time > to_time
    distance_in_minutes = ((to_time - from_time) / 60.0).round
    distance_in_seconds = (to_time - from_time).round

    case distance_in_minutes
    when 0..1
      return distance_in_minutes == 0 ? "지금" : "1분"
    when 2...45           then "#{distance_in_minutes}분"
    when 45...90          then "1시간"
    when 90...1440        then "#{(distance_in_minutes.to_f / 60.0).round}시간"
    when 1440...2520      then "1일"
    when 2520...43200     then "#{(distance_in_minutes.to_f / 1440.0).round}일"
    when 43200...86400    then "1개월"
    when 86400...525600   then "#{(distance_in_minutes.to_f / 43200.0).round}개월"
    else
      from_year = from_time.year
      to_year = to_time.year
      minute_offset_for_leap_year = (to_year > from_year && Date.leap?(to_year)) ? 1440 : 0
      minutes_with_offset = distance_in_minutes - minute_offset_for_leap_year
      remainder = (minutes_with_offset % 525600)
      distance_in_years = (minutes_with_offset.div 525600)
      distance_in_years > 0 ? "#{distance_in_years}년" : "1년 이상"
    end
  end
end