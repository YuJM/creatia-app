# frozen_string_literal: true

require "dry-struct"

module Dto
  # Task 통계 데이터 전송 객체
  class TaskStatisticsDto < Dry::Struct
    transform_keys(&:to_sym)

    attribute :total, Types::Integer

    attribute :by_status do
      attribute :todo, Types::Integer
      attribute :in_progress, Types::Integer
      attribute :review, Types::Integer
      attribute :done, Types::Integer
    end

    attribute :by_priority do
      attribute :urgent, Types::Integer
      attribute :high, Types::Integer
      attribute :medium, Types::Integer
      attribute :low, Types::Integer
    end

    attribute :overdue, Types::Integer
    attribute :unassigned, Types::Integer

    # 계산된 속성들
    def completion_rate
      return 0 if total.zero?
      ((by_status.done.to_f / total) * 100).round(1)
    end

    def in_progress_rate
      return 0 if total.zero?
      ((by_status.in_progress.to_f / total) * 100).round(1)
    end

    def has_overdue?
      overdue > 0
    end

    def urgent_count
      by_priority.urgent + by_priority.high
    end

    def status_chart_data
      {
        labels: [ "Todo", "In Progress", "Review", "Done" ],
        datasets: [ {
          data: [ by_status.todo, by_status.in_progress, by_status.review, by_status.done ],
          backgroundColor: [ "#9CA3AF", "#3B82F6", "#FCD34D", "#10B981" ]
        } ]
      }
    end

    def priority_chart_data
      {
        labels: [ "Urgent", "High", "Medium", "Low" ],
        datasets: [ {
          data: [ by_priority.urgent, by_priority.high, by_priority.medium, by_priority.low ],
          backgroundColor: [ "#EF4444", "#F97316", "#FCD34D", "#9CA3AF" ]
        } ]
      }
    end
  end
end
