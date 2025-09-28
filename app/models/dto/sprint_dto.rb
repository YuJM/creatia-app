# frozen_string_literal: true

module Dto
  # SprintDto - Sprint 데이터 전송 객체 (MongoDB 모델 기반)
  class SprintDto < BaseDto
    attribute :id, Types::String
    attribute :name, Types::String
    attribute :status, Types::String.default("planning")
    attribute :organization_id, Types::String
    attribute? :milestone_id, Types::String.optional
    attribute? :service_id, Types::String.optional
    attribute? :team_id, Types::String.optional

    attribute? :goal, Types::String.optional
    attribute? :sprint_number, Types::Integer.optional

    # Timeline
    attribute? :start_date, Types::Date.optional
    attribute? :end_date, Types::Date.optional
    attribute? :working_days, Types::Integer.optional

    # Capacity & Velocity
    attribute? :team_capacity, Types::Float.optional
    attribute? :planned_velocity, Types::Float.optional
    attribute? :actual_velocity, Types::Float.optional
    attribute? :carry_over_velocity, Types::Float.optional

    # Sprint Planning
    attribute? :committed_points, Types::Float.default(0.0)
    attribute? :stretch_points, Types::Float.default(0.0)
    attribute? :completed_points, Types::Float.default(0.0)
    attribute? :spillover_points, Types::Float.default(0.0)

    # Task Management
    attribute? :total_tasks, Types::Integer.default(0)
    attribute? :completed_tasks, Types::Integer.default(0)
    attribute? :active_tasks, Types::Integer.default(0)

    # Health & Risk
    attribute? :health_score, Types::Float.default(100.0)
    attribute? :risk_level, Types::String.default("low")

    # User Snapshots (간소화된 버전)
    attribute? :sprint_owner, Types::Hash.optional
    attribute? :scrum_master, Types::Hash.optional
    attribute? :team_members, Types::Array.default { [] }
    attribute? :created_by, Types::Hash.optional

    # Blockers & Scope Changes (요약)
    attribute? :active_blockers_count, Types::Integer.default(0)
    attribute? :scope_changes_count, Types::Integer.default(0)

    # Timestamps
    attribute? :created_at, Types::DateTime.optional
    attribute? :updated_at, Types::DateTime.optional

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
      return 0 if total_tasks.zero?
      ((completed_tasks.to_f / total_tasks) * 100).round(1)
    end

    def days_remaining
      return nil unless end_date
      (end_date - Date.current).to_i
    end

    def self.from_model(sprint)
      return nil unless sprint
      
      # Count active blockers and scope changes
      active_blockers = sprint.blockers&.count { |b| b['resolved_at'].nil? } || 0
      unapproved_changes = sprint.scope_changes&.count { |c| c['approved_at'].nil? } || 0
      
      new(
        id: sprint.id.to_s,
        name: sprint.name || "Sprint #{sprint.sprint_number}",
        status: sprint.status || "planning",
        organization_id: sprint.organization_id.to_s,
        milestone_id: sprint.milestone_id,
        service_id: sprint.service_id,
        team_id: sprint.team_id,
        goal: sprint.goal,
        sprint_number: sprint.sprint_number,
        start_date: sprint.start_date,
        end_date: sprint.end_date,
        working_days: sprint.working_days,
        team_capacity: sprint.team_capacity,
        planned_velocity: sprint.planned_velocity,
        actual_velocity: sprint.actual_velocity,
        carry_over_velocity: sprint.carry_over_velocity,
        committed_points: sprint.committed_points,
        stretch_points: sprint.stretch_points,
        completed_points: sprint.completed_points,
        spillover_points: sprint.spillover_points,
        total_tasks: sprint.total_tasks || 0,
        completed_tasks: sprint.completed_tasks || 0,
        active_tasks: sprint.active_tasks || 0,
        health_score: sprint.health_score || 100.0,
        risk_level: sprint.risk_level || "low",
        sprint_owner: simplify_user_snapshot(sprint.sprint_owner_snapshot),
        scrum_master: simplify_user_snapshot(sprint.scrum_master_snapshot),
        team_members: (sprint.team_member_snapshots || []).map { |m| simplify_team_member(m) },
        created_by: simplify_user_snapshot(sprint.created_by_snapshot),
        active_blockers_count: active_blockers,
        scope_changes_count: unapproved_changes,
        created_at: sprint.created_at,
        updated_at: sprint.updated_at
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
    
    def self.simplify_team_member(member)
      {
        user_id: member['user_id'],
        name: member['name'],
        email: member['email'],
        role: member['role_in_sprint'],
        capacity_hours: member['capacity_hours']
      }
    end
  end
end
