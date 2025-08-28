# frozen_string_literal: true

# SprintPlanningSerializer - 스프린트 계획 정보 직렬화
class SprintPlanningSerializer < BaseSerializer
  # 성공 플래그
  attribute :success do
    true
  end
  
  # 스프린트 계획
  attribute :sprint_plan, if: proc { |data|
    data.is_a?(Hash) && data[:sprint_plan]
  } do |data|
    plan = data[:sprint_plan]
    plan.respond_to?(:to_h) ? plan.to_h : plan
  end
  
  # 의존성 분석
  attribute :dependency_analysis, if: proc { |data|
    data.is_a?(Hash) && data[:dependency_analysis]
  } do |data|
    data[:dependency_analysis]
  end
  
  # 리스크 평가
  attribute :risk_assessment, if: proc { |data|
    data.is_a?(Hash) && data[:risk_assessment]
  } do |data|
    assessment = data[:risk_assessment]
    assessment.respond_to?(:to_h) ? assessment.to_h : assessment
  end
  
  # 추천사항
  attribute :recommendations, if: proc { |data|
    data.is_a?(Hash) && data[:recommendations]
  } do |data|
    data[:recommendations]
  end
end