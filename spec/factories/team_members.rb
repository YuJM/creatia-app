FactoryBot.define do
  factory :team_member do
    association :team
    association :user
    role { 'member' }
    
    trait :leader do
      role { 'leader' }
    end
    
    trait :member do
      role { 'member' }
    end
  end
end
