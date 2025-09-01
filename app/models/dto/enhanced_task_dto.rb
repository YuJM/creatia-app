# frozen_string_literal: true

require 'dry-struct'
require 'dry-monads'

module Dto
  # 향상된 Task DTO - Value Objects와 Maybe 모나드 활용
  class EnhancedTaskDto < Dry::Struct
    include Dry::Monads[:maybe]
    
    transform_keys(&:to_sym)
    
    # Core attributes with strong typing
    attribute :id, Types::ID
    attribute :task_id, Types::String  # PROJ-123 형태의 비즈니스 ID
    attribute :title, Types::StrictString
    attribute :status, Types::TaskStatus
    attribute :priority, Types::TaskPriority
    attribute :organization_id, Types::ID
    attribute :service_id, Types::OptionalID
    
    # Optional attributes with defaults
    attribute? :description, Types::String.optional.default(nil)
    attribute? :due_date, Types::OptionalDate
    attribute? :estimated_hours, Types::OptionalEstimatedHours
    attribute? :actual_hours, Types::OptionalEstimatedHours
    attribute? :completion_percentage, Types::Percentage.default(0)
    attribute? :position, Types::OptionalCoordinate
    
    # Timestamps
    attribute :created_at, Types::DateTime
    attribute :updated_at, Types::DateTime
    attribute? :started_at, Types::OptionalDateTime
    attribute? :completed_at, Types::OptionalDateTime
    attribute? :assigned_at, Types::OptionalDateTime
    
    # Value Objects
    attribute :assignee, TaskAssignee.default { TaskAssignee.unassigned }
    attribute :tags, Types::TagArray
    attribute :labels, Types::Array.of(Types::String).default { [] }
    
    # Computed attributes using Maybe monad
    def overdue?
      Maybe(due_date).bind do |date|
        date < Date.current && status != 'done' ? Some(true) : None()
      end.value_or(false)
    end
    
    def urgent?
      priority == 'urgent' || overdue?
    end
    
    def completed?
      status == 'done'
    end
    
    def in_progress?
      status == 'in_progress'
    end
    
    def assigned?
      assignee.assigned?
    end
    
    # Safe date calculations using Maybe
    def days_until_due
      Maybe(due_date).bind do |date|
        Some((date - Date.current).to_i)
      end
    end
    
    def days_since_created
      (Date.current - created_at.to_date).to_i
    end
    
    def days_in_progress
      Maybe(started_at).bind do |start_time|
        end_time = completed_at || Time.current
        Some((end_time.to_date - start_time.to_date).to_i)
      end.value_or(0)
    end
    
    # Time tracking methods
    def estimated_vs_actual_ratio
      Maybe(estimated_hours).bind do |estimated|
        Maybe(actual_hours).bind do |actual|
          estimated > 0 ? Some(actual / estimated) : None()
        end
      end
    end
    
    def time_remaining
      Maybe(estimated_hours).bind do |estimated|
        Maybe(actual_hours).bind do |actual|
          remaining = estimated - actual
          remaining > 0 ? Some(remaining) : Some(0.0)
        end
      end
    end
    
    # Progress calculations
    def progress_by_time
      Maybe(estimated_hours).bind do |estimated|
        Maybe(actual_hours).bind do |actual|
          estimated > 0 ? Some((actual / estimated * 100).round) : None()
        end
      end.value_or(0)
    end
    
    def is_on_track?
      return nil unless estimated_hours && actual_hours && started_at
      
      days_planned = Maybe(due_date).bind do |due|
        Some((due - started_at.to_date).to_i)
      end.value_or(7)  # 기본 7일
      
      days_elapsed = days_in_progress
      expected_progress = days_elapsed.to_f / days_planned * 100
      
      completion_percentage >= expected_progress - 10  # 10% 허용 오차
    end
    
    # Status and priority styling
    def status_color
      {
        'todo' => 'gray',
        'in_progress' => 'blue', 
        'review' => 'yellow',
        'done' => 'green',
        'archived' => 'gray'
      }[status]
    end
    
    def priority_color
      {
        'low' => 'gray',
        'medium' => 'yellow',
        'high' => 'orange', 
        'urgent' => 'red'
      }[priority]
    end
    
    def priority_score
      {
        'low' => 1,
        'medium' => 2,
        'high' => 3,
        'urgent' => 4
      }[priority]
    end
    
    # Business logic helpers
    def can_be_started?
      status == 'todo'
    end
    
    def can_be_completed?
      %w[in_progress review].include?(status)
    end
    
    def can_be_reviewed?
      status == 'in_progress' && completion_percentage >= 90
    end
    
    def requires_attention?
      overdue? || (urgent? && !assigned?) || (assigned? && days_in_progress > 3 && completion_percentage < 30)
    end
    
    # Sprint information (using Maybe for safe access)
    def sprint_info
      Maybe(sprint_id).bind do |id|
        sprint = Sprint.cached_find(id)
        sprint ? Some({
          id: sprint.id.to_s,
          name: sprint.name,
          status: sprint.status,
          start_date: sprint.start_date,
          end_date: sprint.end_date
        }) : None()
      end
    end
    
    def in_active_sprint?
      sprint_info.bind do |info|
        info[:status] == 'active' ? Some(true) : None()
      end.value_or(false)
    end
    
    # Service context information
    def service_info
      Maybe(service_id).bind do |id|
        service = Service.cached_find(id)
        service ? Some({
          id: service.id.to_s,
          name: service.name,
          task_prefix: service.task_prefix
        }) : None()
      end
    end
    
    # Rich text and formatting
    def truncated_description(length = 100)
      Maybe(description).bind do |desc|
        desc.length > length ? Some(\"#{desc[0, length]}...\") : Some(desc)
      end.value_or('')
    end
    
    def formatted_title
      Maybe(task_id).bind do |tid|
        Some(\"[#{tid}] #{title}\")
      end.value_or(title)
    end
    
    # Factory methods with enhanced error handling
    def self.from_model(task)
      Try do
        assignee = TaskAssignee.from_user_id(task.assignee_id, task.organization)
        
        new(
          id: task.id.to_s,
          task_id: task.task_id,
          title: task.title,
          description: task.description,
          status: task.status,
          priority: task.priority,
          organization_id: task.organization_id,
          service_id: task.service_id,
          due_date: task.due_date,
          estimated_hours: task.estimated_hours,
          actual_hours: task.actual_hours,
          completion_percentage: task.completion_percentage || 0,
          position: task.position,
          assignee: assignee,
          tags: task.tags || [],
          labels: task.labels || [],
          created_at: task.created_at,
          updated_at: task.updated_at,
          started_at: task.started_at,
          completed_at: task.completed_at,
          assigned_at: task.assigned_at
        )
      end.to_result.value_or(nil)
    end
    
    def self.from_model!(task)
      result = from_model(task)
      raise \"Failed to create DTO from model: #{task.id}\" unless result
      result
    end
    
    # Serialization for API responses
    def to_api_hash
      {
        id: id,
        task_id: task_id,
        title: title,
        description: description,
        status: status,
        priority: priority,
        due_date: due_date,
        estimated_hours: estimated_hours,
        actual_hours: actual_hours,
        completion_percentage: completion_percentage,
        assignee: assignee.to_h,
        tags: tags,
        labels: labels,
        created_at: created_at.iso8601,
        updated_at: updated_at.iso8601,
        # Computed fields
        overdue: overdue?,
        urgent: urgent?,
        completed: completed?,
        days_until_due: days_until_due&.value,
        days_in_progress: days_in_progress,
        requires_attention: requires_attention?,
        # Styling
        status_color: status_color,
        priority_color: priority_color,
        priority_score: priority_score
      }.compact
    end
    
    def as_json(options = {})
      case options[:context]
      when :api
        to_api_hash
      when :minimal
        { id: id, title: title, status: status, assignee: assignee.display_name }
      else
        attributes.except(:assignee).merge(assignee: assignee.to_h)
      end
    end
  end
end