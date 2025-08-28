# frozen_string_literal: true

# DashboardDataSerializer - 대시보드 데이터 직렬화
class DashboardDataSerializer < BaseSerializer
  # 성공 플래그
  attribute :success do
    true
  end
  
  # 데이터
  attribute :data, if: proc { |data|
    data.is_a?(Hash) && data[:data]
  } do |data|
    data[:data]
  end
  
  # 메트릭
  attribute :metrics, if: proc { |data|
    data.is_a?(Hash) && data[:metrics]
  } do |data|
    metrics = data[:metrics]
    metrics.respond_to?(:to_h) ? metrics.to_h : metrics
  end
  
  # 차트 데이터
  attribute :charts, if: proc { |data|
    data.is_a?(Hash) && data[:charts]
  } do |data|
    data[:charts]
  end
  
  # 마지막 업데이트 시간
  attribute :last_updated, if: proc { |data|
    data.is_a?(Hash) && data[:last_updated]
  } do |data|
    data[:last_updated]
  end
  
  # 활동 내역
  attribute :recent_activities, if: proc { |data|
    data.is_a?(Hash) && data[:recent_activities]
  } do |data|
    data[:recent_activities]
  end
  
  # 알림/경고
  attribute :alerts, if: proc { |data|
    data.is_a?(Hash) && data[:alerts]
  } do |data|
    data[:alerts]
  end
  
  # 활성 스프린트
  attribute :active_sprint, if: proc { |data|
    data.is_a?(Hash) && data[:active_sprint]
  } do |data|
    data[:active_sprint]
  end
  
  # 개인화 데이터
  attribute :personalization, if: proc { |data|
    data.is_a?(Hash) && data[:personalization]
  } do |data|
    data[:personalization]
  end
  
  # 위젯
  attribute :widgets, if: proc { |data|
    data.is_a?(Hash) && data[:widgets]
  } do |data|
    data[:widgets]
  end
end