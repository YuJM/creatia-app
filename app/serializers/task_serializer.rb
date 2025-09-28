# frozen_string_literal: true

require 'alba'

class TaskSerializer
  include Alba::Resource
  
  root_key :task, :tasks
  
  attributes :id, :task_id, :title, :description, :status, :priority
  attributes :story_points, :sequence_number
  attributes :created_at, :updated_at, :completed_at
  
  attribute :deadline do |task|
    task.deadline&.iso8601
  end
  
  attribute :start_time do |task|
    task.start_time&.iso8601
  end
  
  attribute :business_hours_remaining do |task|
    task.business_hours_until_deadline if task.respond_to?(:business_hours_until_deadline)
  end
  
  attribute :urgency_level do |task|
    task.urgency_level.to_s if task.respond_to?(:urgency_level)
  end
  
  attributes :github_issue_number, :github_issue_url
  attributes :github_pr_number, :github_pr_url, :github_branch_name
  
  nested :metadata do
    attribute :is_overdue do |task|
      task.overdue? if task.respond_to?(:overdue?)
    end
    
    attribute :progress do |task|
      task.progress || 0 if task.respond_to?(:progress)
    end
  end
end