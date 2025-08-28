class Service < ApplicationRecord
  # Multi-tenancy
  acts_as_tenant :organization
  
  # Associations
  belongs_to :organization
  has_many :sprints, dependent: :destroy
  has_many :tasks, dependent: :destroy
  
  # Validations
  validates :name, presence: true, uniqueness: { scope: :organization_id }
  validates :key, presence: true, 
                  uniqueness: { scope: :organization_id },
                  format: { with: /\A[A-Z0-9]+\z/, message: "must contain only uppercase letters and numbers" }
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }
  
  # Callbacks
  before_validation :generate_key, on: :create
  
  private
  
  def generate_key
    return if key.present?
    
    # Generate key from name (e.g., "Shopping Cart" => "SHOP")
    self.key = name.upcase.gsub(/[^A-Z0-9]/, '').first(4) if name.present?
    
    # Ensure uniqueness
    if self.class.where(organization: organization, key: key).exists?
      suffix = 1
      while self.class.where(organization: organization, key: "#{key}#{suffix}").exists?
        suffix += 1
      end
      self.key = "#{key}#{suffix}"
    end
  end
end
