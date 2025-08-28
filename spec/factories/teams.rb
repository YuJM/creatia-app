FactoryBot.define do
  factory :team do
    association :organization
    sequence(:name) { |n| "Team #{n}" }
    description { "Description for #{name}" }
  end
end
