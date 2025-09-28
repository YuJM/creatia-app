FactoryBot.define do
  factory :notification do
    recipient_id { 1 }
    recipient_type { 'User' }
    type { 'TestNotification' }
    title { 'Test Notification' }
    body { 'This is a test notification body' }
    priority { 'medium' }
    category { 'system' }
    channels { ['in_app'] }
    
    trait :high_priority do
      priority { 'high' }
    end
    
    trait :urgent do
      priority { 'urgent' }
    end
    
    trait :task_notification do
      type { 'TaskAssignedNotification' }
      category { 'task' }
      title { 'New Task Assigned' }
      body { 'You have been assigned a new task' }
    end
    
    trait :with_email do
      channels { ['in_app', 'email'] }
    end
    
    trait :with_push do
      channels { ['in_app', 'push'] }
    end
    
    trait :read do
      read_at { Time.current }
      status { 'read' }
    end
    
    trait :archived do
      archived_at { Time.current }
      status { 'archived' }
    end
    
    trait :scheduled do
      scheduled_for { 1.hour.from_now }
    end
    
    trait :with_metadata do
      metadata do
        {
          task_id: 123,
          project_id: 456,
          sender_name: 'John Doe'
        }
      end
    end
  end
end