# frozen_string_literal: true

# TaskMetricsSerializer - 태스크 메트릭 정보를 직렬화
class TaskMetricsSerializer < BaseSerializer
  # 메트릭 기본 정보
  attribute :metrics do |task_metrics|
    {
      estimated_hours: task_metrics.estimated_hours,
      actual_hours: task_metrics.actual_hours,
      completion_percentage: task_metrics.completion_percentage,
      complexity_score: task_metrics.complexity_score
    }
  end
  
  # 사용자 친화적인 설명
  attribute :user_friendly, if: proc { |task_metrics, params|
    params.is_a?(Hash) && params[:include_descriptions]
  } do |task_metrics, params|
    {
      efficiency_status: params[:efficiency_status],
      complexity_description: params[:complexity_description], 
      progress_description: params[:progress_description],
      time_status: params[:time_status]
    }
  end
end