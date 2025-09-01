FactoryBot.define do
  factory :task do
    sequence(:title) { |n| "Task #{n}" }
    description { Faker::Lorem.paragraph }
    status { 'todo' }
    priority { 'medium' }
    task_type { 'feature' }
    organization_id { create(:organization).id.to_s }
    service_id { create(:service).id.to_s }
    assignee_id { nil }
    reviewer_id { nil }
    team_id { nil }
    due_date { nil }
    position { 0 }
    estimated_hours { nil }
    actual_hours { 0.0 }
    remaining_hours { nil }
    tags { [] }
    labels { [] }
    
    trait :with_assignee do
      assignee_id { create(:user).id.to_s }
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
    
    trait :with_creator do
      created_by_id { create(:user).id.to_s }
    end
  end
end
