# frozen_string_literal: true

# MongoDB 자동 백업 Job
class MongodbBackupJob < ApplicationJob
  queue_as :low_priority

  def perform(backup_type = 'scheduled')
    Rails.logger.info "Starting MongoDB #{backup_type} backup"
    
    backup = MongodbBackup.new
    result = backup.create_backup(backup_type)
    
    if result[:success]
      Rails.logger.info "MongoDB backup completed: #{result[:file]}"
      
      # 백업 성공 알림
      notify_backup_success(result, backup_type)
      
      # 오래된 백업 정리
      cleanup_old_backups(backup_type)
    else
      Rails.logger.error "MongoDB backup failed: #{result[:error]}"
      
      # 백업 실패 알림
      notify_backup_failure(result[:error], backup_type)
    end
  end

  private

  def cleanup_old_backups(backup_type)
    # 백업 타입별 보관 기간
    retention_days = case backup_type
                    when 'daily' then 7
                    when 'weekly' then 30
                    when 'monthly' then 90
                    else 30
                    end
    
    backup = MongodbBackup.new
    cleanup_result = backup.cleanup_old_backups(retention_days)
    
    Rails.logger.info "Cleaned up #{cleanup_result[:deleted]} old backups, freed #{cleanup_result[:space_freed]}"
  end

  def notify_backup_success(result, backup_type)
    # Slack 알림
    if Rails.application.config.slack_webhook_url
      send_slack_notification(
        "✅ MongoDB #{backup_type} backup completed",
        "File: #{result[:file]}\nSize: #{result[:size]}\nDuration: #{result[:duration]}s",
        'good'
      )
    end
    
    # 이메일 알림 (주간/월간 백업만)
    if %w[weekly monthly].include?(backup_type) && defined?(AdminMailer)
      AdminMailer.backup_success_notification(result, backup_type).deliver_later
    end
  end

  def notify_backup_failure(error, backup_type)
    # Slack 알림
    if Rails.application.config.slack_webhook_url
      send_slack_notification(
        "❌ MongoDB #{backup_type} backup failed",
        "Error: #{error}",
        'danger'
      )
    end
    
    # 이메일 알림
    if defined?(AdminMailer)
      AdminMailer.backup_failure_notification(error, backup_type).deliver_later
    end
  end

  def send_slack_notification(title, text, color)
    require 'net/http'
    require 'json'
    
    webhook_url = Rails.application.config.slack_webhook_url
    
    payload = {
      attachments: [{
        color: color,
        title: title,
        text: text,
        footer: 'MongoDB Backup System',
        ts: Time.current.to_i
      }]
    }
    
    uri = URI(webhook_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    request.content_type = 'application/json'
    request.body = payload.to_json
    
    http.request(request)
  rescue => e
    Rails.logger.error "Failed to send Slack notification: #{e.message}"
  end
end