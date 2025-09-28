# frozen_string_literal: true

namespace :mongodb do
  desc "Migrate PomodoroSession data from PostgreSQL to MongoDB"
  task migrate_pomodoro_sessions: :environment do
    puts "Starting PomodoroSession migration to MongoDB..."
    
    # 통계 초기화
    total_count = PomodoroSession.count
    migrated_count = 0
    failed_count = 0
    failed_records = []
    
    puts "Total sessions to migrate: #{total_count}"
    
    # 배치 처리로 메모리 효율성 개선
    PomodoroSession.find_in_batches(batch_size: 100) do |batch|
      batch.each do |pg_session|
        begin
          # MongoDB 모델 생성
          mongo_session = PomodoroSessionMongo.new(
            task_id: pg_session.task_id,
            user_id: pg_session.user_id,
            organization_id: pg_session.task&.organization_id,
            session_count: pg_session.session_count || 0,
            status: pg_session.status,
            started_at: pg_session.started_at,
            ended_at: pg_session.ended_at,
            completed_at: pg_session.completed_at,
            paused_at: pg_session.paused_at,
            paused_duration: pg_session.paused_duration || 0,
            actual_duration: pg_session.actual_duration,
            planned_duration: PomodoroSessionMongo::WORK_DURATION.to_i,
            session_type: determine_session_type(pg_session),
            productivity_score: pg_session.productivity_score,
            created_at: pg_session.created_at,
            updated_at: pg_session.updated_at
          )
          
          # 추가 메타데이터
          mongo_session.metadata = {
            migrated_at: Time.current,
            original_id: pg_session.id,
            migration_version: '1.0'
          }
          
          if mongo_session.save
            migrated_count += 1
            print "." if migrated_count % 10 == 0
          else
            failed_count += 1
            failed_records << { id: pg_session.id, errors: mongo_session.errors.full_messages }
            print "F"
          end
        rescue => e
          failed_count += 1
          failed_records << { id: pg_session.id, error: e.message }
          print "E"
        end
      end
    end
    
    puts "\n\nMigration completed!"
    puts "=" * 50
    puts "Total records: #{total_count}"
    puts "Successfully migrated: #{migrated_count}"
    puts "Failed: #{failed_count}"
    
    if failed_records.any?
      puts "\nFailed records:"
      failed_records.each do |record|
        puts "  ID: #{record[:id]} - #{record[:error] || record[:errors].join(', ')}"
      end
    end
    
    # 검증
    puts "\n Verifying migration..."
    verify_migration
  end
  
  desc "Verify PomodoroSession migration"
  task verify_pomodoro_migration: :environment do
    verify_migration
  end
  
  desc "Rollback PomodoroSession migration"
  task rollback_pomodoro_migration: :environment do
    puts "Rolling back PomodoroSession migration..."
    
    if confirm_rollback?
      count = PomodoroSessionMongo.count
      PomodoroSessionMongo.destroy_all
      puts "Removed #{count} MongoDB records"
      puts "PostgreSQL records remain intact"
    else
      puts "Rollback cancelled"
    end
  end
  
  private
  
  def determine_session_type(pg_session)
    # 세션 타입 결정 로직
    return 'work' unless pg_session.completed?
    
    # 세션 시간으로 타입 추측
    duration = pg_session.actual_duration || 0
    
    case duration
    when 0..10.minutes.to_i
      'short_break'
    when 10.minutes.to_i..20.minutes.to_i
      'long_break'
    else
      'work'
    end
  end
  
  def verify_migration
    pg_count = PomodoroSession.count
    mongo_count = PomodoroSessionMongo.count
    
    puts "PostgreSQL records: #{pg_count}"
    puts "MongoDB records: #{mongo_count}"
    
    if pg_count == mongo_count
      puts "✅ Record counts match!"
    else
      puts "⚠️  Record count mismatch: #{pg_count - mongo_count} difference"
    end
    
    # 샘플 데이터 검증
    sample_pg = PomodoroSession.first(5)
    sample_pg.each do |pg_session|
      mongo_session = PomodoroSessionMongo.find_by(
        'metadata.original_id' => pg_session.id
      )
      
      if mongo_session
        puts "✅ Found migrated record for ID: #{pg_session.id}"
      else
        puts "❌ Missing migrated record for ID: #{pg_session.id}"
      end
    end
  end
  
  def confirm_rollback?
    print "Are you sure you want to rollback? This will delete all MongoDB records. (yes/no): "
    response = STDIN.gets.chomp.downcase
    response == 'yes' || response == 'y'
  end
end