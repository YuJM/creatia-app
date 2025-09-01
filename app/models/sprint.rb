# frozen_string_literal: true

# Sprint Model Alias for MongoDB Implementation
# This provides a clean interface while maintaining backward compatibility
# with the MongoDB-based execution data architecture.

class Sprint
  include Mongoid::Document
  include Mongoid::Timestamps
  
  # MongoDB 컬렉션 이름 설정
  store_in collection: "sprints"
  
  # Core References
  field :organization_id, type: String
  field :service_id, type: String
  field :created_by_id, type: String
  
  # Sprint Definition
  field :name, type: String
  field :goal, type: String
  field :status, type: String, default: 'planning'
  field :sprint_number, type: Integer
  
  # Timeline
  field :start_date, type: Date
  field :end_date, type: Date
  
  # Capacity
  field :planned_capacity, type: Float
  field :actual_capacity, type: Float
  
  # Sprint 모델의 편의 메소드들 추가
  def self.from_model(sprint)
    sprint
  end
end