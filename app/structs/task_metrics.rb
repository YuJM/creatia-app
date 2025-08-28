# frozen_string_literal: true

require 'dry-struct'

class TaskMetrics < Dry::Struct
  attribute :estimated_hours, Types::Float.optional.default(nil)
  attribute :actual_hours, Types::Float.optional.default(nil)
  attribute :remaining_hours, Types::Float.optional.default(nil)
  attribute :completion_percentage, Types::Float.default(0.0)
  attribute :velocity, Types::Float.optional.default(nil)
  attribute :complexity_score, Types::Integer.default(1)
  
  def overdue?
    return false unless estimated_hours && actual_hours
    actual_hours > estimated_hours
  end
  
  def efficiency_ratio
    return 0.0 unless estimated_hours && actual_hours && estimated_hours > 0
    (estimated_hours / actual_hours).round(2)
  end
  
  def remaining_percentage
    100.0 - completion_percentage
  end
  
  def is_on_track?
    return true unless estimated_hours && actual_hours
    efficiency_ratio >= 0.8
  end
  
  def complexity_level
    case complexity_score
    when 1..2 then 'low'
    when 3..5 then 'medium'
    when 6..8 then 'high'
    else 'very_high'
    end
  end
end