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
  
  # GitHub 통합 관련 메서드들 (옵셔널)
  def github_integration_active?
    # 기본적으로 비활성화
    # 추후 settings 테이블이나 GitHub 설정이 구현되면 여기서 확인
    false
  end
  
  def github_repository
    # 기본값 nil 반환
    # 추후 GitHub 저장소 설정이 구현되면 여기서 반환
    nil
  end
  
  def github_access_token
    # 기본값 nil 반환
    # 추후 암호화된 토큰 저장이 구현되면 여기서 반환
    nil
  end
  
  def current_service
    # 임시로 self를 반환 (Phase 2 CreateTaskWithBranchService에서 service 파라미터 요구)
    # 추후 Service 모델이 구현되면 해당 서비스를 반환
    self
  end
  
  def active_members
    # 활성 멤버들의 User 객체 반환
    users.joins(:organization_memberships)
         .where(organization_memberships: { organization: self, active: true })
  end
end
