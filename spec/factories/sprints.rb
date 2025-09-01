FactoryBot.define do
  factory :sprint do
    organization_id { create(:organization).id.to_s }
    service_id { create(:service).id.to_s }
    sequence(:name) { |n| "Sprint #{n}" }
    start_date { Date.today }
    end_date { 2.weeks.from_now.to_date }
    goal { "Sprint goal for #{name}" }
    status { 'planning' }
    sprint_number { 1 }
    planned_capacity { 40.0 }
    actual_capacity { nil }
    created_by_id { nil }
  end
end
