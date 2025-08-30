class PermissionDelegation < ApplicationRecord
  # Associations
  belongs_to :delegator, class_name: 'User'
  belongs_to :delegatee, class_name: 'User'
  belongs_to :organization
  belongs_to :role, optional: true
  
  # Validations
  validates :starts_at, presence: true
  validates :expires_at, presence: true
  validate :expires_after_starts
  validate :cannot_delegate_to_self
  validate :delegator_has_permissions
  
  # Scopes
  scope :active, -> { 
    where(active: true)
      .where('starts_at <= ?', Time.current)
      .where('expires_at > ?', Time.current) 
  }
  scope :upcoming, -> { where('starts_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }
  scope :for_delegator, ->(user) { where(delegator: user) }
  scope :for_delegatee, ->(user) { where(delegatee: user) }
  
  # Callbacks
  after_create :notify_delegatee
  before_destroy :notify_revocation
  
  # Instance methods
  def active?
    active && starts_at <= Time.current && expires_at > Time.current
  end
  
  def upcoming?
    starts_at > Time.current
  end
  
  def expired?
    expires_at <= Time.current
  end
  
  def days_remaining
    return 0 if expired?
    ((expires_at - Time.current) / 1.day).ceil
  end
  
  def revoke!
    update!(active: false, expires_at: Time.current)
  end
  
  def extend_duration(duration)
    update(expires_at: expires_at + duration)
  end
  
  def delegated_permissions
    if role.present?
      role.permissions
    elsif permissions.present?
      Permission.where(id: permissions)
    else
      Permission.none
    end
  end
  
  def has_permission?(resource, action)
    if role.present?
      role.has_permission?(resource, action)
    else
      permission = Permission.find_by(resource: resource, action: action)
      permission && permissions.include?(permission.id.to_s)
    end
  end
  
  private
  
  def expires_after_starts
    return unless starts_at && expires_at
    
    if expires_at <= starts_at
      errors.add(:expires_at, '종료 시간은 시작 시간 이후여야 합니다')
    end
  end
  
  def cannot_delegate_to_self
    if delegator_id == delegatee_id
      errors.add(:delegatee, '자기 자신에게는 권한을 위임할 수 없습니다')
    end
  end
  
  def delegator_has_permissions
    return unless delegator && organization
    
    membership = delegator.organization_memberships.find_by(organization: organization)
    unless membership
      errors.add(:delegator, '위임자가 해당 조직의 멤버가 아닙니다')
      return
    end
    
    # 역할 위임의 경우, 위임자가 해당 역할보다 높은 권한을 가져야 함
    if role.present? && membership.role
      if membership.role.priority < role.priority
        errors.add(:role, '자신보다 높은 권한의 역할은 위임할 수 없습니다')
      end
    end
  end
  
  def notify_delegatee
    # TODO: 권한 위임 알림 구현
    # NotificationService.notify_permission_delegation(self)
  end
  
  def notify_revocation
    # TODO: 권한 회수 알림 구현
    # NotificationService.notify_delegation_revoked(self)
  end
end