FactoryBot.define do
  factory :team do
    association :organization
    sequence(:name) { |n| "Team #{n}" }
    description { "Description for #{name}" }
    lead_id { nil }
    
    trait :with_lead do
      association :lead_id, factory: :user
    end
  end
end
