# frozen_string_literal: true

require 'alba'

class SprintSerializer
  include Alba::Resource
  
  root_key :sprint, :sprints
  
  attributes :id, :name, :goal, :status
  attributes :created_at, :updated_at
  
  attribute :start_date do |sprint|
    sprint.start_date&.iso8601
  end
  
  attribute :end_date do |sprint|
    sprint.end_date&.iso8601
  end
  
  attribute :velocity do |sprint|
    sprint.velocity
  end
  
  attribute :capacity do |sprint|
    sprint.capacity
  end
  
  attribute :progress do |sprint|
    sprint.progress_percentage if sprint.respond_to?(:progress_percentage)
  end
  
  nested :schedule do
    attribute :daily_standup_time do |sprint|
      sprint.daily_standup_time&.strftime("%H:%M") if sprint.respond_to?(:daily_standup_time)
    end
    
    attribute :retrospective_time do |sprint|
      sprint.retrospective_meeting_time&.iso8601 if sprint.respond_to?(:retrospective_meeting_time)
    end
    
    attribute :review_time do |sprint|
      sprint.review_meeting_time&.iso8601 if sprint.respond_to?(:review_meeting_time)
    end
    
    attribute :working_hours do |sprint|
      sprint.working_hours_config if sprint.respond_to?(:working_hours_config)
    end
  end
  
  nested :stats do
    attribute :total_tasks do |sprint|
      sprint.tasks.count if sprint.respond_to?(:tasks)
    end
    
    attribute :completed_tasks do |sprint|
      sprint.tasks.where(status: 'completed').count if sprint.respond_to?(:tasks)
    end
    
    attribute :total_story_points do |sprint|
      sprint.tasks.sum(:story_points) if sprint.respond_to?(:tasks)
    end
    
    attribute :completed_story_points do |sprint|
      sprint.tasks.where(status: 'completed').sum(:story_points) if sprint.respond_to?(:tasks)
    end
  end
end