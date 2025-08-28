# CleanupOldNotificationsJob - 오래된 알림 정리
#
# 매일 새벽 3시에 실행되어 오래된 읽은 알림을 삭제
#
class CleanupOldNotificationsJob < ApplicationJob
  queue_as :maintenance
  
  # 정리 기준
  RETENTION_PERIODS = {
    read: 30.days,      # 읽은 알림은 30일 후 삭제
    unread: 90.days,    # 읽지 않은 알림은 90일 후 삭제
    system: 7.days      # 시스템 알림은 7일 후 삭제
  }.freeze
  
  def perform
    cleanup_read_notifications
    cleanup_unread_notifications
    cleanup_system_notifications
    cleanup_orphaned_records
    
    log_cleanup_results
  end
  
  private
  
  def cleanup_read_notifications
    @read_deleted = Noticed::Notification
      .read
      .where(created_at: ...RETENTION_PERIODS[:read].ago)
      .destroy_all
      .count
  end
  
  def cleanup_unread_notifications
    # 오래된 읽지 않은 알림 중 중요도가 낮은 것만 삭제
    @unread_deleted = Noticed::Notification
      .unread
      .where(created_at: ...RETENTION_PERIODS[:unread].ago)
      .where.not(type: ['TaskReminder', 'SecurityAlert'])  # 중요 알림은 보존
      .destroy_all
      .count
  end
  
  def cleanup_system_notifications
    @system_deleted = Noticed::Notification
      .where(type: 'SystemNotification')
      .where(created_at: ...RETENTION_PERIODS[:system].ago)
      .destroy_all
      .count
  end
  
  def cleanup_orphaned_records
    # 사용자가 삭제된 알림 정리
    @orphaned_deleted = Noticed::Notification
      .left_joins(:recipient)
      .where(users: { id: nil })
      .destroy_all
      .count
  end
  
  def log_cleanup_results
    total_deleted = @read_deleted + @unread_deleted + @system_deleted + @orphaned_deleted
    
    Rails.logger.info(
      "[NotificationCleanup] Deleted notifications - " \
      "Read: #{@read_deleted}, " \
      "Unread: #{@unread_deleted}, " \
      "System: #{@system_deleted}, " \
      "Orphaned: #{@orphaned_deleted}, " \
      "Total: #{total_deleted}"
    )
    
    # 정리 통계를 관리자에게 알림 (선택적)
    if total_deleted > 1000
      notify_admin_about_cleanup(total_deleted)
    end
  end
  
  def notify_admin_about_cleanup(total_deleted)
    User.admins.each do |admin|
      SystemNotifier.with(
        message: "알림 정리 완료: #{total_deleted}개의 오래된 알림이 삭제되었습니다.",
        type: :maintenance
      ).deliver(admin)
    end
  end
end