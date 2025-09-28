# frozen_string_literal: true

require "dry-struct"

module Dto
  # Sprint Board 데이터 전송 객체
  class SprintBoardDto < Dry::Struct
    transform_keys(&:to_sym)

    attribute :sprint, SprintDto

    attribute :columns, Types::Array do
      attribute :status, Types::String
      attribute :title, Types::String
      attribute :tasks, Types::Array.of(TaskDto)
    end

    attribute :statistics do
      attribute :total_tasks, Types::Integer
      attribute :completed_tasks, Types::Integer
      attribute :in_progress_tasks, Types::Integer
      attribute :total_points, Types::Integer
      attribute :completed_points, Types::Integer
      attribute :velocity, Types::Float
      attribute :days_remaining, Types::Integer
      attribute :completion_rate, Types::Float
    end

    # 헬퍼 메서드들
    def column_for_status(status)
      columns.find { |col| col.status == status }
    end

    def tasks_for_status(status)
      column_for_status(status)&.tasks || []
    end

    def progress_percentage
      return 0 if statistics.total_tasks.zero?
      ((statistics.completed_tasks.to_f / statistics.total_tasks) * 100).round
    end

    def is_on_track?
      return true if statistics.days_remaining.zero?

      expected_completion = (sprint.duration_days - statistics.days_remaining).to_f / sprint.duration_days
      actual_completion = statistics.completion_rate / 100.0

      actual_completion >= expected_completion * 0.9 # 10% 버퍼
    end

    def status_summary
      columns.map do |column|
        {
          status: column.status,
          title: column.title,
          count: column.tasks.size,
          percentage: statistics.total_tasks.zero? ? 0 : ((column.tasks.size.to_f / statistics.total_tasks) * 100).round
        }
      end
    end
  end
end
