# frozen_string_literal: true

require 'dry-struct'

module Dto
  # Sprint 데이터 전송 객체 (MongoDB 모델 기반)
  class SprintDto < Dry::Struct
    transform_keys(&:to_sym)
    
    # Core identifiers
    attribute :id, Types::String
    attribute :name, Types::String
    attribute :sprint_number, Types::Integer.optional
    
    # References
    attribute :organization_id, Types::String
    attribute :service_id, Types::String.optional
    attribute :team_id, Types::String.optional
    attribute :milestone_id, Types::String.optional
    
    # Sprint definition
    attribute :goal, Types::String.optional
    attribute :status, Types::String.default('planning')  # planning, active, completed, cancelled
    
    # Timeline
    attribute :start_date, Types::Date
    attribute :end_date, Types::Date
    attribute :working_days, Types::Integer.optional
    
    # Capacity & Velocity
    attribute :team_capacity, Types::Float.optional
    attribute :planned_velocity, Types::Float.optional
    attribute :actual_velocity, Types::Float.optional
    
    # Sprint metrics
    attribute :committed_points, Types::Float.optional
    attribute :completed_points, Types::Float.optional
    attribute :total_tasks, Types::Integer.default(0)
    attribute :completed_tasks, Types::Integer.default(0)
    attribute :active_tasks, Types::Integer.default(0)
    
    # Health & Risk
    attribute :health_score, Types::Float.default(100.0)
    attribute :risk_level, Types::String.default('low')
    attribute :blockers, Types::Array.default { [] }
    
    # Timestamps
    attribute :created_at, Types::DateTime
    attribute :updated_at, Types::DateTime
    
    # Computed properties
    def progress_percentage
      return 0 if total_tasks.zero?
      ((completed_tasks.to_f / total_tasks) * 100).round
    end
    
    def days_remaining
      return 0 if end_date < Date.current
      (end_date - Date.current).to_i
    end
    
    def days_elapsed
      return 0 if start_date > Date.current
      (Date.current - start_date).to_i
    end
    
    def is_active?
      status == 'active'
    end
    
    def is_completed?
      status == 'completed'
    end
    
    def is_overdue?
      status == 'active' && end_date < Date.current
    end
    
    def burndown_rate
      return 0 if days_elapsed.zero? || committed_points.nil? || completed_points.nil?
      (completed_points / days_elapsed).round(2)
    end
    
    def velocity_achievement
      return 0 if planned_velocity.nil? || planned_velocity.zero? || actual_velocity.nil?
      ((actual_velocity / planned_velocity) * 100).round
    end
    
    def status_color
      {
        'planning' => 'gray',
        'active' => 'blue',
        'completed' => 'green',
        'cancelled' => 'red'
      }[status]
    end
    
    def health_color
      case health_score
      when 80..100 then 'green'
      when 60..79 then 'yellow'
      when 40..59 then 'orange'
      else 'red'
      end
    end
    
    # Factory method to create from MongoDB model
    def self.from_model(sprint)
      return nil unless sprint
      
      new(
        id: sprint.id.to_s,
        name: sprint.name,
        sprint_number: sprint.sprint_number,
        organization_id: sprint.organization_id,
        service_id: sprint.service_id,
        team_id: sprint.team_id,
        milestone_id: sprint.milestone_id,
        goal: sprint.goal,
        status: sprint.status || 'planning',
        start_date: sprint.start_date,
        end_date: sprint.end_date,
        working_days: sprint.working_days,
        team_capacity: sprint.team_capacity,
        planned_velocity: sprint.planned_velocity,
        actual_velocity: sprint.actual_velocity,
        committed_points: sprint.committed_points,
        completed_points: sprint.completed_points,
        total_tasks: sprint.total_tasks || 0,
        completed_tasks: sprint.completed_tasks || 0,
        active_tasks: sprint.active_tasks || 0,
        health_score: sprint.health_score || 100.0,
        risk_level: sprint.risk_level || 'low',
        blockers: sprint.blockers || [],
        created_at: sprint.created_at,
        updated_at: sprint.updated_at
      )
    end
  end
end