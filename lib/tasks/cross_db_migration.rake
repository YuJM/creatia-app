# frozen_string_literal: true

namespace :cross_db do
  desc "Setup indexes for cross-database operations"
  task setup_indexes: :environment do
    puts "🔧 MongoDB 인덱스 설정 시작..."
    
    # Task 컬렉션 인덱스
    Task.create_indexes(
      { organization_id: 1, assignee_id: 1 },
      { organization_id: 1, reviewer_id: 1 },
      { assignee_id: 1 },
      { reviewer_id: 1 },
      { 'assignee_snapshot.synced_at': 1 },
      { 'reviewer_snapshot.synced_at': 1 }
    )
    
    puts "✅ MongoDB 인덱스 설정 완료"
  end
  
  desc "Sync all user snapshots for existing tasks"
  task sync_all_snapshots: :environment do
    puts "🔄 모든 Task의 User 스냅샷 동기화 시작..."
    
    start_time = Time.current
    total_tasks = Task.count
    processed = 0
    failed = 0
    
    # 모든 User를 미리 로드
    users = User.all.index_by(&:id)
    puts "👥 총 #{users.size}명의 User 로드 완료"
    
    # 배치 단위로 Task 처리 (Mongoid)
    Task.all.each_slice(100) do |tasks|
      tasks.each do |task|
        begin
          # Assignee 스냅샷 동기화
          if task.assignee_id.present?
            user = users[task.assignee_id.to_i]
            if user
              task.sync_assignee_snapshot!(user)
            else
              puts "⚠️  User #{task.assignee_id} not found for Task #{task.id}"
            end
          end
          
          # Reviewer 스냅샷 동기화
          if task.reviewer_id.present?
            user = users[task.reviewer_id.to_i]
            if user
              task.sync_reviewer_snapshot!(user)
            else
              puts "⚠️  User #{task.reviewer_id} not found for Task #{task.id}"
            end
          end
          
          processed += 1
        rescue => e
          failed += 1
          puts "❌ Task #{task.id} 동기화 실패: #{e.message}"
        end
      end
      
      # 진행 상황 출력
      progress = (processed.to_f / total_tasks * 100).round(2)
      print "\r📊 진행률: #{progress}% (#{processed}/#{total_tasks})"
    end
    
    elapsed_time = Time.current - start_time
    
    puts "\n\n✅ 스냅샷 동기화 완료!"
    puts "📈 통계:"
    puts "  - 전체 Task: #{total_tasks}개"
    puts "  - 성공: #{processed - failed}개"
    puts "  - 실패: #{failed}개"
    puts "  - 소요 시간: #{elapsed_time.round(2)}초"
  end
  
  desc "Sync snapshots for a specific organization"
  task :sync_organization, [:subdomain] => :environment do |t, args|
    subdomain = args[:subdomain]
    
    unless subdomain
      puts "❌ 조직 서브도메인을 입력해주세요"
      puts "사용법: rake cross_db:sync_organization[subdomain]"
      exit 1
    end
    
    organization = Organization.find_by(subdomain: subdomain)
    
    unless organization
      puts "❌ 조직을 찾을 수 없습니다: #{subdomain}"
      exit 1
    end
    
    puts "🏢 조직 '#{organization.name}' 스냅샷 동기화 시작..."
    
    service = CrossDatabaseSyncService.instance
    synced_count = service.sync_organization_snapshots(organization)
    
    puts "✅ #{synced_count}개 Task 동기화 완료"
  end
  
  desc "Clean up stale snapshots"
  task cleanup_stale_snapshots: :environment do
    puts "🧹 오래된 스냅샷 정리 시작..."
    
    service = CrossDatabaseSyncService.instance
    cleaned_count = service.cleanup_stale_snapshots(7.days)
    
    puts "✅ #{cleaned_count}개 스냅샷 정리 완료"
  end
  
  desc "Health check for cross-database sync"
  task health_check: :environment do
    puts "🏥 Cross-Database 동기화 상태 확인..."
    
    service = CrossDatabaseSyncService.instance
    health = service.health_check
    
    puts "\n📊 동기화 상태:"
    puts "  - 상태: #{health[:healthy] ? '✅ 정상' : '❌ 문제 발생'}"
    puts "  - 총 동기화: #{health[:stats][:total_synced]}개"
    puts "  - 실패 동기화: #{health[:stats][:failed_syncs]}개"
    puts "  - 마지막 동기화: #{health[:stats][:last_sync_at] || '없음'}"
    puts "  - 오래된 스냅샷: #{health[:stale_snapshots_count]}개"
    puts "  - 누락된 스냅샷: #{health[:missing_snapshots_count]}개"
    
    if health[:missing_snapshots_count] > 0
      puts "\n⚠️  누락된 스냅샷이 있습니다. 'rake cross_db:sync_all_snapshots' 실행을 권장합니다."
    end
  end
  
  desc "Benchmark snapshot performance"
  task benchmark_performance: :environment do
    puts "⚡ 성능 벤치마크 시작..."
    
    # 테스트용 Task 샘플
    sample_tasks = Task.limit(100).to_a
    
    if sample_tasks.empty?
      puts "❌ 테스트할 Task가 없습니다"
      exit 1
    end
    
    puts "\n📊 Direct PostgreSQL 조회 (N+1 쿼리):"
    start_time = Time.current
    sample_tasks.each do |task|
      if task.assignee_id
        User.find_by(id: task.assignee_id)&.name
      end
    end
    direct_time = Time.current - start_time
    puts "  소요 시간: #{(direct_time * 1000).round(2)}ms"
    
    puts "\n📊 스냅샷 기반 조회:"
    start_time = Time.current
    sample_tasks.each do |task|
      task.assignee_name
    end
    snapshot_time = Time.current - start_time
    puts "  소요 시간: #{(snapshot_time * 1000).round(2)}ms"
    
    puts "\n📊 배치 프리로딩:"
    start_time = Time.current
    Task.sync_stale_snapshots(sample_tasks)
    sample_tasks.each do |task|
      task.assignee_name
    end
    batch_time = Time.current - start_time
    puts "  소요 시간: #{(batch_time * 1000).round(2)}ms"
    
    puts "\n📈 성능 비교:"
    puts "  - Direct PostgreSQL: 기준"
    puts "  - 스냅샷 기반: #{((direct_time - snapshot_time) / direct_time * 100).round(1)}% 개선"
    puts "  - 배치 프리로딩: #{((direct_time - batch_time) / direct_time * 100).round(1)}% 개선"
  end
  
  desc "Analyze organization data"
  task :analyze_organization, [:subdomain] => :environment do |t, args|
    subdomain = args[:subdomain]
    
    unless subdomain
      puts "❌ 조직 서브도메인을 입력해주세요"
      exit 1
    end
    
    organization = Organization.find_by(subdomain: subdomain)
    
    unless organization
      puts "❌ 조직을 찾을 수 없습니다: #{subdomain}"
      exit 1
    end
    
    puts "📊 조직 '#{organization.name}' 분석..."
    
    # Task 통계
    total_tasks = Task.where(organization_id: organization.id.to_s).count
    tasks_with_assignee = Task.where(organization_id: organization.id.to_s, :assignee_id.ne => nil).count
    tasks_with_reviewer = Task.where(organization_id: organization.id.to_s, :reviewer_id.ne => nil).count
    
    # 스냅샷 통계
    tasks_with_assignee_snapshot = Task.where(
      organization_id: organization.id.to_s,
      :assignee_snapshot.ne => nil
    ).count
    
    tasks_with_reviewer_snapshot = Task.where(
      organization_id: organization.id.to_s,
      :reviewer_snapshot.ne => nil
    ).count
    
    # 스냅샷 신선도
    fresh_snapshots = Task.where(organization_id: organization.id.to_s).select(&:snapshots_fresh?).count
    
    puts "\n📈 Task 통계:"
    puts "  - 전체 Task: #{total_tasks}개"
    puts "  - Assignee 있는 Task: #{tasks_with_assignee}개"
    puts "  - Reviewer 있는 Task: #{tasks_with_reviewer}개"
    
    puts "\n📸 스냅샷 통계:"
    puts "  - Assignee 스냅샷: #{tasks_with_assignee_snapshot}개"
    puts "  - Reviewer 스냅샷: #{tasks_with_reviewer_snapshot}개"
    puts "  - 신선한 스냅샷: #{fresh_snapshots}개"
    
    if tasks_with_assignee > tasks_with_assignee_snapshot
      missing = tasks_with_assignee - tasks_with_assignee_snapshot
      puts "\n⚠️  #{missing}개 Task의 Assignee 스냅샷이 누락되었습니다"
    end
  end
end