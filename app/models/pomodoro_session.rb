# frozen_string_literal: true

# PomodoroSession Model Alias for MongoDB Implementation
# This provides a clean interface while maintaining backward compatibility
# with the MongoDB-based execution data architecture.

class PomodoroSession < Mongodb::MongoPomodoroSession
  # 이 클래스는 MongoDB::MongoPomodoroSession의 깔끔한 인터페이스를 제공합니다.
  # 모든 기능은 MongoDB::MongoPomodoroSession에서 상속받으며,
  # 필요시 여기서 추가적인 인터페이스나 헬퍼 메소드를 정의할 수 있습니다.
  
  # MongoDB 컬렉션 이름 재정의 (필요시)
  # store_in collection: "pomodoro_sessions"
  
  # 추가적인 헬퍼 메소드나 인터페이스가 필요한 경우 여기에 정의
end