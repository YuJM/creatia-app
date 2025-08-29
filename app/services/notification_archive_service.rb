# frozen_string_literal: true

# 알림 아카이빙 및 하이브리드 저장 전략 서비스
class NotificationArchiveService
  attr_reader :errors

  def initialize
    @errors = []
  end

  # 오래된 알림을 MongoDB로 아카이빙
  def archive_old_notifications(days_old = 30)
    cutoff_date = days_old.days.ago
    
    # Noticed gem의 알림 모델 (가정)
    # noticed_notifications 테이블의 오래된 레코드 조회
    notifications = Noticed::Notification
                    .where('created_at < ?', cutoff_date)
                    .includes(:event)
    
    Rails.logger.info "Found #{notifications.count} notifications to archive"
    
    result = NotificationLog.bulk_archive(notifications)
    
    if result[:failed] == 0
      # 성공적으로 아카이빙된 알림 삭제
      notifications.destroy_all
      Rails.logger.info "Successfully archived #{result[:archived]} notifications"
    else
      Rails.logger.warn "Archived #{result[:archived]} notifications with #{result[:failed]} failures"
    end
    
    result
  rescue => e
    Rails.logger.error "Archive failed: #{e.message}"
    @errors << e.message
    { archived: 0, failed: 0, error: e.message }
  end

  # 새 알림 생성시 MongoDB에도 동시 저장 (하이브리드 접근)
  def create_notification_with_log(recipient, type, params = {})
    notification = nil
    log = nil
    
    ActiveRecord::Base.transaction do
      # PostgreSQL에 실시간 알림 생성 (Noticed gem 사용)
      notification = create_postgresql_notification(recipient, type, params)
      
      # MongoDB에 로그 생성
      log = create_mongodb_log(notification, recipient, type, params)
    end
    
    { notification: notification, log: log }
  rescue => e
    Rails.logger.error "Failed to create notification: #{e.message}"
    @errors << e.message
    nil
  end

  # 알림 읽음 처리 (양쪽 모두 업데이트)
  def mark_as_read(notification_id)
    # PostgreSQL 업데이트
    notification = Noticed::Notification.find(notification_id)
    notification.mark_as_read!
    
    # MongoDB 업데이트
    log = NotificationLog.find_by(notification_id: notification_id)
    log&.mark_as_read!
    
    true
  rescue => e
    Rails.logger.error "Failed to mark as read: #{e.message}"
    @errors << e.message
    false
  end

  # 사용자별 알림 조회 (하이브리드)
  def get_user_notifications(user_id, options = {})
    include_archived = options[:include_archived] || false
    limit = options[:limit] || 20
    offset = options[:offset] || 0
    
    if include_archived
      # MongoDB에서 모든 알림 조회 (아카이브 포함)
      NotificationLog.by_recipient(user_id)
                    .recent
                    .limit(limit)
                    .skip(offset)
    else
      # PostgreSQL에서 최근 알림만 조회
      Noticed::Notification.where(recipient_id: user_id)
                          .order(created_at: :desc)
                          .limit(limit)
                          .offset(offset)
    end
  end

  # 알림 통계 (MongoDB 활용)
  def get_notification_statistics(user_id, period = :week)
    NotificationLog.statistics(user_id, period)
  end

  # 사용자 선호도 분석
  def analyze_user_preferences(user_id)
    NotificationLog.user_preferences_analysis(user_id)
  end

  # 조직 전체 알림 트렌드
  def organization_notification_trends(org_id, days = 30)
    NotificationLog.organization_trends(org_id, days)
  end

  # 알림 효과성 리포트
  def effectiveness_report(type = nil)
    NotificationLog.effectiveness_analysis(type)
  end

  # 배치 알림 발송 (대량 발송)
  def send_batch_notifications(recipients, type, params = {})
    batch_id = SecureRandom.uuid
    success_count = 0
    failed_count = 0
    
    recipients.each do |recipient|
      begin
        result = create_notification_with_log(
          recipient,
          type,
          params.merge(batch_id: batch_id)
        )
        
        success_count += 1 if result
      rescue => e
        failed_count += 1
        Rails.logger.error "Batch notification failed for recipient #{recipient.id}: #{e.message}"
      end
    end
    
    {
      batch_id: batch_id,
      total: recipients.count,
      success: success_count,
      failed: failed_count
    }
  end

  # 만료된 알림 정리
  def cleanup_expired_notifications
    expired_logs = NotificationLog.expired
    expired_count = expired_logs.count
    
    expired_logs.destroy_all
    
    Rails.logger.info "Cleaned up #{expired_count} expired notifications"
    expired_count
  end

  # 알림 재발송
  def retry_failed_notifications
    failed_notifications = NotificationLog.where(status: 'failed')
                                         .where(:retry_count.lt => 3)
    
    retry_count = 0
    
    failed_notifications.each do |log|
      if log.retry_send!
        # 실제 재발송 로직 구현
        retry_count += 1
      end
    end
    
    Rails.logger.info "Retried #{retry_count} failed notifications"
    retry_count
  end

  private

  def create_postgresql_notification(recipient, type, params)
    # Noticed gem을 사용한 알림 생성
    # 실제 구현은 프로젝트의 Noticed 설정에 따라 다름
    notification_class = type.constantize
    notification_class.with(params).deliver(recipient)
  rescue => e
    Rails.logger.error "PostgreSQL notification creation failed: #{e.message}"
    raise
  end

  def create_mongodb_log(notification, recipient, type, params)
    NotificationLog.create!(
      notification_id: notification&.id,
      recipient_id: recipient.id,
      recipient_type: recipient.class.name,
      organization_id: recipient.try(:organization_id) || recipient.try(:current_organization_id),
      type: type,
      title: params[:title],
      body: params[:body],
      action_url: params[:action_url],
      category: determine_category(type),
      priority: params[:priority] || 'normal',
      channels: params[:channels] || ['in_app'],
      params: params,
      status: 'sent',
      sent_at: Time.current
    )
  rescue => e
    Rails.logger.error "MongoDB log creation failed: #{e.message}"
    # MongoDB 실패시에도 PostgreSQL 알림은 유지
    nil
  end

  def determine_category(type)
    case type
    when /Task/
      'task'
    when /Comment/
      'comment'
    when /Mention/
      'mention'
    when /Sprint/
      'sprint'
    when /Team/
      'team'
    when /System/, /Alert/
      'system'
    else
      'general'
    end
  end
end