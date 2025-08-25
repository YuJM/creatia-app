FactoryBot.define do
  factory :organization_membership do
    association :user
    association :organization
    role { 'member' }
    active { true }
    
    trait :owner do
      role { 'owner' }
    end
    
    trait :admin do
      role { 'admin' }
    end
    
    trait :viewer do
      role { 'viewer' }
    end
    
    trait :inactive do
      active { false }
    end
  end
end
