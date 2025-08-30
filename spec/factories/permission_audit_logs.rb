FactoryBot.define do
  factory :permission_audit_log do
    association :user
    association :organization
    action { "read" }
    association :resource, factory: :task
    permitted { true }
    context { {} }
  end
end