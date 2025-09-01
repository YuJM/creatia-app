# frozen_string_literal: true

require "dry-struct"

module Dto
  # Milestone 데이터 전송 객체 (MongoDB 모델 기반)
  class MilestoneDto < Dry::Struct
    transform_keys(&:to_sym)

    # Core identifiers
    attribute :id, Types::String
    attribute :title, Types::String
    attribute :description, Types::String.optional

    # References
    attribute :organization_id, Types::String
    attribute :service_id, Types::String.optional
    attribute :created_by_id, Types::String.optional

    # Milestone definition
    attribute :status, Types::String.default("planning")  # planning, active, completed, cancelled
    attribute :milestone_type, Types::String.default("release")  # release, feature, business

    # Timeline
    attribute :planned_start, Types::Date.optional
    attribute :planned_end, Types::Date.optional
    attribute :actual_start, Types::Date.optional
    attribute :actual_end, Types::Date.optional

    # Progress tracking
    attribute :total_sprints, Types::Integer.default(0)
    attribute :completed_sprints, Types::Integer.default(0)
    attribute :total_tasks, Types::Integer.default(0)
    attribute :completed_tasks, Types::Integer.default(0)
    attribute :progress_percentage, Types::Float.default(0.0)

    # Objectives & Key Results
    attribute :objectives, Types::Array.default { [] }

    # Risk & Dependencies
    attribute :risks, Types::Array.default { [] }
    attribute :dependencies, Types::Array.default { [] }
    attribute :blockers, Types::Array.default { [] }

    # Timestamps
    attribute :created_at, Types::DateTime
    attribute :updated_at, Types::DateTime

    def self.from_model(milestone)
      return nil unless milestone

      new(
        id: milestone.id.to_s,
        title: milestone.title || "Untitled Milestone",
        description: milestone.description,
        organization_id: milestone.organization_id.to_s,
        service_id: milestone.service_id,
        created_by_id: milestone.created_by_id,
        status: milestone.status || "planning",
        milestone_type: milestone.milestone_type || "release",
        planned_start: milestone.planned_start,
        planned_end: milestone.planned_end,
        actual_start: milestone.actual_start,
        actual_end: milestone.actual_end,
        total_sprints: milestone.total_sprints || 0,
        completed_sprints: milestone.completed_sprints || 0,
        total_tasks: milestone.total_tasks || 0,
        completed_tasks: milestone.completed_tasks || 0,
        progress_percentage: milestone.progress_percentage || 0.0,
        objectives: milestone.objectives || [],
        risks: milestone.risks || [],
        dependencies: milestone.dependencies || [],
        blockers: milestone.blockers || [],
        created_at: milestone.created_at,
        updated_at: milestone.updated_at
      )
    end

    def self.calculate_progress(milestone)
      # 이미 progress_percentage가 있으면 그것을 사용
      return milestone.progress_percentage if milestone.respond_to?(:progress_percentage) && milestone.progress_percentage

      # 없으면 계산
      total = milestone.total_tasks || 0
      return 0 if total.zero?

      completed = milestone.completed_tasks || 0
      ((completed.to_f / total) * 100).round
    end

    def overdue?
      planned_end && planned_end < Date.current && status != "completed"
    end

    def days_remaining
      return nil unless planned_end
      (planned_end - Date.current).to_i
    end

    def sprint_progress
      return 0 if total_sprints.zero?
      ((completed_sprints.to_f / total_sprints) * 100).round
    end

    def task_progress
      return 0 if total_tasks.zero?
      ((completed_tasks.to_f / total_tasks) * 100).round
    end

    def is_active?
      status == "active"
    end

    def is_completed?
      status == "completed"
    end

    def status_color
      case status
      when "completed" then "green"
      when "active" then "blue"
      when "planning" then "gray"
      else "yellow"
      end
    end
  end
end
