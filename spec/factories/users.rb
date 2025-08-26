FactoryBot.define do
  factory :user do
    email { Faker::Internet.unique.email }
    password { 'password123' }
    password_confirmation { 'password123' }
    username { Faker::Internet.unique.username(specifier: 3..20, separators: %w[_ -]) }
    name { Faker::Name.name }
    bio { Faker::Lorem.paragraph }
    role { 'user' }
    
    trait :admin do
      role { 'admin' }
    end
    
    trait :moderator do
      role { 'moderator' }
    end
    
    trait :with_avatar do
      avatar_url { Faker::Avatar.image }
    end
    
    trait :oauth_github do
      provider { 'github' }
      uid { Faker::Number.number(digits: 8).to_s }
    end
    
    trait :oauth_google do
      provider { 'google_oauth2' }
      uid { Faker::Number.number(digits: 21).to_s }
    end
    
    trait :tracked do
      sign_in_count { Faker::Number.between(from: 1, to: 100) }
      current_sign_in_at { Faker::Time.between(from: 1.hour.ago, to: Time.current) }
      last_sign_in_at { Faker::Time.between(from: 1.week.ago, to: 1.day.ago) }
      current_sign_in_ip { Faker::Internet.ip_v4_address }
      last_sign_in_ip { Faker::Internet.ip_v4_address }
    end
  end
end
