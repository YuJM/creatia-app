class Team < ApplicationRecord
  # Multi-tenancy
  acts_as_tenant :organization
  
  # Associations
  belongs_to :organization
  has_many :tasks, dependent: :nullify
  has_many :team_members, dependent: :destroy
  has_many :users, through: :team_members
  has_many :sprints, through: :tasks
  
  # Validations
  validates :name, presence: true, uniqueness: { scope: :organization_id }
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }
  
  # Instance methods
  def member_count
    users.count
  end
  
  def current_sprint
    sprints.current.first
  end
  
  def velocity
    sprints.past.average(:velocity) || 0
  end
end
