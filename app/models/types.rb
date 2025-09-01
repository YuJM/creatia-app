# frozen_string_literal: true

module Types
  include Dry.Types()
  
  # 기본 타입들
  StrippedString = Types::String.constructor(&:strip)
  Email = Types::String.constrained(format: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
  
  # Task 관련 타입들
  TaskStatus = Types::String.enum('todo', 'in_progress', 'review', 'done', 'archived')
  TaskPriority = Types::String.enum('low', 'medium', 'high', 'urgent')
  
  # Sprint 관련 타입들
  SprintStatus = Types::String.enum('planned', 'active', 'completed', 'cancelled')
  
  # 역할 타입들
  UserRole = Types::String.enum('user', 'admin', 'moderator')
  MembershipRole = Types::String.enum('owner', 'admin', 'member', 'viewer')
  
  # 날짜/시간 타입들
  DateTime = Types::DateTime
  Date = Types::Date
  
  # ID 타입들
  UUID = Types::String.constrained(format: /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
  MongoID = Types::String.constrained(format: /\A[0-9a-f]{24}\z/i)
end