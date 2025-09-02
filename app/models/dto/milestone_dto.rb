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

    # User Snapshots (간소화된 버전)
    attribute :owner, Types::Hash.optional
    # { user_id, name, email, avatar_url }
    
    attribute :created_by, Types::Hash.optional
    
    attribute :stakeholders, Types::Array.default { [] }
    # [{ user_id, name, email, role }]

    # Objectives & Key Results (간소화)
    attribute :objectives_count, Types::Integer.default(0)
    attribute :key_results_count, Types::Integer.default(0)
    attribute :key_results_achieved, Types::Integer.default(0)

    # Risk & Dependencies (요약)
    attribute :high_risks_count, Types::Integer.default(0)
    attribute :open_blockers_count, Types::Integer.default(0)
    attribute :pending_dependencies_count, Types::Integer.default(0)

    # Health Status
    attribute :health_status, Types::String.default("on_track")

    # Timestamps
    attribute :created_at, Types::DateTime
    attribute :updated_at, Types::DateTime

    def self.from_model(milestone)
      return nil unless milestone

      # Count metrics
      objectives_count = milestone.objectives&.count || 0
      key_results_count = milestone.objectives&.sum { |o| o['key_results']&.count || 0 } || 0
      key_results_achieved = milestone.objectives&.sum { |o| 
        o['key_results']&.count { |kr| kr['current'] >= kr['target'] } || 0 
      } || 0
      
      high_risks_count = milestone.risks&.count { |r| 
        r['severity'] == 'high' || r['severity'] == 'critical' 
      } || 0
      
      open_blockers_count = milestone.blockers&.count { |b| 
        b['status'] != 'resolved' 
      } || 0
      
      pending_dependencies_count = milestone.dependencies&.count { |d| 
        d['status'] == 'pending' 
      } || 0

      new(
        id: milestone.id.to_s,
        title: milestone.title || "Untitled Milestone",
        description: milestone.description,
        organization_id: milestone.organization_id.to_s,
        service_id: milestone.service_id,
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
        owner: simplify_user_snapshot(milestone.owner_snapshot),
        created_by: simplify_user_snapshot(milestone.created_by_snapshot),
        stakeholders: (milestone.stakeholder_snapshots || []).map { |s| simplify_stakeholder(s) },
        objectives_count: objectives_count,
        key_results_count: key_results_count,
        key_results_achieved: key_results_achieved,
        high_risks_count: high_risks_count,
        open_blockers_count: open_blockers_count,
        pending_dependencies_count: pending_dependencies_count,
        health_status: milestone.respond_to?(:health_status) ? milestone.health_status : "on_track",
        created_at: milestone.created_at,
        updated_at: milestone.updated_at
      )
    end
    
    def self.simplify_user_snapshot(snapshot)
      return nil if snapshot.blank?
      
      {
        user_id: snapshot['user_id'],
        name: snapshot['name'],
        email: snapshot['email'],
        avatar_url: snapshot['avatar_url']
      }
    end
    
    def self.simplify_stakeholder(stakeholder)
      {
        user_id: stakeholder['user_id'],
        name: stakeholder['name'],
        email: stakeholder['email'],
        role: stakeholder['role']
      }
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
