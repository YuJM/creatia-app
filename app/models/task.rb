class Task < ApplicationRecord
  # Multi-tenancy
  acts_as_tenant :organization
  
  # Associations
  belongs_to :organization
  belongs_to :assigned_user, polymorphic: true, optional: true
  
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
  scope :overdue, -> { where('due_date < ? AND status NOT IN (?)', Date.current.beginning_of_day, %w[done archived]) }
  scope :due_today, -> { where(due_date: Date.current.beginning_of_day..Date.current.end_of_day) }
  scope :due_soon, -> { where(due_date: Time.current..3.days.from_now) }
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
  
  # Callbacks
  before_validation :set_default_values, on: :create
  
  # Instance methods
  def assigned?
    assigned_user.present?
  end
  
  def overdue?
    due_date.present? && due_date < Date.current.beginning_of_day && !completed?
  end
  
  def due_soon?
    due_date.present? && due_date.between?(Time.current, 3.days.from_now)
  end
  
  def completed?
    status.in?(%w[done archived])
  end
  
  def in_progress?
    status == 'in_progress'
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
