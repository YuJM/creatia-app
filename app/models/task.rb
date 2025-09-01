# frozen_string_literal: true

# Task Model Alias for MongoDB Implementation
# This provides a clean interface while maintaining backward compatibility
# with the MongoDB-based execution data architecture.

class Task
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # MongoDB 컬렉션 이름 설정
  store_in collection: "tasks"
  
  # Constants
  STATUSES = %w[todo in_progress review done blocked cancelled].freeze
  PRIORITIES = %w[low medium high urgent].freeze
  TASK_TYPES = %w[feature bug chore spike epic].freeze
  
  # Mongodb::MongoTask의 모든 필드 정의를 포함
  # (실제로는 MongoTask로부터 데이터를 읽고 쓰지만, 직접 정의하여 _type 문제 회피)
  
  # Core References (PostgreSQL UUIDs)
  field :organization_id, type: String
  field :service_id, type: String
  field :sprint_id, type: String
  field :milestone_id, type: String
  
  # Task Identification
  field :task_id, type: String
  field :external_id, type: String
  
  # Task Core
  field :title, type: String
  field :description, type: String
  field :task_type, type: String, default: 'feature'
  
  # Assignment
  field :assignee_id, type: String
  field :assignee_name, type: String
  field :reviewer_id, type: String
  field :team_id, type: String
  
  # Status & Priority
  field :status, type: String, default: 'todo'
  field :priority, type: String, default: 'medium'
  field :position, type: Integer, default: 0
  
  # Time Tracking
  field :estimated_hours, type: Float
  field :actual_hours, type: Float, default: 0.0
  field :remaining_hours, type: Float
  field :time_entries, type: Array, default: []
  
  # Dates
  field :due_date, type: Date
  field :start_date, type: Date
  field :completed_at, type: DateTime
  
  # Tags & Labels
  field :tags, type: Array, default: []
  field :labels, type: Array, default: []
  
  # Task 모델의 편의 메소드들 추가
  def self.from_model(task)
    task
  end
end