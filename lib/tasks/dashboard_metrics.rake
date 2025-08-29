# frozen_string_literal: true

namespace :dashboard do
  desc "Calculate daily dashboard metrics"
  task calculate_daily: :environment do
    puts "Calculating daily dashboard metrics..."
    DashboardMetricsAggregationJob.perform_now('daily')
    puts "Daily metrics calculation completed!"
  end

  desc "Calculate weekly dashboard metrics"
  task calculate_weekly: :environment do
    puts "Calculating weekly dashboard metrics..."
    DashboardMetricsAggregationJob.perform_now('weekly')
    puts "Weekly metrics calculation completed!"
  end

  desc "Calculate monthly dashboard metrics"
  task calculate_monthly: :environment do
    puts "Calculating monthly dashboard metrics..."
    DashboardMetricsAggregationJob.perform_now('monthly')
    puts "Monthly metrics calculation completed!"
  end

  desc "Calculate all dashboard metrics"
  task calculate_all: :environment do
    puts "Calculating all dashboard metrics..."
    DashboardMetricsAggregationJob.perform_now('all')
    puts "All metrics calculation completed!"
  end

  desc "Recalculate metrics for a specific date range"
  task :recalculate, [:start_date, :end_date] => :environment do |_task, args|
    start_date = Date.parse(args[:start_date])
    end_date = Date.parse(args[:end_date])
    
    puts "Recalculating metrics from #{start_date} to #{end_date}..."
    
    (start_date..end_date).each do |date|
      print "Processing #{date}... "
      DashboardMetricsAggregationJob.perform_now('daily', date)
      puts "✓"
    end
    
    puts "Recalculation completed!"
  end

  desc "Schedule daily metrics calculation (for cron)"
  task schedule_daily: :environment do
    # 매일 오전 2시에 실행
    DashboardMetricsAggregationJob.perform_later('all')
  end

  desc "Clean up old metrics data"
  task :cleanup, [:days] => :environment do |_task, args|
    days = (args[:days] || 90).to_i
    cutoff_date = days.days.ago
    
    puts "Cleaning up metrics older than #{cutoff_date}..."
    
    count = DashboardMetrics.where(:date.lt => cutoff_date).destroy_all
    
    puts "Removed #{count} old metric records"
  end

  desc "Generate sample metrics for testing"
  task generate_sample: :environment do
    puts "Generating sample metrics..."
    
    # 지난 30일간의 샘플 데이터 생성
    30.times do |i|
      date = i.days.ago.to_date
      print "Generating for #{date}... "
      
      Organization.find_each do |org|
        metrics = DashboardMetrics.find_or_initialize_by(
          organization_id: org.id,
          date: date,
          period_type: 'daily'
        )
        
        # 랜덤 샘플 데이터
        metrics.tasks_created = rand(5..20)
        metrics.tasks_completed = rand(3..15)
        metrics.tasks_in_progress = rand(10..30)
        metrics.pomodoro_sessions_completed = rand(10..50)
        metrics.productivity_score = rand(60..95)
        metrics.team_velocity = rand(20..80)
        metrics.completion_rate = rand(40..90)
        
        metrics.save!
      end
      
      puts "✓"
    end
    
    puts "Sample metrics generation completed!"
  end

  desc "Verify metrics integrity"
  task verify: :environment do
    puts "Verifying metrics integrity..."
    
    errors = []
    
    # 최근 7일 데이터 검증
    7.times do |i|
      date = i.days.ago.to_date
      
      Organization.find_each do |org|
        metrics = DashboardMetrics.by_organization(org.id)
                                 .where(date: date, period_type: 'daily')
                                 .first
        
        if metrics.nil?
          errors << "Missing daily metrics for Organization #{org.id} on #{date}"
        elsif metrics.calculated_at < 24.hours.ago
          errors << "Stale metrics for Organization #{org.id} on #{date}"
        end
      end
    end
    
    if errors.any?
      puts "Found #{errors.count} issues:"
      errors.each { |error| puts "  - #{error}" }
    else
      puts "✅ All metrics are valid and up to date!"
    end
  end
end