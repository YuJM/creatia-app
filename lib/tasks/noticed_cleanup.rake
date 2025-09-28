# frozen_string_literal: true

namespace :noticed do
  desc "Backup and migrate Noticed gem data to MongoDB"
  task backup_and_migrate: :environment do
    puts "\n📦 Starting Noticed gem data migration to MongoDB..."
    puts "=" * 60
    
    # 통계 초기화
    stats = {
      events: 0,
      notifications: 0,
      migrated: 0,
      failed: 0
    }
    
    begin
      # 1. Noticed 테이블 존재 확인
      if ActiveRecord::Base.connection.table_exists?('noticed_events')
        stats[:events] = ActiveRecord::Base.connection.execute(
          "SELECT COUNT(*) FROM noticed_events"
        ).first['count'].to_i
        
        puts "Found #{stats[:events]} events in noticed_events table"
      end
      
      if ActiveRecord::Base.connection.table_exists?('noticed_notifications')
        stats[:notifications] = ActiveRecord::Base.connection.execute(
          "SELECT COUNT(*) FROM noticed_notifications"
        ).first['count'].to_i
        
        puts "Found #{stats[:notifications]} notifications in noticed_notifications table"
      end
      
      # 2. 데이터가 있으면 백업
      if stats[:events] > 0 || stats[:notifications] > 0
        backup_file = backup_noticed_data
        puts "✅ Backup created: #{backup_file}"
        
        # 3. MongoDB로 마이그레이션
        if stats[:notifications] > 0
          puts "\n📋 Migrating notifications to MongoDB..."
          migrate_notifications_to_mongodb(stats)
        end
      else
        puts "No Noticed data found to migrate"
      end
      
      # 4. 결과 출력
      puts "\n📊 Migration Summary:"
      puts "=" * 40
      puts "Total Events: #{stats[:events]}"
      puts "Total Notifications: #{stats[:notifications]}"
      puts "Successfully Migrated: #{stats[:migrated]}"
      puts "Failed: #{stats[:failed]}"
      
    rescue => e
      puts "❌ Error during migration: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end

  desc "Remove Noticed gem and clean up legacy code"
  task remove: :environment do
    puts "\n🧹 Removing Noticed gem and legacy code..."
    puts "=" * 60
    
    # 확인 프롬프트
    print "⚠️  This will remove all Noticed gem related code. Continue? (yes/no): "
    response = STDIN.gets.chomp
    
    unless response.downcase == 'yes'
      puts "Cleanup cancelled"
      exit 0
    end
    
    # 1. 레거시 파일 제거
    remove_noticed_files
    
    # 2. 마이그레이션 생성 (테이블 삭제)
    create_drop_tables_migration
    
    # 3. Gemfile 수정
    update_gemfile
    
    puts "\n✅ Noticed gem cleanup completed!"
    puts "Next steps:"
    puts "1. Run 'bundle install' to update dependencies"
    puts "2. Run 'rails db:migrate' to drop noticed tables"
    puts "3. Test the application thoroughly"
  end

  private

  def backup_noticed_data
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    backup_dir = Rails.root.join('backups', 'noticed')
    FileUtils.mkdir_p(backup_dir)
    backup_file = backup_dir.join("noticed_backup_#{timestamp}.sql")
    
    # pg_dump로 noticed 테이블만 백업
    db_config = ActiveRecord::Base.connection_db_config.configuration_hash
    
    cmd = [
      'pg_dump',
      '-h', db_config[:host] || 'localhost',
      '-p', (db_config[:port] || 5432).to_s,
      '-U', db_config[:username],
      '-d', db_config[:database],
      '-t', 'noticed_events',
      '-t', 'noticed_notifications',
      '--data-only',
      '--no-owner',
      '-f', backup_file.to_s
    ].compact
    
    # 환경 변수로 비밀번호 전달
    env = {}
    env['PGPASSWORD'] = db_config[:password] if db_config[:password]
    
    system(env, *cmd)
    
    backup_file
  rescue => e
    puts "Warning: Could not create pg_dump backup: #{e.message}"
    
    # 대체 방법: SQL로 백업
    backup_file = backup_dir.join("noticed_backup_#{timestamp}.json")
    
    data = {
      events: [],
      notifications: [],
      exported_at: Time.current
    }
    
    if ActiveRecord::Base.connection.table_exists?('noticed_events')
      data[:events] = ActiveRecord::Base.connection.execute(
        "SELECT * FROM noticed_events"
      ).to_a
    end
    
    if ActiveRecord::Base.connection.table_exists?('noticed_notifications')
      data[:notifications] = ActiveRecord::Base.connection.execute(
        "SELECT * FROM noticed_notifications"
      ).to_a
    end
    
    File.write(backup_file, JSON.pretty_generate(data))
    backup_file
  end

  def migrate_notifications_to_mongodb(stats)
    # noticed_notifications 테이블에서 데이터 가져오기
    notifications = ActiveRecord::Base.connection.execute(
      "SELECT * FROM noticed_notifications ORDER BY created_at"
    )
    
    notifications.each do |row|
      begin
        # MongoDB Notification 모델로 변환
        notification = Notification.new(
          recipient_id: row['recipient_id'],
          recipient_type: row['recipient_type'] || 'User',
          type: row['type'] || 'LegacyNotification',
          # params를 파싱 (JSONB 필드인 경우)
          title: extract_param(row['params'], 'title') || 'Legacy Notification',
          body: extract_param(row['params'], 'body') || extract_param(row['params'], 'message'),
          status: row['read_at'].present? ? 'read' : 'delivered',
          read_at: row['read_at'],
          created_at: row['created_at'],
          updated_at: row['updated_at'],
          metadata: {
            legacy_id: row['id'],
            legacy_event_id: row['event_id'],
            migrated_from: 'noticed_gem',
            migrated_at: Time.current
          }
        )
        
        if notification.save
          stats[:migrated] += 1
          print "." if stats[:migrated] % 50 == 0
        else
          stats[:failed] += 1
          puts "\nFailed to migrate notification #{row['id']}: #{notification.errors.full_messages}"
        end
      rescue => e
        stats[:failed] += 1
        puts "\nError migrating notification #{row['id']}: #{e.message}"
      end
    end
    
    puts # 새 줄
  end

  def extract_param(params_json, key)
    return nil unless params_json
    
    params = if params_json.is_a?(String)
               JSON.parse(params_json) rescue {}
             else
               params_json
             end
    
    params[key]
  rescue
    nil
  end

  def remove_noticed_files
    files_to_remove = [
      'app/notifiers/application_notifier.rb',
      'app/jobs/cleanup_old_notifications_job.rb',
      'app/services/notification_archive_service.rb'
    ]
    
    files_to_remove.each do |file|
      file_path = Rails.root.join(file)
      if File.exist?(file_path)
        File.delete(file_path)
        puts "❌ Removed: #{file}"
      end
    end
    
    # notifiers 디렉토리가 비어있으면 삭제
    notifiers_dir = Rails.root.join('app', 'notifiers')
    if Dir.exist?(notifiers_dir) && Dir.empty?(notifiers_dir)
      Dir.rmdir(notifiers_dir)
      puts "❌ Removed empty directory: app/notifiers/"
    end
  end

  def create_drop_tables_migration
    timestamp = Time.current.strftime('%Y%m%d%H%M%S')
    migration_file = Rails.root.join('db', 'migrate', "#{timestamp}_drop_noticed_tables.rb")
    
    migration_content = <<~RUBY
      # frozen_string_literal: true

      class DropNoticedTables < ActiveRecord::Migration[8.0]
        def up
          # Drop Noticed gem tables
          drop_table :noticed_notifications if table_exists?(:noticed_notifications)
          drop_table :noticed_events if table_exists?(:noticed_events)
          
          puts "✅ Dropped Noticed gem tables"
        end

        def down
          # Recreate tables if needed (rollback)
          # Note: This is a simplified version, actual schema might differ
          
          create_table :noticed_events do |t|
            t.string :type
            t.belongs_to :record, polymorphic: true
            t.jsonb :params
            t.integer :notifications_count
            t.timestamps
          end if !table_exists?(:noticed_events)

          create_table :noticed_notifications do |t|
            t.string :type
            t.belongs_to :event, null: false
            t.belongs_to :recipient, polymorphic: true, null: false
            t.datetime :read_at
            t.datetime :seen_at
            t.timestamps
          end if !table_exists?(:noticed_notifications)
          
          puts "⚠️  Recreated Noticed gem tables (rollback)"
        end
      end
    RUBY
    
    File.write(migration_file, migration_content)
    puts "✅ Created migration: #{migration_file}"
  end

  def update_gemfile
    gemfile_path = Rails.root.join('Gemfile')
    gemfile_content = File.read(gemfile_path)
    
    # Noticed gem 라인 제거
    updated_content = gemfile_content.gsub(/^gem ['"]noticed['"].*\n/, '')
    
    if gemfile_content != updated_content
      File.write(gemfile_path, updated_content)
      puts "✅ Removed 'noticed' gem from Gemfile"
    else
      puts "ℹ️  'noticed' gem not found in Gemfile"
    end
  end
end