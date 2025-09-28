# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TaskQueryService do
  let(:organization) { create(:organization) }
  let(:user1) { create(:user, name: "Alice", email: "alice@example.com") }
  let(:user2) { create(:user, name: "Bob", email: "bob@example.com") }
  let(:sprint) { create(:sprint, organization: organization, name: "Sprint 1") }
  let(:milestone) { create(:milestone, organization: organization, name: "Beta Release") }
  
  let(:task1) do
    create(:task,
      organization_id: organization.id.to_s,
      title: "Task 1",
      assignee_id: user1.id.to_s,
      reviewer_id: user2.id.to_s,
      sprint_id: sprint.id.to_s,
      milestone_id: milestone.id.to_s,
      status: 'todo'
    )
  end
  
  let(:task2) do
    create(:task,
      organization_id: organization.id.to_s,
      title: "Task 2",
      assignee_id: user2.id.to_s,
      status: 'in_progress'
    )
  end
  
  let(:service) { described_class.new(organization) }

  before do
    create(:organization_membership, organization: organization, user: user1)
    create(:organization_membership, organization: organization, user: user2)
    Rails.cache.clear
  end

  describe '#list_with_users' do
    it 'returns enriched task data with user information' do
      task1 && task2  # 생성
      
      result = service.list_with_users

      expect(result).to be_success
      data = result.value!
      
      expect(data[:tasks]).to have(2).items
      expect(data[:tasks].first).to be_a(Dto::TaskDto)
      
      # User 데이터가 포함되어 있는지 확인
      task_with_assignee = data[:tasks].find { |t| t.id == task1.id.to_s }
      expect(task_with_assignee.assignee).to be_present
      expect(task_with_assignee.assignee.name).to eq("Alice")
      expect(task_with_assignee.assignee.email).to eq("alice@example.com")
      
      # 메타데이터 확인
      expect(data[:metadata][:total_count]).to be >= 2
      expect(data[:metadata][:by_status]['todo']).to be >= 1
      expect(data[:metadata][:by_status]['in_progress']).to be >= 1
    end

    it 'handles empty task list gracefully' do
      result = service.list_with_users

      expect(result).to be_success
      data = result.value!
      
      expect(data[:tasks]).to be_empty
      expect(data[:metadata][:total_count]).to eq(0)
    end
  end

  describe '#find_with_user' do
    it 'returns single task with user data' do
      task1  # 생성
      
      result = service.find_with_user(task1.id.to_s)

      expect(result).to be_success
      task_dto = result.value!
      
      expect(task_dto).to be_a(Dto::TaskDto)
      expect(task_dto.title).to eq(task1.title)
      expect(task_dto.assignee.name).to eq("Alice")
      expect(task_dto.reviewer.name).to eq("Bob")
      
      # Sprint/Milestone 데이터 확인
      expect(task_dto.sprint[:name]).to eq(sprint.name)
      expect(task_dto.milestone[:name]).to eq(milestone.name)
    end

    it 'returns failure for non-existent task' do
      result = service.find_with_user("nonexistent_id")

      expect(result).to be_failure
      expect(result.failure).to eq(:task_not_found)
    end
  end

  describe '#list_for_sprint' do
    it 'filters tasks by sprint' do
      task1  # 생성
      task2  # 생성
      
      result = service.list_for_sprint(sprint.id.to_s)

      expect(result).to be_success
      data = result.value!
      
      expect(data[:tasks]).to have(1).item
      expect(data[:tasks].first.id).to eq(task1.id.to_s)
    end
  end

  describe '#list_for_assignee' do
    it 'filters tasks by assignee' do
      task1  # 생성
      task2  # 생성
      
      result = service.list_for_assignee(user1.id.to_s)

      expect(result).to be_success
      data = result.value!
      
      expect(data[:tasks]).to have(1).item
      expect(data[:tasks].first.id).to eq(task1.id.to_s)
    end
  end

  describe '#dashboard_summary' do
    it 'provides organization statistics' do
      task1 && task2  # 생성
      
      result = service.dashboard_summary

      expect(result).to be_success
      summary = result.value!
      
      expect(summary[:total_tasks]).to be >= 2
      expect(summary[:by_status]['todo']).to be >= 1
      expect(summary[:by_status]['in_progress']).to be >= 1
      
      # 성능 통계 확인
      expect(summary[:performance_stats]).to be_present
      expect(summary[:performance_stats][:query_service][:total_queries]).to eq(1)
    end
  end

  describe 'performance tracking' do
    it 'tracks query performance correctly' do
      initial_stats = service.instance_variable_get(:@stats)
      expect(initial_stats[:total_queries]).to eq(0)
      
      service.list_with_users
      
      updated_stats = service.instance_variable_get(:@stats)
      expect(updated_stats[:total_queries]).to eq(1)
      expect(updated_stats[:average_response_time]).to be > 0
    end
  end

  describe 'error handling' do
    it 'handles missing user gracefully' do
      # 존재하지 않는 사용자 ID로 Task 생성
      task_without_user = create(:task,
        organization_id: organization.id.to_s,
        assignee_id: "nonexistent_user_id"
      )
      
      result = service.find_with_user(task_without_user.id.to_s)

      expect(result).to be_success
      task_dto = result.value!
      
      # assignee가 nil이어야 함
      expect(task_dto.assignee).to be_nil
    end
  end
end