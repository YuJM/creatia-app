# frozen_string_literal: true

module Dto
  # SprintDto - Sprint 데이터 전송 객체
  class SprintDto < BaseDto
    attribute :id, Types::String
    attribute :name, Types::String
    attribute :status, Types::String.default("planning")
    attribute :organization_id, Types::String

    attribute? :goal, Types::String.optional
    attribute? :sprint_number, Types::Integer.optional

    # 날짜
    attribute? :start_date, Types::Date.optional
    attribute? :end_date, Types::Date.optional
    attribute? :completed_at, Types::DateTime.optional

    # 타임스탬프
    attribute? :created_at, Types::DateTime.optional
    attribute? :updated_at, Types::DateTime.optional

    # Sprint 특화 속성
    attribute? :planned_capacity, Types::Float.optional
    attribute? :actual_capacity, Types::Float.optional

    # 관계
    attribute? :created_by, UserDto.optional
    attribute? :tasks_count, Types::Integer.default(0)
    attribute? :completed_tasks_count, Types::Integer.default(0)

    def computed_attributes
      {
        "is_active" => active?,
        "is_completed" => completed?,
        "progress_percentage" => progress_percentage,
        "days_remaining" => days_remaining
      }
    end

    def active?
      status == "active"
    end

    def completed?
      status == "completed"
    end

    def progress_percentage
      return 0 if tasks_count.zero?
      ((completed_tasks_count.to_f / tasks_count) * 100).round(1)
    end

    def days_remaining
      return nil unless end_date
      (end_date - Date.current).to_i
    end

    def self.from_model(sprint, enriched_data = {})
      new(
        id: sprint.id.to_s,
        name: sprint.name,
        status: sprint.status,
        organization_id: sprint.organization_id,
        goal: sprint.goal,
        sprint_number: sprint.sprint_number,
        start_date: sprint.start_date,
        end_date: sprint.end_date,
        planned_capacity: sprint.planned_capacity,
        actual_capacity: sprint.actual_capacity,
        created_by: enriched_data[:created_by],
        tasks_count: enriched_data[:tasks_count] || 0,
        completed_tasks_count: enriched_data[:completed_tasks_count] || 0,
        created_at: sprint.created_at,
        updated_at: sprint.updated_at
      )
    end
  end
end
