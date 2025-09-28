FactoryBot.define do
  factory :mongo_sprint, class: 'Mongodb::MongoSprint' do
    association :service
    sequence(:name) { |n| "Sprint #{n}" }
    start_date { Date.today }
    end_date { 2.weeks.from_now.to_date }
    goal { "Sprint goal for #{name}" }
    status { :planning }
    schedule { nil }
    
    # MongoDB specific fields
    _id { BSON::ObjectId.new }
    
    trait :active do
      status { :active }
      start_date { 1.week.ago }
      end_date { 1.week.from_now }
    end
    
    trait :completed do
      status { :completed }
      start_date { 4.weeks.ago }
      end_date { 2.weeks.ago }
    end
    
    trait :upcoming do
      status { :planning }
      start_date { 1.week.from_now }
      end_date { 3.weeks.from_now }
    end
    
    trait :with_velocity do
      velocity { rand(20..50) }
    end
  end
end