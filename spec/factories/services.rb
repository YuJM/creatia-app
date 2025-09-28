FactoryBot.define do
  factory :service do
    association :organization
    sequence(:name) { |n| "Service #{n}" }
    sequence(:key) { |n| "SVC#{n.to_s.rjust(3, '0')}" } # SVC001, SVC002, etc.
    description { "Service description for #{name}" }
  end
end
