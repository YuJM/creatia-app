FactoryBot.define do
  factory :permission_delegation do
    association :organization
    association :delegator, factory: :user
    association :delegatee, factory: :user
    association :role
    permissions { [] }
    starts_at { 1.day.ago }
    ends_at { 30.days.from_now }
    reason { "Temporary delegation for vacation coverage" }
  end
end