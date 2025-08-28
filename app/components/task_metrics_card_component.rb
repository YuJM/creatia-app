# frozen_string_literal: true

class TaskMetricsCardComponent < ViewComponent::Base
  def initialize(task:, task_metrics:)
    @task = task
    @task_metrics = task_metrics
  end

  private

  attr_reader :task, :task_metrics

  def progress_bar_color
    if task_metrics.completion_percentage >= 90
      "bg-green-600"
    elsif task_metrics.completion_percentage >= 50
      "bg-blue-600"
    else
      "bg-yellow-600"
    end
  end

  def efficiency_status_class
    if task_metrics.is_on_track?
      "bg-green-50 text-green-800"
    else
      "bg-yellow-50 text-yellow-800"
    end
  end

  def complexity_badge_class
    case task_metrics.complexity_level
    when 'low' then "bg-green-50 text-green-800"
    when 'medium' then "bg-yellow-50 text-yellow-800"
    when 'high' then "bg-orange-50 text-orange-800"
    when 'very_high' then "bg-red-50 text-red-800"
    else "bg-gray-50 text-gray-800"
    end
  end

  def time_status_color
    if task_metrics.overdue?
      "text-red-600"
    elsif task_metrics.efficiency_ratio >= 1.0
      "text-green-600"
    else
      "text-blue-600"
    end
  end

  def efficiency_status_text
    if task_metrics.is_on_track?
      "👍 예정대로 진행 중"
    else
      "⚠️ 일정 지연 위험"
    end
  end

  def complexity_description
    case task_metrics.complexity_level
    when 'low' then "🟢 간단한 작업"
    when 'medium' then "🟡 보통 작업" 
    when 'high' then "🟠 복잡한 작업"
    when 'very_high' then "🔴 매우 복잡한 작업"
    end
  end

  def progress_description
    remaining = task_metrics.remaining_percentage
    if remaining > 75
      "📋 시작 단계입니다"
    elsif remaining > 25
      "⚡ 진행 중입니다"
    elsif remaining > 0
      "🏁 거의 완료되었습니다"
    else
      "✅ 작업이 완료되었습니다"
    end
  end
end