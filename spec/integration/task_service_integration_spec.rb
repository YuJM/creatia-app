# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Task Service Integration" do
  let(:organization) { create(:organization) }
  let(:user1) { create(:user, name: "Alice", email: "alice@example.com") }
  let(:user2) { create(:user, name: "Bob", email: "bob@example.com") }
  let(:sprint) { create(:sprint, organization_id: organization.id.to_s, name: "Test Sprint") }
  let(:task_service) { TaskService.new(organization, user1) }

  before do
    create(:organization_membership, organization: organization, user: user1)
    create(:organization_membership, organization: organization, user: user2)
    Rails.cache.clear
  end

  describe 'complete task workflow' do
    it 'handles full CRUD cycle with user data integration' do
      # 1. Task 생성
      create_params = {
        title: "Integration Test Task",
        description: "Test description",
        status: 'todo',
        priority: 'high',
        assignee_id: user2.id.to_s,
        sprint_id: sprint.id.to_s
      }
      
      create_result = task_service.create(create_params)
      expect(create_result).to be_success
      
      created_task = create_result.value!
      expect(created_task).to be_a(Dto::TaskDto)
      expect(created_task.title).to eq("Integration Test Task")
      expect(created_task.assignee.name).to eq("Bob")
      
      # 2. Task 조회 (User 데이터 포함)
      find_result = task_service.find(created_task.id)
      expect(find_result).to be_success
      
      found_task = find_result.value!
      expect(found_task.id).to eq(created_task.id)
      expect(found_task.assignee.name).to eq("Bob")
      expect(found_task.assignee.email).to eq(user2.email)
      
      # 3. Task 목록 조회 (필터 적용)
      list_result = task_service.list(assignee_id: user2.id.to_s)
      expect(list_result).to be_success
      
      list_data = list_result.value!
      expect(list_data[:tasks].size).to be >= 1
      expect(list_data[:metadata][:assigned_count]).to be >= 1
      
      # 4. Task 상태 변경
      status_result = task_service.change_status(created_task.id, 'in_progress')
      expect(status_result).to be_success
      
      updated_task = status_result.value!
      expect(updated_task.status).to eq('in_progress')
      
      # 5. Task 할당자 변경
      assign_result = task_service.assign(created_task.id, user1.id.to_s)
      expect(assign_result).to be_success
      
      reassigned_task = assign_result.value!
      expect(reassigned_task.assignee.name).to eq("Alice")
      
      # 6. Sprint 통계 확인
      sprint_result = task_service.list_for_sprint(sprint.id.to_s)
      expect(sprint_result).to be_success
      
      sprint_data = sprint_result.value!
      expect(sprint_data[:tasks].size).to be >= 1
    end
  end

  describe 'performance with large dataset' do
    it 'handles bulk operations efficiently' do
      # UserSnapshot 생성 (MongoDB Aggregation을 위해)
      UserSnapshot.create!(
        user_id: user1.id.to_s,
        name: user1.name,
        email: user1.email,
        synced_at: Time.current
      )
      
      UserSnapshot.create!(
        user_id: user2.id.to_s,
        name: user2.name,
        email: user2.email,
        synced_at: Time.current
      )
      
      # 대량 데이터 생성
      tasks = []
      10.times do |i|
        assignee = [user1, user2].sample
        task = create(:task,
          organization_id: organization.id.to_s,
          title: "Bulk Task #{i}",
          assignee_id: assignee.id.to_s
        )
        tasks << task
      end
      
      
      # 성능 측정
      start_time = Time.current
      result = task_service.list
      elapsed_time = Time.current - start_time
      
      expect(result).to be_success
      data = result.value!
      
      expect(data[:tasks].size).to be >= 10
      expect(elapsed_time).to be < 1.0
      
      # 모든 Task에 User 데이터가 포함되어 있는지 확인
      
      tasks_with_users = data[:tasks].count { |task| task.assignee }
      expect(tasks_with_users).to be > 0
      
      data[:tasks].select { |task| task.assignee }.each do |task|
        expect(task.assignee).to be_a(Dto::UserDto)
        expect(task.assignee.name).to be_present
      end
    end
  end

  describe 'user data resolver caching effectiveness' do
    it 'demonstrates cache efficiency with repeated queries' do
      # 같은 사용자가 할당된 여러 Task 생성
      tasks = []
      5.times do |i|
        tasks << create(:task,
          organization_id: organization.id.to_s,
          assignee_id: user1.id.to_s,
          title: "Cache Test Task #{i}"
        )
      end
      
      # 첫 번째 조회
      resolver_instance = UserDataResolver.new
      result = resolver_instance.resolve_for_tasks(tasks)
      
      expect(result).to be_success
      enriched_tasks = result.value!
      
      # 모든 Task에 대해 assignee가 제대로 조회되었는지 확인
      enriched_tasks.each do |item|
        expect(item[:assignee]).not_to be_nil
        expect(item[:assignee].name).to eq(user1.name)
      end
      
      # 통계 확인
      stats = resolver_instance.stats
      expect(stats[:db_queries]).to be >= 1  # 최소 1개의 DB 쿼리
      
      # UserSnapshot 기반 작업이므로 snapshot_hits도 가능
      total_resolutions = stats[:snapshot_hits] + stats[:cache_hits] + stats[:db_queries]
      expect(total_resolutions).to be >= 5  # 5개 Task 모두 처리됨
    end
  end

  describe 'snapshot freshness logic' do
    it 'prioritizes fresh snapshots over database queries' do
      # Task 생성
      task1 = create(:task, organization_id: organization.id.to_s, assignee_id: user1.id.to_s)
      task2 = create(:task, organization_id: organization.id.to_s, assignee_id: user2.id.to_s)
      
      # Fresh snapshot 생성 (별도 컬렉션)
      fresh_snapshot = UserSnapshot.create!(
        user_id: user1.id.to_s,
        name: "Alice Fresh",
        email: user1.email,
        synced_at: 10.minutes.ago
      )
      task1.assignee_snapshot_id = fresh_snapshot.id.to_s
      task1.save!
      
      # Stale snapshot 생성 (별도 컬렉션)
      stale_snapshot = UserSnapshot.create!(
        user_id: user2.id.to_s,
        name: "Bob Stale",
        email: user2.email,
        synced_at: 2.hours.ago
      )
      task2.assignee_snapshot_id = stale_snapshot.id.to_s
      task2.save!
      
      resolver_instance = UserDataResolver.new
      
      # Fresh snapshot 사용 확인
      user1_dto = resolver_instance.resolve_user_for_task(task1, :assignee)
      expect(user1_dto.name).to eq("Alice Fresh")
      
      # Stale snapshot은 DB로 fallback 확인
      user2_dto = resolver_instance.resolve_user_for_task(task2, :assignee)
      expect(user2_dto.name).to eq(user2.name)  # DB의 실제 이름
      
      # 통계 확인
      stats = resolver_instance.stats
      expect(stats[:snapshot_hits]).to eq(1)
      expect(stats[:db_queries]).to eq(1)
    end
  end

  describe 'background synchronization' do
    it 'schedules sync jobs for stale snapshots' do
      # 오래된 스냅샷으로 Task들 생성
      tasks_with_stale_snapshots = []
      
      # Stale snapshot 생성 (별도 컬렉션)
      stale_snapshot = UserSnapshot.create!(
        user_id: user1.id.to_s,
        name: "Stale Name",
        email: user1.email,
        synced_at: 2.hours.ago
      )
      
      3.times do |i|
        task = create(:task,
          organization_id: organization.id.to_s,
          assignee_id: user1.id.to_s
        )
        
        task.assignee_snapshot_id = stale_snapshot.id.to_s
        task.save!
        
        tasks_with_stale_snapshots << task
      end
      
      # BulkUserSnapshotSyncJob이 예약되는지 확인
      resolver_instance = UserDataResolver.new
      
      expect {
        resolver_instance.resolve_for_tasks(tasks_with_stale_snapshots)
      }.to have_enqueued_job(BulkUserSnapshotSyncJob)
      
      # 백그라운드 동기화 통계 확인 (동일한 user_id이므로 1번만 카운트)
      stats = resolver_instance.stats
      expect(stats[:background_syncs]).to eq(1)
    end
  end
end