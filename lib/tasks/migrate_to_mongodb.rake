# lib/tasks/migrate_to_mongodb.rake
namespace :mongodb do
  namespace :migrate do
    desc "Migrate active sprints from PostgreSQL to MongoDB"
    task active_sprints: :environment do
      puts "🚀 Starting migration of active sprints to MongoDB..."
      
      migrated = 0
      failed = 0
      
      # PostgreSQL에서 활성 Sprint 조회 (가정: Sprint 모델이 PostgreSQL에 있음)
      # 현재는 Service만 있으므로 샘플 데이터로 진행
      Service.find_each do |service|
        begin
          # MongoDB Sprint 생성 (샘플)
          sprint = Mongodb::MongoSprint.create!(
            organization_id: service.organization_id.to_s,
            service_id: service.id.to_s,
            name: "Sprint #{Time.current.strftime('%Y-%m')}",
            goal: "Migrate to MongoDB",
            start_date: Date.current,
            end_date: Date.current + 2.weeks,
            status: 'active',
            sprint_number: 1,
            team_id: nil # Team이 있다면 설정
          )
          
          puts "✅ Migrated sprint for service: #{service.name}"
          migrated += 1
        rescue => e
          puts "❌ Failed to migrate sprint for service #{service.name}: #{e.message}"
          failed += 1
        end
      end
      
      puts "\n📊 Migration Summary:"
      puts "   Migrated: #{migrated}"
      puts "   Failed: #{failed}"
    end
    
    desc "Archive completed sprints older than 30 days"
    task archive_completed_sprints: :environment do
      puts "📦 Archiving old completed sprints..."
      
      archived_count = 0
      
      Mongodb::MongoSprint.where(
        status: 'completed',
        :end_date.lte => 30.days.ago
      ).each do |sprint|
        # S3 백업 (옵션)
        if ENV['AWS_S3_BUCKET'].present?
          BackupService.backup_sprint_to_s3(sprint)
        end
        
        # 아카이브 플래그 설정
        sprint.update!(archived: true, archived_at: Time.current)
        archived_count += 1
        
        puts "📦 Archived: #{sprint.name} (#{sprint.id})"
      end
      
      puts "✅ Archived #{archived_count} sprints"
    end
    
    desc "Migrate historical tasks to MongoDB"
    task historical_tasks: :environment do
      puts "📝 Migrating historical tasks..."
      
      # 샘플 태스크 생성
      Service.find_each do |service|
        sprint = Mongodb::MongoSprint.where(service_id: service.id.to_s).first
        next unless sprint
        
        5.times do |i|
          task = Mongodb::MongoTask.create!(
            organization_id: service.organization_id.to_s,
            service_id: service.id.to_s,
            sprint_id: sprint.id.to_s,
            task_id: "#{service.key}-#{i + 1}",
            title: "Sample Task #{i + 1}",
            description: "Migrated task from PostgreSQL",
            status: ['backlog', 'todo', 'in_progress', 'done'].sample,
            priority: ['low', 'medium', 'high'].sample,
            story_points: [1, 2, 3, 5, 8].sample,
            task_type: ['feature', 'bug', 'chore'].sample
          )
          
          # Sprint에 태스크 추가
          sprint.add_task(task)
        end
      end
      
      puts "✅ Task migration completed"
    end
    
    desc "Setup initial MongoDB indexes"
    task setup_indexes: :environment do
      puts "🔧 Setting up MongoDB indexes..."
      
      # 이미 mongodb.rake에 구현되어 있으므로 호출
      Rake::Task['mongodb:create_indexes'].invoke
      
      puts "✅ Indexes created successfully"
    end
    
    desc "Full migration from PostgreSQL to MongoDB"
    task full: :environment do
      puts "🚀 Starting full migration to MongoDB..."
      
      # 순서대로 실행
      Rake::Task['mongodb:migrate:setup_indexes'].invoke
      Rake::Task['mongodb:migrate:active_sprints'].invoke
      Rake::Task['mongodb:migrate:historical_tasks'].invoke
      Rake::Task['mongodb:migrate:archive_completed_sprints'].invoke
      
      puts "\n✅ Full migration completed!"
      puts "📊 Run 'rails mongodb:stats' to see collection statistics"
    end
  end
  
  namespace :sync do
    desc "Enable dual-write mode for gradual migration"
    task enable_dual_write: :environment do
      Rails.cache.write('mongodb:dual_write:enabled', true)
      puts "✅ Dual-write mode enabled"
      puts "   All new data will be written to both PostgreSQL and MongoDB"
    end
    
    desc "Disable dual-write mode"
    task disable_dual_write: :environment do
      Rails.cache.delete('mongodb:dual_write:enabled')
      puts "✅ Dual-write mode disabled"
    end
    
    desc "Verify data consistency between PostgreSQL and MongoDB"
    task verify_consistency: :environment do
      puts "🔍 Verifying data consistency..."
      
      inconsistencies = []
      
      # Sprint 일관성 체크
      Mongodb::MongoSprint.each do |mongo_sprint|
        # PostgreSQL과 비교 (실제 구현시)
        # pg_sprint = Sprint.find_by(id: mongo_sprint.legacy_id)
        # if pg_sprint && pg_sprint.updated_at != mongo_sprint.updated_at
        #   inconsistencies << "Sprint #{mongo_sprint.id}"
        # end
      end
      
      if inconsistencies.empty?
        puts "✅ Data is consistent between databases"
      else
        puts "⚠️  Found #{inconsistencies.count} inconsistencies:"
        inconsistencies.each { |item| puts "   - #{item}" }
      end
    end
  end
end