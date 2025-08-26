class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :trackable,
         :omniauthable, omniauth_providers: [:google_oauth2, :github]
         
  # Validations
  validates :username, uniqueness: { case_sensitive: false }, length: { minimum: 3, maximum: 30 }, format: { with: /\A[a-zA-Z0-9_-]+\z/ }, allow_nil: true, allow_blank: true
  validates :role, inclusion: { in: %w[user admin moderator] }
  
  # Multi-tenant associations
  has_many :organization_memberships, dependent: :destroy
  has_many :organizations, through: :organization_memberships
  
  # Role helper methods
  def admin?
    role == 'admin'
  end
  
  def moderator?
    role == 'moderator'
  end
  
  def regular_user?
    role == 'user'
  end
  
  # Organization-specific role methods
  def find_organization(subdomain)
    organizations.find_by(subdomain: subdomain)
  end
  
  def current_organization
    ActsAsTenant.current_tenant
  end
  
  def member_of?(organization)
    organization_memberships.active.exists?(organization: organization)
  end
  
  def role_in(organization)
    organization_memberships.find_by(organization: organization, active: true)&.role
  end
  
  def owner_of?(organization)
    role_in(organization) == 'owner'
  end
  
  def admin_of?(organization)
    role_in(organization).in?(%w[owner admin])
  end
  
  def can_access?(organization)
    member_of?(organization) && organization.active?
  end
  
  def owned_organizations
    organizations.joins(:organization_memberships)
                 .where(organization_memberships: { user: self, role: 'owner', active: true })
  end
  
  def administered_organizations
    organizations.joins(:organization_memberships)
                 .where(organization_memberships: { user: self, role: %w[owner admin], active: true })
  end
         
  def self.from_omniauth(access_token)
    data = access_token.info
    user = User.where(email: data['email']).first

    unless user
      user = User.create(
        name: data['name'],
        email: data['email'],
        password: Devise.friendly_token[0, 20],
        provider: access_token.provider,
        uid: access_token.uid
      )
    end
    user
  end
end
