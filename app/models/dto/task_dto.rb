# frozen_string_literal: true

module Dto
  # TaskDto - Task 데이터 전송 객체
  class TaskDto < BaseDto
    # 핵심 필수 속성
    attribute :id, Types::String
    attribute :title, Types::String
    attribute :status, Types::TaskStatus
    attribute :priority, Types::TaskPriority
    attribute :organization_id, Types::String

    # 설명
    attribute? :description, Types::String.optional
    attribute? :task_id, Types::String.optional  # e.g., "PROJ-123"

    # 날짜
    attribute? :due_date, Types::Date.optional
    attribute? :start_date, Types::Date.optional
    attribute? :completed_at, Types::DateTime.optional

    # 관계
    attribute? :assignee, UserDto.optional
    attribute? :reviewer, UserDto.optional
    attribute? :sprint, Types::Hash.optional
    attribute? :milestone, Types::Hash.optional

    # 추적
    attribute? :estimated_hours, Types::Float.optional
    attribute? :actual_hours, Types::Float.default(0.0)
    attribute? :remaining_hours, Types::Float.optional
    attribute? :completion_percentage, Types::Integer.default(0)

    # 메타데이터
    attribute? :tags, Types::Array.of(Types::String).default([].freeze)
    attribute? :labels, Types::Array.of(Types::String).default([].freeze)
    attribute? :position, Types::Integer.default(0)

    # 타임스탬프
    attribute? :created_at, Types::DateTime.optional
    attribute? :updated_at, Types::DateTime.optional

    # 계산된 속성
    def computed_attributes
      {
        "is_overdue" => overdue?,
        "is_urgent" => urgent?,
        "is_completed" => completed?
      }
    end

    # 비즈니스 로직
    def overdue?
      due_date && due_date < Date.current && status != "done"
    end

    def urgent?
      priority == "urgent" || overdue?
    end

    def completed?
      status == "done"
    end

    def assigned?
      assignee.present?
    end

    def blocked?
      status == "blocked"
    end

    def in_progress?
      status == "in_progress"
    end

    # 상태/우선순위 색상
    def status_color
      {
        "todo" => "gray",
        "in_progress" => "blue",
        "review" => "yellow",
        "done" => "green",
        "blocked" => "red",
        "cancelled" => "gray"
      }[status] || "gray"
    end

    def priority_color
      {
        "low" => "gray",
        "medium" => "yellow",
        "high" => "orange",
        "urgent" => "red"
      }[priority] || "gray"
    end

    # Service Layer용 팩토리 메서드
    def self.from_enriched_data(task_data, user_data = {})
      new(
        id: task_data[:id] || task_data["_id"]&.to_s,
        title: task_data[:title],
        description: task_data[:description],
        status: task_data[:status] || "todo",
        priority: task_data[:priority] || "medium",
        organization_id: task_data[:organization_id],
        task_id: task_data[:task_id],
        due_date: task_data[:due_date],
        start_date: task_data[:start_date],
        completed_at: task_data[:completed_at],
        assignee: user_data[:assignee],
        reviewer: user_data[:reviewer],
        sprint: task_data[:sprint],
        milestone: task_data[:milestone],
        estimated_hours: task_data[:estimated_hours],
        actual_hours: task_data[:actual_hours],
        remaining_hours: task_data[:remaining_hours],
        completion_percentage: task_data[:completion_percentage] || 0,
        tags: task_data[:tags] || [],
        labels: task_data[:labels] || [],
        position: task_data[:position] || 0,
        created_at: task_data[:created_at],
        updated_at: task_data[:updated_at]
      )
    end
  end
end
