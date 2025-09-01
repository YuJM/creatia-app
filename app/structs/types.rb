# frozen_string_literal: true

require 'dry-types'

module Types
  include Dry.Types()
  
  # 기본 타입들
  StrictString = Strict::String
  StrictInteger = Strict::Integer
  StrictFloat = Strict::Float
  StrictBool = Strict::Bool
  
  # ID 타입들 - MongoDB ObjectId 또는 UUID
  ID = String.constrained(format: /\A[0-9a-f]{24}\z/) # MongoDB ObjectId
  OptionalID = ID.optional
  
  # 날짜/시간 타입들
  Date = Params::Date
  # DateTime은 ActiveSupport::TimeWithZone, Time, DateTime, String 모두 처리 가능
  DateTime = Types::Any.constructor do |value|
    case value
    when ::String
      ::DateTime.parse(value)
    when ::Time, ::ActiveSupport::TimeWithZone
      value.to_datetime
    when ::DateTime
      value
    else
      value
    end
  end
  Time = Params::Time
  OptionalDate = Date.optional
  OptionalDateTime = DateTime.optional
  
  # 비즈니스 도메인 타입들
  Email = String.constrained(format: /@/)
  OptionalEmail = Email.optional
  
  # URL 타입
  URL = String.constrained(format: URI::DEFAULT_PARSER.make_regexp)
  OptionalURL = URL.optional
  
  # Task 관련 타입들
  TaskStatus = String.enum('todo', 'in_progress', 'review', 'done', 'archived')
  TaskPriority = String.enum('low', 'medium', 'high', 'urgent')
  
  # Sprint 관련 타입들  
  SprintStatus = String.enum('planning', 'active', 'completed', 'archived')
  
  # User 관련 타입들
  UserRole = String.enum('admin', 'member', 'viewer', 'guest')
  
  # 파일 크기 (바이트)
  FileSize = Integer.constrained(gteq: 0)
  
  # 포지티브 정수
  PositiveInteger = Integer.constrained(gt: 0)
  NonNegativeInteger = Integer.constrained(gteq: 0)
  
  # 퍼센트 (0-100)
  Percentage = Integer.constrained(gteq: 0, lteq: 100)
  
  # 컬러 코드
  ColorCode = String.enum('gray', 'red', 'yellow', 'green', 'blue', 'indigo', 'purple', 'pink')
  HexColor = String.constrained(format: /\A#[0-9a-fA-F]{6}\z/)
  
  # 태그 배열
  TagArray = Array.of(String).default { [] }
  
  # JSON 데이터
  JSONData = Hash.default { {} }
  
  # 조직 슬러그 (서브도메인용)
  OrganizationSlug = String.constrained(
    format: /\A[a-z0-9][a-z0-9-]*[a-z0-9]\z/,
    min_size: 2,
    max_size: 50
  )
  
  # GitHub 관련 타입들
  GitHubRepo = String.constrained(format: /\A[\w.-]+\/[\w.-]+\z/)
  GitHubBranch = String.constrained(format: /\A[^\s~^:?*\[\\]+\z/)
  
  # 시간 추정 (시간 단위)
  EstimatedHours = Float.constrained(gteq: 0.0, lteq: 999.0)
  OptionalEstimatedHours = EstimatedHours.optional
  
  # 좌표 (Kanban 보드 위치 등)
  Coordinate = PositiveInteger
  OptionalCoordinate = Coordinate.optional
end