# frozen_string_literal: true

namespace :test do
  desc "Test UserSnapshot integration with Task"
  task snapshot: :environment do
    puts "🧪 UserSnapshot 통합 테스트 시작..."
    
    # 1. 테스트용 Organization과 User 준비
    org = Organization.first || Organization.create!(
      name: "Test Org",
      subdomain: "test",
      plan: "free"
    )
    
    user = User.first || User.create!(
      email: "test@example.com",
      password: "password123",
      name: "Test User",
      role: "user"
    )
    
    puts "✅ Organization: #{org.name}"
    puts "✅ User: #{user.name} (ID: #{user.id})"
    
    # 2. Sprint 생성
    sprint = Sprint.create!(
      organization_id: org.id.to_s,
      service_id: SecureRandom.uuid,
      name: "Test Sprint",
      status: "active"
    )
    
    puts "✅ Sprint: #{sprint.name}"
    
    # 3. Task 생성 (스냅샷 없이)
    task = Task.create!(
      organization_id: org.id.to_s,
      service_id: SecureRandom.uuid,
      sprint_id: sprint.id.to_s,
      title: "Test Task with Snapshot",
      description: "Testing UserSnapshot integration",
      status: "todo",
      priority: "medium",
      assignee_id: user.id.to_s,
      task_id: "TEST-001"
    )
    
    puts "\n📋 Task 생성됨: #{task.title}"
    puts "  - Assignee ID: #{task.assignee_id}"
    puts "  - Assignee Snapshot: #{task.assignee_snapshot ? '있음' : '없음'}"
    
    # 4. 스냅샷 동기화
    puts "\n🔄 스냅샷 동기화 중..."
    task.sync_assignee_snapshot!(user)
    
    puts "✅ 스냅샷 동기화 완료"
    puts "  - Snapshot Name: #{task.assignee_snapshot&.name}"
    puts "  - Snapshot Email: #{task.assignee_snapshot&.email}"
    puts "  - Snapshot Synced At: #{task.assignee_snapshot&.synced_at}"
    
    # 5. DTO 변환 테스트
    puts "\n📦 DTO 변환 테스트..."
    dto = Dto::TaskDto.from_model(task)
    
    puts "✅ DTO 생성 완료"
    puts "  - DTO ID: #{dto.id}"
    puts "  - DTO Title: #{dto.title}"
    puts "  - DTO Assignee Name: #{dto.assignee_name}"
    puts "  - DTO Assignee ID: #{dto.assignee_id}"
    
    # 6. 성능 비교
    puts "\n⚡ 성능 비교..."
    
    # Direct PostgreSQL 조회
    start_time = Time.current
    10.times do
      User.find_by(id: task.assignee_id)&.name
    end
    direct_time = Time.current - start_time
    puts "  - Direct PostgreSQL (10회): #{(direct_time * 1000).round(2)}ms"
    
    # Snapshot 조회
    start_time = Time.current
    10.times do
      task.assignee_snapshot&.name
    end
    snapshot_time = Time.current - start_time
    puts "  - Snapshot 조회 (10회): #{(snapshot_time * 1000).round(2)}ms"
    
    improvement = ((direct_time - snapshot_time) / direct_time * 100).round(1)
    puts "  - 성능 개선: #{improvement}%"
    
    # 7. User 정보 변경 시 동기화 테스트
    puts "\n🔄 User 정보 변경 시 동기화 테스트..."
    original_name = user.name
    user.update!(name: "Updated User Name")
    
    puts "  - User 이름 변경: #{original_name} → #{user.name}"
    puts "  - 스냅샷 (변경 전): #{task.assignee_snapshot.name}"
    
    # 수동 동기화
    task.sync_assignee_snapshot!(user)
    puts "  - 스냅샷 (동기화 후): #{task.assignee_snapshot.name}"
    
    # 8. 정리
    puts "\n🧹 테스트 데이터 정리..."
    task.destroy
    sprint.destroy
    
    puts "\n✅ UserSnapshot 통합 테스트 완료!"
  end
end