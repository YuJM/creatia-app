# frozen_string_literal: true

# SprintMetricsSerializer - 스프린트 메트릭 정보 직렬화
class SprintMetricsSerializer < BaseSerializer
  # 메트릭 데이터
  attribute :metrics, if: proc { |data|
    data.is_a?(Hash) && data[:metrics]
  } do |data|
    metrics = data[:metrics]
    metrics.respond_to?(:to_h) ? metrics.to_h : metrics
  end
  
  # 사용자 친화적 설명
  attribute :user_friendly, if: proc { |data|
    data.is_a?(Hash) && data[:user_friendly]
  } do |data|
    data[:user_friendly]
  end
  
  # 트렌드 데이터
  attribute :trends, if: proc { |data|
    data.is_a?(Hash) && data[:trends]
  } do |data|
    data[:trends]
  end
  
  # 프로젝션
  attribute :projections, if: proc { |data|
    data.is_a?(Hash) && data[:projections]
  } do |data|
    data[:projections]
  end
end