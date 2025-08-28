FactoryBot.define do
  factory :sprint do
    association :service
    sequence(:name) { |n| "Sprint #{n}" }
    start_date { Date.today }
    end_date { 2.weeks.from_now.to_date }
    goal { "Sprint goal for #{name}" }
    status { :planning }
    schedule { nil }
  end
end
