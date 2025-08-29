# frozen_string_literal: true

# 알림 배달을 처리하는 백그라운드 Job
class NotificationDeliveryJob < ApplicationJob
  queue_as :notifications

  # 재시도 전략
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(notification_id)
    notification = Notification.find(notification_id)
    return if notification.nil?

    # 이미 발송된 알림은 건너뛰기
    return if notification.sent? || notification.delivered? || notification.read?

    # 만료된 알림 처리
    if notification.expired?
      notification.update!(status: 'expired')
      return
    end

    # 사용자 설정 확인
    if should_skip_notification?(notification)
      notification.update!(status: 'skipped')
      return
    end

    # 채널별 발송
    send_to_channels(notification)
    
    # 상태 업데이트
    update_notification_status(notification)
    
    # 집계 데이터 업데이트
    update_analytics(notification)
  rescue => e
    handle_delivery_error(notification, e)
  end

  private

  def should_skip_notification?(notification)
    recipient = notification.recipient
    return false unless recipient

    # Do Not Disturb 모드 확인
    if recipient.respond_to?(:do_not_disturb?) && recipient.do_not_disturb?
      return true unless notification.do_not_disturb_override?
    end

    # 차단된 알림 타입 확인
    if recipient.respond_to?(:blocked_notification_types)
      return true if recipient.blocked_notification_types&.include?(notification.type)
    end

    false
  end

  def send_to_channels(notification)
    notification.channels.each do |channel|
      case channel
      when 'in_app'
        deliver_in_app(notification)
      when 'email'
        deliver_email(notification)
      when 'push'
        deliver_push(notification)
      when 'sms'
        deliver_sms(notification)
      when 'slack'
        deliver_slack(notification)
      when 'webhook'
        deliver_webhook(notification)
      end
    rescue => e
      log_channel_error(notification, channel, e)
    end
  end

  def deliver_in_app(notification)
    # In-app 알림은 이미 DB에 저장되어 있으므로 상태만 업데이트
    notification.channel_statuses['in_app'] = 'delivered'
    notification.delivered_at ||= Time.current
    
    # 실시간 알림 브로드캐스트 (ActionCable 또는 SSE)
    broadcast_notification(notification)
  end

  def deliver_email(notification)
    NotificationMailer.notification_email(notification).deliver_later
    notification.channel_statuses['email'] = 'sent'
  end

  def deliver_push(notification)
    # FCM 또는 APNS를 통한 푸시 알림
    push_config = notification.channel_config['push'] || {}
    
    if notification.recipient.respond_to?(:push_tokens)
      notification.recipient.push_tokens.each do |token|
        PushNotificationService.send(
          token: token,
          title: notification.title,
          body: notification.body,
          data: {
            notification_id: notification.id.to_s,
            action_url: notification.action_url
          },
          sound: push_config['sound'] || 'default',
          badge: push_config['badge']
        )
      end
    end
    
    notification.channel_statuses['push'] = 'sent'
  end

  def deliver_sms(notification)
    # SMS 발송 (Twilio 등 사용)
    return unless notification.recipient_email # 전화번호가 email 필드에 저장되어 있다고 가정
    
    SmsService.send(
      to: notification.recipient_email,
      body: "#{notification.title}: #{notification.body.truncate(140)}"
    )
    
    notification.channel_statuses['sms'] = 'sent'
  end

  def deliver_slack(notification)
    slack_config = notification.channel_config['slack'] || {}
    webhook_url = slack_config['webhook_url']
    channel = slack_config['channel'] || '#general'
    
    return unless webhook_url
    
    SlackNotifier.new(webhook_url).ping(
      channel: channel,
      text: notification.title,
      attachments: [{
        color: priority_color(notification.priority),
        text: notification.body,
        footer: 'Creatia',
        ts: notification.created_at.to_i
      }]
    )
    
    notification.channel_statuses['slack'] = 'sent'
  end

  def deliver_webhook(notification)
    webhook_config = notification.channel_config['webhook'] || {}
    url = webhook_config['url']
    
    return unless url
    
    HTTParty.post(url, 
      body: {
        notification: {
          id: notification.id.to_s,
          type: notification.type,
          title: notification.title,
          body: notification.body,
          priority: notification.priority,
          action_url: notification.action_url,
          metadata: notification.metadata
        }
      }.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'X-Notification-Type' => notification.type
      }
    )
    
    notification.channel_statuses['webhook'] = 'sent'
  end

  def broadcast_notification(notification)
    # ActionCable을 통한 실시간 알림
    NotificationChannel.broadcast_to(
      notification.recipient,
      {
        id: notification.id.to_s,
        type: notification.type,
        title: notification.title,
        body: notification.body,
        icon: notification.icon,
        action_url: notification.action_url,
        priority: notification.priority,
        created_at: notification.created_at
      }
    )
  rescue => e
    Rails.logger.error "Failed to broadcast notification: #{e.message}"
  end

  def update_notification_status(notification)
    # 모든 채널의 상태를 확인하여 전체 상태 결정
    statuses = notification.channel_statuses.values
    
    notification.status = if statuses.all? { |s| s == 'delivered' || s == 'read' }
                            'delivered'
                          elsif statuses.any? { |s| s == 'sent' || s == 'delivered' }
                            'sent'
                          elsif statuses.all? { |s| s == 'failed' }
                            'failed'
                          else
                            'partial'
                          end
    
    notification.sent_at ||= Time.current if notification.status != 'pending'
    notification.save!
  end

  def update_analytics(notification)
    # 비동기로 분석 데이터 업데이트
    NotificationAnalyticsJob.perform_later(
      notification.organization_id,
      notification.type,
      notification.category
    )
  end

  def handle_delivery_error(notification, error)
    Rails.logger.error "Notification delivery failed: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
    
    notification.error_logs << {
      error: error.message,
      timestamp: Time.current,
      backtrace: error.backtrace.first(5)
    }
    
    if notification.retry_count < 3
      notification.retry_count += 1
      notification.last_retry_at = Time.current
      notification.save!
      
      # 재시도 스케줄링
      NotificationDeliveryJob.set(wait: (notification.retry_count ** 2).minutes)
                            .perform_later(notification.id.to_s)
    else
      notification.status = 'failed'
      notification.save!
      
      # 실패 알림 (관리자에게)
      notify_delivery_failure(notification)
    end
  end

  def log_channel_error(notification, channel, error)
    notification.error_logs << {
      channel: channel,
      error: error.message,
      timestamp: Time.current
    }
    notification.channel_statuses[channel] = 'failed'
    notification.save!
  end

  def priority_color(priority)
    case priority
    when 'critical' then 'danger'
    when 'urgent', 'high' then 'warning'
    when 'normal' then 'good'
    else '#888888'
    end
  end

  def notify_delivery_failure(notification)
    # 중요한 알림 실패 시 관리자에게 알림
    return unless notification.high_priority?
    
    AdminMailer.notification_delivery_failed(notification).deliver_later
  end
end