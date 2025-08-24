# 사용자 Factory 예제
FactoryBot.define do
  factory :user do
    # Faker를 사용한 한국어 테스트 데이터 생성
    name { Faker::Name.name }
    email { Faker::Internet.unique.email }
    phone { Faker::PhoneNumber.cell_phone }
    address { Faker::Address.full_address }
    
    # 특정 유형의 사용자
    trait :admin do
      role { "admin" }
      admin { true }
    end

    trait :premium do
      subscription_level { "premium" }
      subscription_expires_at { 1.year.from_now }
    end

    # 연관 관계가 있는 경우 예제
    # association :profile
    # has_many :posts
  end
end