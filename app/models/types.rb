# frozen_string_literal: true

module Types
  include Dry.Types()
  
  # 기본 타입들
  StrippedString = Types::String.constructor(&:strip)
  Email = Types::String.constrained(format: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
  
  # Task 관련 타입들 - structs/types.rb와 통합
  TaskStatus = Types::String.enum("todo", "in_progress", "review", "done", "blocked", "cancelled")
  TaskPriority = Types::String.enum("low", "medium", "high", "urgent")
  
  # Sprint 관련 타입들
  SprintStatus = Types::String.enum("planning", "active", "completed", "cancelled")
  
  # 역할 타입들
  UserRole = Types::String.enum("user", "admin", "moderator")
  MembershipRole = Types::String.enum("owner", "admin", "member", "viewer")
  
  # 날짜/시간 타입들
  DateTime = Types::DateTime
  Date = Types::Date
  
  # ID 타입들
  UUID = Types::String.constrained(format: /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
  MongoID = Types::String.constrained(format: /\A[0-9a-f]{24}\z/i)
  
  # 추가 타입들 (structs/types.rb에서 가져온 것들)
  StrictString = Strict::String
  StrictInteger = Strict::Integer
  StrictFloat = Strict::Float
  StrictBool = Strict::Bool
  
  # MongoDB ObjectId와 PostgreSQL UUID 모두 지원하는 ID 타입
  FlexibleID = String # MongoDB ObjectId나 PostgreSQL UUID 모두 허용
  OptionalFlexibleID = FlexibleID.optional
  
  # 비즈니스 도메인 타입들
  OptionalEmail = Email.optional
  URL = String.constrained(format: URI::DEFAULT_PARSER.make_regexp)
  OptionalURL = URL.optional
  
  # 시간 추정 (시간 단위)
  EstimatedHours = Float.constrained(gteq: 0.0, lteq: 999.0)
  OptionalEstimatedHours = EstimatedHours.optional
  
  # 포지티브 정수
  PositiveInteger = Integer.constrained(gt: 0)
  NonNegativeInteger = Integer.constrained(gteq: 0)
  
  # 퍼센트 (0-100)
  Percentage = Integer.constrained(gteq: 0, lteq: 100)
  
  # 컬러 코드
  ColorCode = String.enum("gray", "red", "yellow", "green", "blue", "indigo", "purple", "pink")
  HexColor = String.constrained(format: /\A#[0-9a-fA-F]{6}\z/)
  
  # 태그 배열
  TagArray = Array.of(String).default([].freeze)
  
  # JSON 데이터
  JSONData = Hash.default({}.freeze)
end