# frozen_string_literal: true

require "dry-struct"

module Dto
  # Dashboard 메트릭 데이터 전송 객체
  # View에서 필요한 데이터를 구조화된 형태로 제공
  class DashboardMetrics < Dry::Struct
    transform_keys(&:to_sym)
    attribute :task_stats do
      attribute :total, Types::Integer
      attribute :completed, Types::Integer
      attribute :in_progress, Types::Integer
      attribute :overdue, Types::Integer
      attribute :completion_rate, Types::Float
    end

    attribute :member_stats do
      attribute :total, Types::Integer
      attribute :active, Types::Integer
      attribute :owners, Types::Integer
      attribute :admins, Types::Integer
      attribute :members, Types::Integer
    end

    attribute :activity_stats do
      attribute :tasks_created_today, Types::Integer
      attribute :tasks_completed_today, Types::Integer
      attribute :active_sprints, Types::Integer
    end

    attribute :recent_tasks, Types::Array.of(Types::Any)
    attribute :upcoming_milestones, Types::Array.of(Types::Any)

    # 편의 메서드들
    def has_overdue_tasks?
      task_stats.overdue > 0
    end

    def progress_percentage
      return 0 if task_stats.total.zero?
      ((task_stats.completed.to_f / task_stats.total) * 100).round
    end

    def active_member_percentage
      return 0 if member_stats.total.zero?
      ((member_stats.active.to_f / member_stats.total) * 100).round
    end
  end
end
