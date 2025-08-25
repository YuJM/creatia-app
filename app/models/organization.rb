class Organization < ApplicationRecord
  
  # Associations
  has_many :organization_memberships, dependent: :destroy
  has_many :users, through: :organization_memberships
  
  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :subdomain, presence: true, 
                        uniqueness: { case_sensitive: false },
                        length: { minimum: 2, maximum: 63 },
                        format: { 
                          with: /\A[a-z0-9\-]+\z/, 
                          message: "소문자, 숫자, 하이픈만 사용 가능합니다" 
                        }
  validates :plan, inclusion: { in: %w[free team pro enterprise] }
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_plan, ->(plan) { where(plan: plan) }
  
  # Class methods
  def self.find_by_subdomain(subdomain)
    find_by(subdomain: subdomain.downcase)
  end
  
  # Instance methods
  def display_name
    name.presence || subdomain.humanize.downcase.titleize
  end
  
  def owner
    organization_memberships.find_by(role: 'owner')&.user
  end
  
  def admins
    users.joins(:organization_memberships)
         .where(organization_memberships: { role: %w[owner admin] })
  end
  
  def member?(user)
    organization_memberships.exists?(user: user, active: true)
  end
  
  def role_for(user)
    organization_memberships.find_by(user: user, active: true)&.role
  end
end
