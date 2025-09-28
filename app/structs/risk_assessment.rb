# frozen_string_literal: true

require 'dry-struct'

class RiskAssessment < Dry::Struct
  attribute :type, Types::String.enum('dependency', 'capacity', 'technical', 'schedule', 'quality', 'resource')
  attribute :severity, Types::String.enum('low', 'medium', 'high', 'critical')
  attribute :probability, Types::Float.constrained(gteq: 0.0, lteq: 1.0)
  attribute :impact_score, Types::Integer.constrained(gteq: 1, lteq: 10)
  attribute :description, Types::String
  attribute :mitigation_strategy, Types::String.optional.default(nil)
  attribute :owner, Types::String.optional.default(nil)
  attribute :target_date, Types::Date.optional.default(nil)
  attribute :status, Types::String.default('identified').enum('identified', 'analyzing', 'mitigating', 'monitoring', 'resolved')
  
  def risk_score
    (probability * impact_score * 10).round(2)
  end
  
  def priority_level
    case risk_score
    when 0..25 then 'low'
    when 26..50 then 'medium'  
    when 51..75 then 'high'
    else 'critical'
    end
  end
  
  def is_critical?
    severity == 'critical' || risk_score > 75
  end
  
  def is_overdue?
    return false unless target_date
    Date.current > target_date && status != 'resolved'
  end
  
  def requires_immediate_attention?
    is_critical? || is_overdue?
  end
  
  def severity_color
    case severity
    when 'low' then 'green'
    when 'medium' then 'yellow'
    when 'high' then 'orange'
    when 'critical' then 'red'
    end
  end
  
  def status_icon
    case status
    when 'identified' then '🔍'
    when 'analyzing' then '🔬'
    when 'mitigating' then '🛠️'
    when 'monitoring' then '👁️'
    when 'resolved' then '✅'
    end
  end
  
  def days_until_target
    return nil unless target_date
    (target_date - Date.current).to_i
  end
  
  def self.create_capacity_risk(utilization_rate, team_size)
    severity = case utilization_rate
               when 0..70 then 'low'
               when 71..90 then 'medium'
               when 91..110 then 'high'
               else 'critical'
               end
    
    new(
      type: 'capacity',
      severity: severity,
      probability: [utilization_rate / 100.0, 1.0].min,
      impact_score: team_size < 3 ? 8 : 6,
      description: "팀 활용률이 #{utilization_rate}%입니다",
      mitigation_strategy: utilization_rate > 100 ? "작업량 조정 또는 팀원 추가" : "업무 재분배 고려"
    )
  end
  
  def self.create_dependency_risk(blocked_tasks_count)
    return nil if blocked_tasks_count.zero?
    
    new(
      type: 'dependency',
      severity: blocked_tasks_count > 3 ? 'high' : 'medium',
      probability: 0.8,
      impact_score: [blocked_tasks_count * 2, 10].min,
      description: "#{blocked_tasks_count}개의 블로킹된 작업이 있습니다",
      mitigation_strategy: "종속성 해결 및 블로킹 이슈 제거"
    )
  end
end