# frozen_string_literal: true

require 'dry-struct'

class TaskStatus < Dry::Struct
  attribute :state, Types::String.enum('todo', 'in_progress', 'blocked', 'review', 'done')
  attribute? :blocked_by, Types::Array.of(Types::String).optional
  attribute? :blocking, Types::Array.of(Types::String).optional
  attribute? :assigned_to, Types::String.optional
  attribute? :started_at, Types::Time.optional
  attribute? :completed_at, Types::Time.optional
  
  def can_transition_to?(new_state)
    case state
    when 'todo'
      %w[in_progress blocked].include?(new_state)
    when 'in_progress'
      %w[blocked review done].include?(new_state)
    when 'blocked'
      %w[in_progress].include?(new_state)
    when 'review'
      %w[in_progress done].include?(new_state)
    when 'done'
      false # 완료된 태스크는 상태 변경 불가
    else
      false
    end
  end
  
  def blocked?
    state == 'blocked'
  end
  
  def in_progress?
    state == 'in_progress'
  end
  
  def done?
    state == 'done'
  end
  
  def todo?
    state == 'todo'
  end
  
  def review?
    state == 'review'
  end
  
  def active?
    %w[in_progress review].include?(state)
  end
  
  def completed?
    state == 'done'
  end
  
  def workable?
    !blocked? && !done?
  end
  
  def duration
    return nil unless started_at
    
    end_time = completed_at || Time.current
    end_time - started_at
  end
  
  def days_in_progress
    return 0 unless started_at
    
    ((Time.current - started_at) / 1.day).round
  end
end