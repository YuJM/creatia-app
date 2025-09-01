FactoryBot.define do
  factory :mongo_pomodoro_session, class: 'Mongodb::MongoPomodoroSession' do
    association :task, factory: :mongo_task
    association :user
    started_at { Time.current }
    completed_at { nil }
    ended_at { nil }
    status { :in_progress }
    session_count { 1 }
    actual_duration { nil }
    duration { nil }
    paused_at { nil }
    paused_duration { 0 }
    
    # MongoDB specific fields
    _id { BSON::ObjectId.new }
    
    trait :completed do
      status { :completed }
      ended_at { Time.current }
      completed_at { Time.current }
      actual_duration { 25.minutes.to_i }
    end
    
    trait :cancelled do
      status { :cancelled }
      ended_at { Time.current }
    end
    
    trait :paused do
      status { :paused }
      paused_at { Time.current }
    end
    
    trait :today do
      started_at { Time.current.beginning_of_day + rand(8..17).hours }
    end
    
    trait :yesterday do
      started_at { 1.day.ago + rand(8..17).hours }
    end
    
    trait :this_week do
      started_at { rand(7).days.ago + rand(8..17).hours }
    end
  end
end