FactoryBot.define do
  factory :permission do
    sequence(:resource) { |n| "Resource#{n}" }
    sequence(:action) { |n| %w[read create update delete manage].sample }
    name { "#{resource} #{action}" }
    description { "Permission to #{action} #{resource}" }
  end
end