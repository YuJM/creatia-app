FactoryBot.define do
  factory :mongo_task, class: 'Mongodb::MongoTask' do
    sequence(:title) { |n| "Task #{n}" }
    description { Faker::Lorem.paragraph }
    status { 'todo' }
    priority { 'medium' }
    association :organization
    association :service
    assigned_user { nil }
    assignee { nil }
    created_by { nil }
    team { nil }
    due_date { nil }
    position { 0 }
    
    # MongoDB specific fields
    _id { BSON::ObjectId.new }
    
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
    
    trait :with_creator do
      association :created_by, factory: :user
    end
    
    trait :with_story_points do
      story_points { rand(1..8) }
    end
    
    trait :completed do
      status { 'done' }
      completed_at { Time.current }
    end
  end
end