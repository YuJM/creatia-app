# frozen_string_literal: true

namespace :notifications do
  desc "Archive old notifications to MongoDB"
  task :archive, [:days] => :environment do |_task, args|
    days = (args[:days] || 30).to_i
    
    puts "Archiving notifications older than #{days} days..."
    
    service = NotificationArchiveService.new
    result = service.archive_old_notifications(days)
    
    if result[:error]
      puts "❌ Error: #{result[:error]}"
    else
      puts "✅ Archived: #{result[:archived]} notifications"
      puts "❌ Failed: #{result[:failed]} notifications" if result[:failed] > 0
    end
  end

  desc "Cleanup expired notifications"
  task cleanup_expired: :environment do
    puts "Cleaning up expired notifications..."
    
    service = NotificationArchiveService.new
    count = service.cleanup_expired_notifications
    
    puts "✅ Cleaned up #{count} expired notifications"
  end

  desc "Retry failed notifications"
  task retry_failed: :environment do
    puts "Retrying failed notifications..."
    
    service = NotificationArchiveService.new
    count = service.retry_failed_notifications
    
    puts "✅ Retried #{count} notifications"
  end

  desc "Generate notification statistics for a user"
  task :user_stats, [:user_id, :period] => :environment do |_task, args|
    user_id = args[:user_id].to_i
    period = (args[:period] || 'week').to_sym
    
    puts "Generating notification statistics for user #{user_id}..."
    
    service = NotificationArchiveService.new
    stats = service.get_notification_statistics(user_id, period)
    
    puts "\n📊 Notification Statistics (#{period})"
    puts "=" * 50
    puts "Total: #{stats[:total]}"
    puts "Unread: #{stats[:unread]}"
    puts "Read Rate: #{stats[:read_rate]}%"
    puts "Interaction Rate: #{stats[:interaction_rate]}%"
    
    puts "\nBy Type:"
    stats[:by_type].each do |type, count|
      puts "  #{type}: #{count}"
    end
    
    puts "\nBy Category:"
    stats[:by_category].each do |category, count|
      puts "  #{category}: #{count}"
    end
    
    puts "\nPeak Hours:"
    stats[:peak_hours].each do |hour, count|
      puts "  #{hour}:00 - #{count} notifications"
    end
  end

  desc "Generate organization notification trends"
  task :org_trends, [:org_id, :days] => :environment do |_task, args|
    org_id = args[:org_id].to_i
    days = (args[:days] || 30).to_i
    
    puts "Generating notification trends for organization #{org_id}..."
    
    service = NotificationArchiveService.new
    trends = service.organization_notification_trends(org_id, days)
    
    puts "\n📈 Organization Notification Trends (Last #{days} days)"
    puts "=" * 50
    
    trends.each do |date, stats|
      puts "#{date}: Sent: #{stats[:sent]}, Read: #{stats[:read]}, Interactions: #{stats[:interactions]}"
    end
    
    total_sent = trends.values.sum { |s| s[:sent] }
    total_read = trends.values.sum { |s| s[:read] }
    
    puts "\nSummary:"
    puts "Total Sent: #{total_sent}"
    puts "Total Read: #{total_read}"
    puts "Overall Read Rate: #{(total_read.to_f / total_sent * 100).round(1)}%" if total_sent > 0
  end

  desc "Generate effectiveness report"
  task :effectiveness, [:type] => :environment do |_task, args|
    type = args[:type]
    
    puts "Generating effectiveness report#{type ? " for #{type}" : ''}..."
    
    service = NotificationArchiveService.new
    report = service.effectiveness_report(type)
    
    puts "\n📊 Notification Effectiveness Report"
    puts "=" * 50
    puts "Delivery Rate: #{report[:delivery_rate]}%"
    puts "Read Rate: #{report[:read_rate]}%"
    puts "Interaction Rate: #{report[:interaction_rate]}%"
    puts "Avg Time to Read: #{report[:avg_time_to_read]} minutes"
    
    if report[:channel_performance].any?
      puts "\nChannel Performance:"
      report[:channel_performance].each do |channel, stats|
        puts "  #{channel}: #{stats[:success_rate]}% success rate"
      end
    end
  end

  desc "Schedule daily archiving (for cron)"
  task schedule_daily: :environment do
    NotificationArchiveJob.perform_later('archive_old', days_old: 30)
    NotificationArchiveJob.perform_later('cleanup_expired')
  end

  desc "Generate sample notification logs for testing"
  task generate_sample: :environment do
    puts "Generating sample notification logs..."
    
    users = User.limit(5)
    types = %w[TaskAssigned CommentMention SprintCompleted TeamInvite SystemAlert]
    categories = %w[task comment mention sprint team system]
    priorities = %w[low normal high urgent]
    
    100.times do |i|
      user = users.sample
      created_at = rand(30).days.ago
      
      log = NotificationLog.create!(
        recipient_id: user.id,
        organization_id: user.try(:organization_id) || 1,
        type: types.sample,
        title: "Sample Notification #{i}",
        body: "This is a sample notification body for testing purposes.",
        category: categories.sample,
        priority: priorities.sample,
        channels: ['in_app', 'email'].sample(rand(1..2)),
        status: ['sent', 'delivered', 'read'].sample,
        sent_at: created_at,
        delivered_at: created_at + rand(1..60).minutes,
        read_at: rand < 0.7 ? created_at + rand(1..180).minutes : nil,
        click_count: rand(0..5),
        created_at: created_at
      )
      
      print "." if (i + 1) % 10 == 0
    end
    
    puts "\n✅ Generated 100 sample notification logs"
  end

  desc "Verify notification system integrity"
  task verify: :environment do
    puts "Verifying notification system integrity..."
    
    # PostgreSQL 알림 수 (Noticed gem)
    pg_count = Noticed::Notification.count rescue 0
    
    # MongoDB 로그 수
    mongo_count = NotificationLog.count
    
    # 최근 7일 동안의 알림
    recent_mongo = NotificationLog.where(:created_at.gte => 7.days.ago).count
    
    puts "\n📊 Notification System Status"
    puts "=" * 50
    puts "PostgreSQL Notifications: #{pg_count}"
    puts "MongoDB Logs: #{mongo_count}"
    puts "Recent Logs (7 days): #{recent_mongo}"
    
    # 중복 체크
    if pg_count > 0
      duplicates = NotificationLog.where(:notification_id.ne => nil).distinct(:notification_id).count
      puts "Synchronized Records: #{duplicates}"
    end
    
    # 성능 체크
    start_time = Time.current
    NotificationLog.by_recipient(User.first&.id || 1).recent.limit(20).to_a
    query_time = Time.current - start_time
    
    puts "\nPerformance:"
    puts "Query Time (20 records): #{(query_time * 1000).round(2)}ms"
    
    if query_time > 0.1
      puts "⚠️  Warning: Query performance may need optimization"
    else
      puts "✅ Query performance is good"
    end
  end
end