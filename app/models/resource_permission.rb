class ResourcePermission < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :organization
  belongs_to :permission
  belongs_to :resource, polymorphic: true
  
  # Validations
  validates :resource_type, presence: true
  validates :resource_id, presence: true
  validates :user_id, uniqueness: { 
    scope: [:organization_id, :resource_type, :resource_id, :permission_id] 
  }
  
  # Scopes
  scope :active, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }
  scope :granted, -> { where(granted: true) }
  scope :denied, -> { where(granted: false) }
  scope :for_resource, ->(resource) { where(resource: resource) }
  scope :for_user, ->(user) { where(user: user) }
  
  # Callbacks
  before_create :set_default_expiration
  
  # Instance methods
  def active?
    expires_at.nil? || expires_at > Time.current
  end
  
  def expired?
    expires_at.present? && expires_at <= Time.current
  end
  
  def permanent?
    expires_at.nil?
  end
  
  def temporary?
    expires_at.present?
  end
  
  def days_until_expiration
    return nil if permanent?
    return 0 if expired?
    
    ((expires_at - Time.current) / 1.day).ceil
  end
  
  def revoke!
    update!(granted: false, expires_at: Time.current)
  end
  
  def extend_expiration(duration)
    return false if permanent?
    
    new_expiration = expires_at + duration
    update(expires_at: new_expiration)
  end
  
  def make_permanent!
    update(expires_at: nil)
  end
  
  private
  
  def set_default_expiration
    # 기본적으로 30일 후 만료 (nil이면 영구)
    self.expires_at ||= 30.days.from_now if ENV['DEFAULT_PERMISSION_DURATION'].present?
  end
end