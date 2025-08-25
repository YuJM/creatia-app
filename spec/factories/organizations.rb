FactoryBot.define do
  factory :organization do
    sequence(:name) { |n| "Organization #{n}" }
    sequence(:subdomain) { |n| "org-#{n}" }
    description { Faker::Lorem.paragraph }
    plan { 'team' }
    active { true }
    
    trait :with_free_plan do
      plan { 'free' }
    end
    
    trait :with_pro_plan do
      plan { 'pro' }
    end
    
    trait :with_enterprise_plan do
      plan { 'enterprise' }
    end
    
    trait :inactive do
      active { false }
    end
  end
end
