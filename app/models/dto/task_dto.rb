# frozen_string_literal: true

require 'dry-struct'
require 'ostruct'

module Dto
  # Task 데이터 전송 객체
  # MongoDB 모델을 View에서 사용하기 위한 DTO
  class TaskDto < Dry::Struct
    transform_keys(&:to_sym)
    
    # 필수 속성들
    attribute :id, Types::String
    attribute :title, Types::String
    attribute :status, Types::TaskStatus
    attribute :priority, Types::TaskPriority
    attribute :organization_id, Types::String
    
    # 선택적 속성들
    attribute? :description, Types::String.optional
    attribute? :due_date, Types::Date.optional
    attribute? :assignee_id, Types::String.optional
    attribute? :assignee_name, Types::String.optional
    attribute? :assignee_avatar, Types::String.optional
    attribute? :sprint_id, Types::String.optional
    attribute? :sprint_name, Types::String.optional
    attribute? :estimated_hours, Types::Float.optional
    attribute? :actual_hours, Types::Float.optional
    attribute? :completion_percentage, Types::Integer.default(0)
    attribute? :tags, Types::Array.of(Types::String).default([].freeze)
    attribute? :created_at, Types::DateTime
    attribute? :updated_at, Types::DateTime
    
    # 계산된 속성들
    def overdue?
      due_date && due_date < Date.current && status != 'done'
    end
    
    def urgent?
      priority == 'urgent' || overdue?
    end
    
    # Assignee 관련 헬퍼 메소드
    def assignee
      return nil unless assignee_id.present?
      
      # OpenStruct를 사용하여 assignee 객체 생성
      # name이 없으면 임시로 "User"를 사용
      display_name = assignee_name.presence || "User #{assignee_id.split('-').first}"
      
      OpenStruct.new(
        id: assignee_id,
        name: display_name,
        email: display_name, # View가 email을 기대하므로 name을 email로도 제공
        avatar_url: assignee_avatar,
        present?: true
      )
    end
    
    def completed?
      status == 'done'
    end
    
    def in_progress?
      status == 'in_progress'
    end
    
    def assigned?
      assignee_id.present?
    end
    
    def days_until_due
      return nil unless due_date
      (due_date - Date.current).to_i
    end
    
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
    
    # Factory method to create from MongoDB model
    def self.from_model(task)
      assignee = task.assignee_id ? User.cached_find(task.assignee_id) : nil
      sprint = task.sprint_id ? Sprint.find_by(id: task.sprint_id) : nil
      
      new(
        id: task.id.to_s,
        title: task.title,
        description: task.description,
        status: task.status || 'backlog',
        priority: task.priority || 'medium',
        organization_id: task.organization_id,
        due_date: task.due_date,
        assignee_id: task.assignee_id,
        assignee_name: task.assignee_name || assignee&.name,
        assignee_avatar: assignee&.avatar_url,
        sprint_id: task.sprint_id,
        sprint_name: sprint&.name,
        estimated_hours: task.respond_to?(:original_estimate_hours) ? task.original_estimate_hours : task.estimated_hours,
        actual_hours: task.respond_to?(:time_spent_hours) ? task.time_spent_hours : task.actual_hours,
        completion_percentage: task.respond_to?(:completion_percentage) ? task.completion_percentage : 0,
        tags: task.tags || [],
        created_at: task.created_at,
        updated_at: task.updated_at
      )
    end
  end
end