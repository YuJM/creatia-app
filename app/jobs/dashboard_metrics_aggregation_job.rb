# frozen_string_literal: true

# 대시보드 메트릭을 주기적으로 집계하는 백그라운드 Job
class DashboardMetricsAggregationJob < ApplicationJob
  queue_as :low_priority

  # 재시도 설정
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(period = 'daily', date = nil)
    date ||= Date.current
    
    Rails.logger.info "Starting DashboardMetrics aggregation for #{period} on #{date}"
    
    case period
    when 'daily'
      aggregate_daily_metrics(date)
    when 'weekly'
      aggregate_weekly_metrics(date)
    when 'monthly'
      aggregate_monthly_metrics(date)
    when 'all'
      aggregate_all_periods(date)
    else
      Rails.logger.error "Invalid period: #{period}"
    end
    
    Rails.logger.info "Completed DashboardMetrics aggregation for #{period} on #{date}"
  end

  private

  def aggregate_daily_metrics(date)
    start_time = Time.current
    
    # 일일 메트릭 계산
    DashboardMetrics.calculate_daily_metrics(date)
    
    # 실행 시간 로깅
    duration = Time.current - start_time
    Rails.logger.info "Daily metrics aggregation completed in #{duration.round(2)} seconds"
    
    # 성능 모니터링
    if duration > 60 # 1분 이상 걸리면 경고
      Rails.logger.warn "Daily aggregation took longer than expected: #{duration.round(2)} seconds"
    end
  end

  def aggregate_weekly_metrics(date)
    start_time = Time.current
    
    # 주간 메트릭 계산
    DashboardMetrics.calculate_weekly_metrics(date)
    
    duration = Time.current - start_time
    Rails.logger.info "Weekly metrics aggregation completed in #{duration.round(2)} seconds"
  end

  def aggregate_monthly_metrics(date)
    start_time = Time.current
    
    # 월간 메트릭 계산
    DashboardMetrics.calculate_monthly_metrics(date)
    
    duration = Time.current - start_time
    Rails.logger.info "Monthly metrics aggregation completed in #{duration.round(2)} seconds"
  end

  def aggregate_all_periods(date)
    aggregate_daily_metrics(date)
    
    # 주간 집계는 월요일에만
    if date.monday?
      aggregate_weekly_metrics(date)
    end
    
    # 월간 집계는 매월 1일에만
    if date.day == 1
      aggregate_monthly_metrics(date)
    end
  end
end