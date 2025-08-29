# frozen_string_literal: true

# 알림 아카이빙을 처리하는 백그라운드 Job
class NotificationArchiveJob < ApplicationJob
  queue_as :low_priority

  # 재시도 설정
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(action = 'archive_old', options = {})
    service = NotificationArchiveService.new
    
    case action
    when 'archive_old'
      archive_old_notifications(service, options)
    when 'cleanup_expired'
      cleanup_expired_notifications(service)
    when 'retry_failed'
      retry_failed_notifications(service)
    when 'generate_report'
      generate_effectiveness_report(service, options)
    else
      Rails.logger.error "Unknown action: #{action}"
    end
  end

  private

  def archive_old_notifications(service, options)
    days_old = options[:days_old] || 30
    
    Rails.logger.info "Starting notification archiving for notifications older than #{days_old} days"
    
    result = service.archive_old_notifications(days_old)
    
    if result[:error]
      Rails.logger.error "Archiving failed: #{result[:error]}"
    else
      Rails.logger.info "Archived #{result[:archived]} notifications, #{result[:failed]} failures"
      
      # Slack 또는 이메일로 결과 알림 (선택적)
      notify_admin_of_archive_result(result) if result[:failed] > 0
    end
  end

  def cleanup_expired_notifications(service)
    Rails.logger.info "Starting expired notification cleanup"
    
    count = service.cleanup_expired_notifications
    
    Rails.logger.info "Cleaned up #{count} expired notifications"
  end

  def retry_failed_notifications(service)
    Rails.logger.info "Starting failed notification retry"
    
    count = service.retry_failed_notifications
    
    Rails.logger.info "Retried #{count} failed notifications"
  end

  def generate_effectiveness_report(service, options)
    org_id = options[:organization_id]
    
    return unless org_id
    
    Rails.logger.info "Generating effectiveness report for organization #{org_id}"
    
    report = {
      overall: service.effectiveness_report,
      trends: service.organization_notification_trends(org_id, 30),
      timestamp: Time.current
    }
    
    # 리포트 저장 또는 전송
    save_or_send_report(org_id, report)
  end

  def notify_admin_of_archive_result(result)
    # 관리자에게 아카이빙 결과 알림
    # 실제 구현은 프로젝트의 알림 시스템에 따라 다름
  end

  def save_or_send_report(org_id, report)
    # 리포트를 파일로 저장하거나 이메일로 전송
    # 실제 구현은 요구사항에 따라 다름
  end
end