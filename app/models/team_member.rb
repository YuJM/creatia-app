class TeamMember < ApplicationRecord
  belongs_to :team
  belongs_to :user
  
  # Constants
  ROLES = %w[leader member].freeze
  
  # Validations
  validates :role, presence: true, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :team_id, message: "is already a member of this team" }
  
  # Scopes
  scope :leaders, -> { where(role: 'leader') }
  scope :members, -> { where(role: 'member') }
end
