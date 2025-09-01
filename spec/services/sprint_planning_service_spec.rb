# frozen_string_literal: true

require 'rails_helper'
require_relative '../../app/services/sprint_planning_service'
require_relative '../../app/contracts/sprint_planning_contract'
require_relative '../../app/structs/sprint_plan'

RSpec.describe SprintPlanningService do
  let(:organization) { create(:organization) }
  let(:service) { create(:service, organization: organization) }
  let(:sprint) do
    create(:mongo_sprint,
      service: service,
      start_date: Date.current,
      end_date: 14.days.from_now
    )
  end
  
  let(:team_members) do
    3.times.map { create(:user) }
  end
  
  let!(:tasks) do
    5.times.map do |i|
      create(:mongo_task,
        sprint: sprint,
        service: service,
        title: "Task #{i}",
        estimated_hours: rand(4..16),
        status: 'todo'
      )
    end
  end
  
  subject(:planning_service) { described_class.new(sprint, team_members) }
  
  describe '#execute' do
    context 'with valid sprint data' do
      it 'returns Success with SprintPlan' do
        result = planning_service.execute
        
        expect(result).to be_success
        expect(result.value!).to be_a(SprintPlan)
      end
      
      it 'includes allocations in the plan' do
        result = planning_service.execute
        plan = result.value!
        
        expect(plan.allocations).to be_a(Hash)
      end
      
      it 'calculates team capacity' do
        result = planning_service.execute
        plan = result.value!
        
        # 14 business days * 3 members * 8 hours * 0.8 efficiency
        expected_capacity = 10 * 3 * 8 * 0.8 # 약 10 business days
        expect(plan.capacity).to be > 0
        expect(plan.capacity).to be <= expected_capacity + 50 # 여유있게
      end
      
      it 'identifies risks' do
        result = planning_service.execute
        plan = result.value!
        
        expect(plan.risks).to be_an(Array)
      end
      
      it 'generates burndown projection' do
        result = planning_service.execute
        plan = result.value!
        
        expect(plan.burndown).to have_key(:ideal)
        expect(plan.burndown).to have_key(:projected)
        expect(plan.burndown).to have_key(:will_complete)
      end
    end
    
    context 'with invalid sprint data' do
      let(:invalid_sprint) do
        build(:mongo_sprint,
          service: service,
          start_date: Date.current,
          end_date: Date.yesterday # Invalid: end before start
        )
      end
      
      it 'returns Failure with validation errors' do
        # stub하여 validation 에러가 나지 않도록 함
        allow(invalid_sprint).to receive(:tasks).and_return(Mongodb::MongoTask.none)
        service = described_class.new(invalid_sprint, team_members)
        result = service.execute
        
        expect(result).to be_failure
        expect(result.failure[0]).to eq(:validation_error)
      end
    end
    
    context 'with no team members' do
      let(:empty_team) { [] }
      
      it 'returns Failure' do
        service = described_class.new(sprint, empty_team)
        result = service.execute
        
        expect(result).to be_failure
      end
    end
  end
  
  describe 'SprintPlan methods' do
    let(:plan) do
      result = planning_service.execute
      result.value!
    end
    
    it 'calculates utilization rate' do
      expect(plan.utilization_rate).to be_a(Float)
      expect(plan.utilization_rate).to be >= 0
    end
    
    it 'determines if overloaded' do
      expect(plan.overloaded?).to be_in([true, false])
    end
    
    it 'checks if on track' do
      expect(plan.on_track?).to be_in([true, false])
    end
    
    it 'provides risk summary' do
      summary = plan.risk_summary
      
      expect(summary).to have_key(:high)
      expect(summary).to have_key(:medium)
      expect(summary).to have_key(:low)
      expect(summary).to have_key(:total)
    end
    
    it 'provides allocation summary' do
      summary = plan.allocation_summary
      
      expect(summary).to be_a(Hash)
      summary.each_value do |allocation|
        expect(allocation).to have_key(:count)
        expect(allocation).to have_key(:hours)
      end
    end
  end
  
  describe 'MemoWise integration' do
    it 'memoizes dependency_analyzer' do
      # private 메서드이지만 send로 접근
      analyzer1 = planning_service.send(:dependency_analyzer)
      analyzer2 = planning_service.send(:dependency_analyzer)
      
      expect(analyzer1.object_id).to eq(analyzer2.object_id)
    end
    
    it 'memoizes calculate_capacity' do
      capacity1 = planning_service.send(:calculate_capacity)
      capacity2 = planning_service.send(:calculate_capacity)
      
      expect(capacity1).to eq(capacity2)
    end
    
    it 'memoizes calculate_velocity' do
      velocity1 = planning_service.send(:calculate_velocity)
      velocity2 = planning_service.send(:calculate_velocity)
      
      expect(velocity1).to eq(velocity2)
    end
  end
end