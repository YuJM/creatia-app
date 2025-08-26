FactoryBot.define do
  factory :task do
    sequence(:title) { |n| "Task #{n}" }
    description { Faker::Lorem.paragraph }
    status { 'todo' }
    priority { 'medium' }
    association :organization
    assigned_user { nil }
    due_date { nil }
    position { 0 }
    
    trait :with_assignee do
      association :assigned_user, factory: :user
    end
    
    trait :high_priority do
      priority { 'high' }
    end
    
    trait :urgent do
      priority { 'urgent' }
    end
    
    trait :low_priority do
      priority { 'low' }
    end
    
    trait :in_progress do
      status { 'in_progress' }
    end
    
    trait :done do
      status { 'done' }
    end
    
    trait :with_due_date do
      due_date { 1.week.from_now }
    end
    
    trait :overdue do
      due_date { 1.day.ago }
      status { 'todo' }
    end
  end
end
