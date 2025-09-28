# frozen_string_literal: true

namespace :notifications do
  desc "Migrate existing PostgreSQL notifications to MongoDB"
  task migrate_to_mongodb: :environment do
    puts "Starting notification migration from PostgreSQL to MongoDB..."
    
    # 통계 초기화
    total = 0
    migrated = 0
    failed = 0
    skipped = 0
    
    # Noticed gem 알림이 있는지 확인
    if defined?(Noticed::Notification)
      total = Noticed::Notification.count
      puts "Found #{total} notifications to migrate"
      
      # 배치 처리
      Noticed::Notification.find_in_batches(batch_size: 100) do |batch|
        batch.each do |pg_notification|
          begin
            # 이미 마이그레이션된 알림인지 확인
            if Notification.where(notification_id: pg_notification.id).exists?
              skipped += 1
              next
            end
            
            # MongoDB 알림 생성
            mongo_notification = migrate_single_notification(pg_notification)
            
            if mongo_notification.persisted?
              migrated += 1
              print "."
            else
              failed += 1
              print "F"
              puts "\nFailed to migrate notification #{pg_notification.id}: #{mongo_notification.errors.full_messages}"
            end
          rescue => e
            failed += 1
            print "E"
            puts "\nError migrating notification #{pg_notification.id}: #{e.message}"
          end
        end
        
        # 진행 상황 표시
        puts "\nProgress: #{migrated + failed + skipped}/#{total}"
      end
    else
      puts "Noticed::Notification not found. Skipping PostgreSQL migration."
    end
    
    # 결과 출력
    puts "\n" + "=" * 50
    puts "Migration Complete!"
    puts "Total: #{total}"
    puts "Migrated: #{migrated}"
    puts "Failed: #{failed}"
    puts "Skipped: #{skipped}"
    puts "=" * 50
  end

  desc "Verify notification migration integrity"
  task verify_migration: :environment do
    puts "Verifying notification migration..."
    
    if defined?(Noticed::Notification)
      pg_count = Noticed::Notification.count
      mongo_count = Notification.count
      
      puts "PostgreSQL notifications: #{pg_count}"
      puts "MongoDB notifications: #{mongo_count}"
      
      # 샘플 검증
      sample_size = [100, pg_count].min
      sample_notifications = Noticed::Notification.limit(sample_size)
      
      matched = 0
      mismatched = []
      
      sample_notifications.each do |pg_notification|
        mongo_notification = Notification.find_by(notification_id: pg_notification.id)
        
        if mongo_notification && verify_notification_match(pg_notification, mongo_notification)
          matched += 1
        else
          mismatched << pg_notification.id
        end
      end
      
      puts "\nSample verification (#{sample_size} records):"
      puts "Matched: #{matched}"
      puts "Mismatched: #{mismatched.count}"
      
      if mismatched.any?
        puts "Mismatched IDs: #{mismatched.first(10).join(', ')}#{mismatched.count > 10 ? '...' : ''}"
      end
    else
      puts "Noticed::Notification not found. Cannot verify migration."
    end
  end

  desc "Rollback notification migration"
  task rollback_migration: :environment do
    puts "Rolling back notification migration..."
    
    print "Are you sure you want to delete all MongoDB notifications? (yes/no): "
    response = STDIN.gets.chomp
    
    if response.downcase == 'yes'
      count = Notification.count
      Notification.destroy_all
      puts "Deleted #{count} MongoDB notifications"
    else
      puts "Rollback cancelled"
    end
  end

  desc "Sync new notifications continuously"
  task sync_notifications: :environment do
    puts "Starting continuous notification sync..."
    
    loop do
      sync_recent_notifications
      sleep 60 # 1분마다 동기화
    end
  end

  private

  def migrate_single_notification(pg_notification)
    # PostgreSQL 알림 데이터 추출
    recipient = pg_notification.recipient
    event = pg_notification.event
    
    # 알림 타입 결정
    notification_type = determine_notification_type(event)
    
    # 파라미터 추출
    params = extract_notification_params(pg_notification)
    
    # MongoDB 알림 생성
    Notification.create!(
      notification_id: pg_notification.id, # 원본 ID 저장
      recipient_id: recipient&.id,
      recipient_type: recipient&.class&.name || 'User',
      recipient_email: recipient&.email,
      organization_id: recipient&.try(:organization_id),
      type: notification_type,
      title: params[:title] || generate_title(event),
      body: params[:body] || generate_body(event),
      category: determine_category(notification_type),
      priority: params[:priority] || 'normal',
      status: pg_notification.read_at.present? ? 'read' : 'delivered',
      read_at: pg_notification.read_at,
      created_at: pg_notification.created_at,
      updated_at: pg_notification.updated_at,
      # 추가 필드들
      sender_id: params[:sender_id],
      sender_name: params[:sender_name],
      action_url: params[:action_url],
      related_type: params[:related_type],
      related_id: params[:related_id],
      metadata: params[:metadata] || {}
    )
  end

  def determine_notification_type(event)
    case event.class.name
    when /TaskAssigned/
      'TaskAssignedNotification'
    when /TaskCompleted/
      'TaskCompletedNotification'
    when /CommentMention/
      'CommentMentionNotification'
    when /CommentReply/
      'CommentReplyNotification'
    when /SprintStarted/
      'SprintStartedNotification'
    when /SprintCompleted/
      'SprintCompletedNotification'
    when /TeamInvite/
      'TeamInvitationNotification'
    else
      'GeneralNotification'
    end
  end

  def determine_category(notification_type)
    case notification_type
    when /Task/
      'task'
    when /Comment/
      'comment'
    when /Sprint/
      'sprint'
    when /Team/
      'team'
    when /System/
      'system'
    else
      'general'
    end
  end

  def extract_notification_params(pg_notification)
    params = {}
    
    # Noticed gem의 params 구조에 따라 데이터 추출
    if pg_notification.respond_to?(:params)
      notice_params = pg_notification.params
      
      params[:title] = notice_params[:title]
      params[:body] = notice_params[:body] || notice_params[:message]
      params[:priority] = notice_params[:priority]
      params[:action_url] = notice_params[:action_url] || notice_params[:url]
      params[:sender_id] = notice_params[:sender_id]
      params[:sender_name] = notice_params[:sender_name]
      params[:related_type] = notice_params[:related_type]
      params[:related_id] = notice_params[:related_id]
      params[:metadata] = notice_params[:metadata] || {}
    end
    
    params
  end

  def generate_title(event)
    event.class.name.underscore.humanize
  end

  def generate_body(event)
    "You have a new notification"
  end

  def verify_notification_match(pg_notification, mongo_notification)
    return false unless mongo_notification
    
    # 주요 필드 일치 확인
    mongo_notification.notification_id == pg_notification.id &&
      mongo_notification.recipient_id == pg_notification.recipient_id &&
      mongo_notification.created_at.to_i == pg_notification.created_at.to_i
  end

  def sync_recent_notifications
    return unless defined?(Noticed::Notification)
    
    # 최근 1시간 내 생성된 알림 동기화
    recent_notifications = Noticed::Notification.where('created_at > ?', 1.hour.ago)
    
    recent_notifications.each do |pg_notification|
      next if Notification.where(notification_id: pg_notification.id).exists?
      
      begin
        migrate_single_notification(pg_notification)
        puts "Synced notification #{pg_notification.id}"
      rescue => e
        puts "Failed to sync notification #{pg_notification.id}: #{e.message}"
      end
    end
  end
end