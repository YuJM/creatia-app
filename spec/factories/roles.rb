FactoryBot.define do
  factory :role do
    association :organization
    sequence(:name) { |n| "Role #{n}" }
    sequence(:key) { |n| "role_#{n}" }
    description { "A test role" }
    system_role { false }
    editable { true }
    priority { 50 }
  end
end