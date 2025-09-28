# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserDataResolver do
  let(:organization) { create(:organization) }
  let(:user1) { create(:user, name: "Alice", email: "alice@example.com") }
  let(:user2) { create(:user, name: "Bob", email: "bob@example.com") }
  
  let(:task1) do
    create(:task,
      organization_id: organization.id.to_s,
      assignee_id: user1.id.to_s,
      reviewer_id: user2.id.to_s
    )
  end
  
  let(:task2) do
    create(:task,
      organization_id: organization.id.to_s,
      assignee_id: user2.id.to_s
    )
  end
  
  let(:resolver) { described_class.new }

  before do
    create(:organization_membership, organization: organization, user: user1)
    create(:organization_membership, organization: organization, user: user2)
    Rails.cache.clear
  end

  describe '#resolve_for_tasks' do
    it 'returns enriched task data' do
      tasks = [task1, task2]
      
      result = resolver.resolve_for_tasks(tasks)

      expect(result).to be_success
      enriched_data = result.value!
      
      expect(enriched_data).to have(2).items
      
      # 첫 번째 Task 확인
      task1_data = enriched_data.find { |item| item[:task].id == task1.id }
      expect(task1_data).to be_present
      expect(task1_data[:assignee]).to be_a(Dto::UserDto)
      expect(task1_data[:reviewer]).to be_a(Dto::UserDto)
      expect(task1_data[:assignee].name).to eq("Alice")
      expect(task1_data[:reviewer].name).to eq("Bob")
      
      # 두 번째 Task 확인
      task2_data = enriched_data.find { |item| item[:task].id == task2.id }
      expect(task2_data).to be_present
      expect(task2_data[:assignee]).to be_a(Dto::UserDto)
      expect(task2_data[:reviewer]).to be_nil
      expect(task2_data[:assignee].name).to eq("Bob")
    end

    it 'handles empty task list' do
      result = resolver.resolve_for_tasks([])

      expect(result).to be_success
      expect(result.value!).to be_empty
    end
  end

  describe '#resolve_user_for_task' do
    context 'with fresh snapshot' do
      it 'uses snapshot data first' do
        # Fresh snapshot 생성
        snapshot = UserSnapshot.new(
          user_id: user1.id.to_s,
          name: "Alice Updated",
          email: user1.email,
          synced_at: 5.minutes.ago
        )
        task1.assignee_snapshot = snapshot
        task1.save!
        
        user_dto = resolver.resolve_user_for_task(task1, :assignee)
        
        expect(user_dto).to be_a(Dto::UserDto)
        expect(user_dto.name).to eq("Alice Updated")
        
        # 스냅샷 히트 통계 확인
        stats = resolver.stats
        expect(stats[:snapshot_hits]).to eq(1)
        expect(stats[:db_queries]).to eq(0)
      end
    end

    context 'with cache fallback' do
      it 'uses cached data when snapshot is stale' do
        # 캐시에 데이터 저장
        user_dto = Dto::UserDto.from_model(user1)
        Rails.cache.write("user_dto/#{user1.id}", user_dto, expires_in: 5.minutes)
        
        result_dto = resolver.resolve_user_for_task(task1, :assignee)
        
        expect(result_dto).to be_a(Dto::UserDto)
        expect(result_dto.name).to eq(user1.name)
        
        # 캐시 히트 통계 확인
        stats = resolver.stats
        expect(stats[:cache_hits]).to eq(1)
        expect(stats[:db_queries]).to eq(0)
      end
    end

    context 'with database fallback' do
      it 'queries database when cache and snapshot unavailable' do
        # 캐시와 스냅샷 모두 없는 상태
        user_dto = resolver.resolve_user_for_task(task1, :assignee)
        
        expect(user_dto).to be_a(Dto::UserDto)
        expect(user_dto.name).to eq(user1.name)
        expect(user_dto.email).to eq(user1.email)
        
        # DB 쿼리 통계 확인
        stats = resolver.stats
        expect(stats[:db_queries]).to eq(1)
        expect(stats[:cache_hits]).to eq(0)
      end
    end

    context 'with missing user' do
      it 'returns nil gracefully' do
        nonexistent_task = create(:task,
          organization_id: organization.id.to_s,
          assignee_id: "nonexistent_user_id"
        )
        
        user_dto = resolver.resolve_user_for_task(nonexistent_task, :assignee)
        
        expect(user_dto).to be_nil
      end
    end
  end

  describe '#resolve_users_batch' do
    it 'optimizes with cache usage' do
      user_ids = [user1.id.to_s, user2.id.to_s]
      
      # 첫 번째 사용자만 캐시에 저장
      user1_dto = Dto::UserDto.from_model(user1)
      Rails.cache.write("user_dto/#{user1.id}", user1_dto, expires_in: 5.minutes)
      
      resolved_users = resolver.resolve_users_batch(user_ids)
      
      expect(resolved_users).to have(2).items
      expect(resolved_users[user1.id.to_s]).to be_a(Dto::UserDto)
      expect(resolved_users[user2.id.to_s]).to be_a(Dto::UserDto)
      
      # 통계 확인: 1개는 캐시, 1개는 DB
      stats = resolver.stats
      expect(stats[:db_queries]).to eq(1)
    end
  end

  describe 'statistics tracking' do
    it 'tracks operations correctly' do
      initial_stats = resolver.stats
      expect(initial_stats[:snapshot_hits]).to eq(0)
      expect(initial_stats[:cache_hits]).to eq(0)
      expect(initial_stats[:db_queries]).to eq(0)
      
      # 여러 작업 수행
      resolver.resolve_user_for_task(task1, :assignee)  # DB 조회
      resolver.resolve_user_for_task(task1, :assignee)  # 캐시 히트
      
      updated_stats = resolver.stats
      expect(updated_stats[:db_queries]).to eq(1)
      expect(updated_stats[:cache_hits]).to eq(1)
    end

    it 'can reset statistics' do
      resolver.resolve_user_for_task(task1, :assignee)
      expect(resolver.stats[:db_queries]).to eq(1)
      
      resolver.reset_stats!
      reset_stats = resolver.stats
      expect(reset_stats[:db_queries]).to eq(0)
      expect(reset_stats[:cache_hits]).to eq(0)
    end
  end

  describe 'caching behavior' do
    it 'caches user data after database fetch' do
      # 첫 번째 호출 - DB에서 조회하고 캐시에 저장
      user_dto1 = resolver.resolve_user_for_task(task1, :assignee)
      expect(user_dto1).to be_a(Dto::UserDto)
      
      # 캐시에서 직접 확인
      cached_data = Rails.cache.read("user_dto/#{user1.id}")
      expect(cached_data).to be_present
      
      # 두 번째 호출 - 캐시에서 조회
      user_dto2 = resolver.resolve_user_for_task(task1, :assignee)
      expect(user_dto2.name).to eq(user_dto1.name)
      
      # 통계 확인
      stats = resolver.stats
      expect(stats[:db_queries]).to eq(1)
      expect(stats[:cache_hits]).to eq(1)
    end
  end
end