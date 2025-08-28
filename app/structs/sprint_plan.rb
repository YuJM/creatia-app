# frozen_string_literal: true

require 'dry-struct'

class SprintPlan < Dry::Struct
  attribute :sprint, Types.Instance(Sprint)
  attribute :allocations, Types::Hash
  attribute :capacity, Types::Float
  attribute :risks, Types::Array.of(Types::Hash)
  attribute :burndown, Types::Hash
  
  def high_risk?
    risks.any? { |r| r[:severity] == 'high' }
  end
  
  def medium_risk?
    risks.any? { |r| r[:severity] == 'medium' }
  end
  
  def utilization_rate
    return 0.0 if capacity.zero?
    
    total_allocated = allocations.values.flatten.sum do |task|
      task.respond_to?(:estimated_hours) ? task.estimated_hours : 0
    end
    
    (total_allocated.to_f / capacity * 100).round(2)
  end
  
  def overloaded?
    utilization_rate > 100
  end
  
  def on_track?
    burndown[:will_complete] == true
  end
  
  def risk_summary
    {
      high: risks.count { |r| r[:severity] == 'high' },
      medium: risks.count { |r| r[:severity] == 'medium' },
      low: risks.count { |r| r[:severity] == 'low' },
      total: risks.count
    }
  end
  
  def allocation_summary
    allocations.transform_values do |tasks|
      {
        count: tasks.size,
        hours: tasks.sum { |t| t.estimated_hours || 0 }
      }
    end
  end
end