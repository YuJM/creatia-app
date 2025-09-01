# app/models/milestone.rb
class Milestone
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # ===== Core References (PostgreSQL UUIDs) =====
  field :organization_id, type: String  # UUID from PostgreSQL
  field :service_id, type: String       # UUID from PostgreSQL
  field :created_by_id, type: String    # UUID from PostgreSQL User
  
  # ===== Milestone Definition =====
  field :title, type: String
  field :description, type: String
  field :status, type: String, default: 'planning' # planning, active, completed, cancelled
  field :milestone_type, type: String, default: 'release' # release, feature, business
  
  # ===== Timeline =====
  field :planned_start, type: Date
  field :planned_end, type: Date
  field :actual_start, type: Date
  field :actual_end, type: Date
  
  # ===== Progress Tracking =====
  field :total_sprints, type: Integer, default: 0
  field :completed_sprints, type: Integer, default: 0
  field :total_tasks, type: Integer, default: 0
  field :completed_tasks, type: Integer, default: 0
  field :progress_percentage, type: Float, default: 0.0
  
  # ===== Objectives & Key Results =====
  field :objectives, type: Array, default: []
  # [{
  #   id: 'obj-1',
  #   title: 'Improve user engagement',
  #   key_results: [
  #     { id: 'kr-1', description: 'DAU 50% 증가', target: 50000, current: 35000, unit: 'users' },
  #     { id: 'kr-2', description: 'Retention 30% 개선', target: 30, current: 22, unit: 'percent' }
  #   ]
  # }]
  
  # ===== Risk & Dependencies =====
  field :risks, type: Array, default: []
  field :dependencies, type: Array, default: []
  field :blockers, type: Array, default: []
  
  # ===== Stakeholders =====
  field :owner_id, type: Integer
  field :stakeholder_ids, type: Array, default: []
  field :team_ids, type: Array, default: []
  
  # ===== Flexible Metadata =====
  field :custom_fields, type: Hash, default: {}
  field :integrations, type: Hash, default: {}
  # {
  #   jira: { project_id: 'PROJ-123', epic_id: 'EPIC-456' },
  #   github: { milestone_id: 789 },
  #   slack: { channel_id: 'C123456' }
  # }
  
  # ===== Indexes =====
  index({ organization_id: 1, status: 1 })
  index({ service_id: 1 })
  index({ planned_end: 1 })
  index({ status: 1, actual_end: 1 })
  index({ actual_end: 1 }, { expire_after_seconds: 63072000 }) # 2년 후 자동 삭제
  
  # ===== Validations =====
  validates :title, presence: true
  validates :organization_id, presence: true
  validates :status, inclusion: { in: %w[planning active completed cancelled] }
  
  # ===== Scopes =====
  scope :active, -> { where(status: 'active') }
  scope :completed, -> { where(status: 'completed') }
  scope :upcoming, -> { where(status: 'planning') }
  scope :at_risk, -> { where(:progress_percentage.lt => 30, :planned_end.lt => 30.days.from_now) }
  
  # ===== Associations with PostgreSQL =====
  def organization
    @organization ||= Organization.find_by(id: organization_id)
  end
  
  def service
    @service ||= Service.find_by(id: service_id)
  end
  
  def owner
    @owner ||= User.find_by(id: owner_id)
  end
  
  def created_by
    @created_by ||= User.find_by(id: created_by_id)
  end
  
  # ===== Instance Methods =====
  def update_progress
    return if total_tasks.zero?
    
    self.progress_percentage = (completed_tasks.to_f / total_tasks * 100).round(2)
    save!
  end
  
  def days_remaining
    return nil unless planned_end
    (planned_end - Date.current).to_i
  end
  
  def is_overdue?
    planned_end && planned_end < Date.current && status != 'completed'
  end
  
  def health_status
    return 'on_track' if progress_percentage >= 70
    return 'at_risk' if progress_percentage >= 40
    'critical'
  end
end