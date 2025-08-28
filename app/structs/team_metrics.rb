# frozen_string_literal: true

require 'dry-struct'

class TeamMetrics < Dry::Struct
  attribute :total_capacity, Types::Float.default(0.0)
  attribute :allocated_hours, Types::Float.default(0.0)
  attribute :completed_hours, Types::Float.default(0.0)
  attribute :team_size, Types::Integer.default(0)
  attribute :active_tasks, Types::Integer.default(0)
  attribute :completed_tasks, Types::Integer.default(0)
  attribute :blocked_tasks, Types::Integer.default(0)
  attribute :velocity_last_sprint, Types::Float.optional.default(nil)
  attribute :average_velocity, Types::Float.optional.default(nil)
  
  def utilization_rate
    return 0.0 if total_capacity.zero?
    (allocated_hours / total_capacity * 100).round(2)
  end
  
  def completion_rate
    total_tasks = active_tasks + completed_tasks + blocked_tasks
    return 0.0 if total_tasks.zero?
    (completed_tasks.to_f / total_tasks * 100).round(2)
  end
  
  def capacity_per_member
    return 0.0 if team_size.zero?
    (total_capacity / team_size).round(2)
  end
  
  def hours_per_task
    return 0.0 if active_tasks.zero?
    (allocated_hours / active_tasks).round(2)
  end
  
  def is_overallocated?
    utilization_rate > 100.0
  end
  
  def is_underutilized?
    utilization_rate < 70.0
  end
  
  def has_blocked_issues?
    blocked_tasks > 0
  end
  
  def velocity_trend
    return 'unknown' unless velocity_last_sprint && average_velocity
    
    if velocity_last_sprint > average_velocity * 1.1
      'improving'
    elsif velocity_last_sprint < average_velocity * 0.9
      'declining'
    else
      'stable'
    end
  end
  
  def health_score
    score = 100.0
    
    # 과다 할당 페널티
    score -= 20 if is_overallocated?
    
    # 미활용 페널티 (적은 페널티)
    score -= 10 if is_underutilized?
    
    # 블로킹된 태스크 페널티
    score -= (blocked_tasks * 5)
    
    # 완료율 보너스
    score += (completion_rate * 0.3)
    
    [score, 0].max.round(1)
  end
end