FactoryBot.define do
  factory :role_permission do
    association :role
    association :permission
    conditions { {} }
    scope { {} }
  end
end