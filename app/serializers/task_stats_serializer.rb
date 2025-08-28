# frozen_string_literal: true

# TaskStatsSerializer - 태스크 통계 정보를 직렬화
class TaskStatsSerializer < BaseSerializer
  # 통계 데이터
  attribute :total do |stats|
    stats[:total]
  end
  
  attribute :by_status do |stats|
    stats[:by_status]
  end
  
  attribute :by_priority do |stats|
    stats[:by_priority]
  end
  
  attribute :overdue do |stats|
    stats[:overdue]
  end
  
  attribute :due_soon do |stats|
    stats[:due_soon]
  end
  
  # 래핑된 형태로 반환
  root_key :data
  
  # 성공 플래그 추가
  attribute :success do
    true
  end
end