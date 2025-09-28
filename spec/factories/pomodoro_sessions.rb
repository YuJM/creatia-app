FactoryBot.define do
  factory :pomodoro_session do
    association :task
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
  end
end
