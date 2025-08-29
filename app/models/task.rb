class Task < ApplicationRecord
  # Multi-tenancy
  acts_as_tenant :organization
  
  # Concerns
  include TimeTrackable
  include TrackableHistory
  
  # Associations
  belongs_to :organization
  belongs_to :assigned_user, polymorphic: true, optional: true
  belongs_to :sprint, optional: true
  belongs_to :team, optional: true
  belongs_to :service, optional: true
  belongs_to :assignee, class_name: 'User', optional: true
  has_many :pomodoro_sessions, dependent: :destroy
  
  # Constants
  STATUSES = %w[todo in_progress review done archived].freeze
  PRIORITIES = %w[low medium high urgent].freeze
  
  # Validations
  validates :title, presence: true, length: { minimum: 1, maximum: 200 }
  validates :status, inclusion: { in: STATUSES }
  validates :priority, inclusion: { in: PRIORITIES }
  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :organization, presence: true
  
  # Scopes
  scope :by_status, ->(status) { where(status: status) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :assigned_to, ->(user) { where(assigned_user: user) }
  scope :unassigned, -> { where(assigned_user: nil) }
  scope :due_today, -> { where(due_date: Date.current.beginning_of_day..Date.current.end_of_day) }
  scope :ordered, -> { order(:position, :created_at) }
  
  # Status scopes
  scope :todo, -> { by_status('todo') }
  scope :in_progress, -> { by_status('in_progress') }
  scope :review, -> { by_status('review') }
  scope :done, -> { by_status('done') }
  scope :archived, -> { by_status('archived') }
  
  # Priority scopes
  scope :low_priority, -> { by_priority('low') }
  scope :medium_priority, -> { by_priority('medium') }
  scope :high_priority, -> { by_priority('high') }
  scope :urgent, -> { by_priority('urgent') }
  
  # Additional scopes for UI integration
  scope :active, -> { where(status: %w[todo in_progress review]) }
  scope :completed, -> { where(status: %w[done]) }
  scope :blocked, -> { where(status: %w[blocked]) } # 추후 blocked 상태 추가 시 사용
  scope :overdue, -> { where('due_date < ?', Date.current).where.not(status: %w[done archived]) }
  scope :due_soon, -> { where(due_date: Date.current..7.days.from_now).where.not(status: %w[done archived]) }
  
  # Callbacks
  before_validation :set_default_values, on: :create
  
  # Groupdate를 사용한 고급 시계열 분석
  
  # 일별 완료 태스크 수
  def self.daily_completion_data(range = 30.days.ago..Date.current)
    done.group_by_day(:updated_at, range: range).count
  end
  
  # 주별 태스크 생성 추세
  def self.weekly_creation_trend(range = 12.weeks.ago..Date.current)
    group_by_week(:created_at, range: range, week_start: :monday).count
  end
  
  # 시간별 생산성 분석 (하루 중 어느 시간대에 가장 많이 완료되는지)
  def self.hourly_productivity_analysis
    done.group_by_hour_of_day(:updated_at, format: "%l %P", time_zone: "Asia/Seoul").count
  end
  
  # 요일별 완료 패턴
  def self.weekday_completion_pattern
    done.group_by_day_of_week(:updated_at, format: "%a").count
  end
  
  # 우선순위별 평균 처리 시간
  def self.priority_average_completion_time
    done
      .where.not(started_at: nil, completed_at: nil)
      .group(:priority)
      .average("EXTRACT(EPOCH FROM (completed_at - started_at))/3600")
      .transform_values { |v| v.to_f.round(1) }
  end
  
  # 담당자별 월간 생산성
  def self.assignee_monthly_productivity(month = Date.current.beginning_of_month)
    joins(:assignee)
      .where(updated_at: month..month.end_of_month)
      .where(status: 'done')
      .group("users.name")
      .count
  end
  
  # 스프린트별 완료 추세
  def self.sprint_completion_trend
    joins(:sprint)
      .group_by_week("sprints.end_date", last: 12)
      .group(:status)
      .count
  end
  
  # 상태별 체류 시간 분석
  def self.status_duration_analysis
    select("status, AVG(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - updated_at))/3600) as avg_hours")
      .group(:status)
      .map { |t| [t.status, t.avg_hours.to_f.round(1)] }
      .to_h
  end
  
  # SLA 준수율 (기한 내 완료된 태스크 비율)
  def self.sla_compliance_rate(range = 30.days.ago..Date.current)
    total = where(deadline: range).count
    on_time = where(deadline: range)
              .where("(status = 'done' AND completed_at <= deadline) OR (status != 'done' AND deadline > ?)", Time.current)
              .count
    
    return 0 if total == 0
    (on_time.to_f / total * 100).round(1)
  end
  
  # Business Time을 활용한 실제 업무시간 계산
  def actual_business_hours
    return nil unless started_at && completed_at
    
    # Business Time gem을 사용하여 실제 업무 시간만 계산
    business_hours_between(started_at, completed_at, exclude_lunch: true)
  end
  
  # 예상 vs 실제 시간 차이 분석
  def time_variance
    return nil unless estimated_hours && actual_hours
    
    variance = actual_hours - estimated_hours
    percentage = (variance / estimated_hours * 100).round(1)
    
    {
      variance_hours: variance.round(1),
      variance_percentage: percentage,
      accuracy_level: case percentage.abs
                      when 0..10 then :excellent
                      when 11..25 then :good
                      when 26..50 then :fair
                      else :poor
                      end
    }
  end
  
  # Instance methods
  def assigned?
    assigned_user.present?
  end
  
  # Task ID generation
  def task_id
    return nil unless service&.task_prefix && id
    "#{service.task_prefix}-#{id}"
  end
  
  # TaskStatus struct integration
  def status_struct
    @status_struct ||= TaskStatus.new(
      state: status,
      blocked_by: blocked_by_task_ids,
      blocking: blocking_task_ids,
      assigned_to: assignee&.email,
      started_at: started_at,
      completed_at: completed_at
    )
  end
  
  def transition_to!(new_state)
    if status_struct.can_transition_to?(new_state)
      update!(status: new_state)
      true
    else
      errors.add(:status, "#{status}에서 #{new_state}로 전환할 수 없습니다")
      false
    end
  end
  
  def blocked_by_task_ids
    # 나중에 구현: 의존성 관계에서 blocking tasks를 가져옴
    []
  end
  
  def blocking_task_ids
    # 나중에 구현: 의존성 관계에서 blocked tasks를 가져옴
    []
  end
  
  def priority_color
    case priority
    when 'low' then 'green'
    when 'medium' then 'yellow'
    when 'high' then 'orange'
    when 'urgent' then 'red'
    else 'gray'
    end
  end
  
  def status_display_name
    case status
    when 'todo' then '할 일'
    when 'in_progress' then '진행 중'
    when 'review' then '검토 중'
    when 'done' then '완료'
    when 'archived' then '보관됨'
    else status.humanize
    end
  end
  
  def priority_display_name
    case priority
    when 'low' then '낮음'
    when 'medium' then '보통'
    when 'high' then '높음'
    when 'urgent' then '긴급'
    else priority.humanize
    end
  end
  
  # GitHub 브랜치 정보 (추후 마이그레이션으로 추가 예정)
  def github_branch
    # 임시로 nil 반환, 추후 DB 컬럼 추가 시 해당 컬럼 값 반환
    nil
  end
  
  def github_branch=(value)
    # 임시로 무시, 추후 DB 컬럼 추가 시 해당 컬럼에 저장
  end
  
  # 복잡도 점수 (추후 마이그레이션으로 추가 예정)
  def complexity_score
    # 기본값으로 우선순위 기반 복잡도 반환
    case priority
    when 'low' then 2
    when 'medium' then 4
    when 'high' then 6
    when 'urgent' then 8
    else 3
    end
  end
  
  # 다음 위치 값 계산
  def self.next_position(organization, status = nil)
    scope = where(organization: organization)
    scope = scope.by_status(status) if status
    (scope.maximum(:position) || 0) + 1
  end
  
  private
  
  def set_default_values
    self.status ||= 'todo'
    self.priority ||= 'medium'
    self.position ||= self.class.next_position(organization, status)
  end
end
