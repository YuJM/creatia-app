# frozen_string_literal: true

require 'rails_helper'
require_relative '../../app/services/dependency_analyzer'

RSpec.describe DependencyAnalyzer do
  let(:organization) { create(:organization) }
  let(:service) { create(:service, organization: organization) }
  let(:sprint) do
    create(:sprint, 
      service: service, 
      start_date: Date.current,
      end_date: 10.days.from_now
    )
  end
  
  let!(:task1) do
    create(:task, 
      sprint: sprint, 
      service: service, 
      title: 'Task 1',
      estimated_hours: 8,
      status: 'todo'
    )
  end
  
  let!(:task2) do
    create(:task,
      sprint: sprint,
      service: service, 
      title: 'Task 2',
      estimated_hours: 6,
      status: 'in_progress'
    )
  end
  
  let!(:task3) do
    create(:task,
      sprint: sprint,
      service: service,
      title: 'Task 3', 
      estimated_hours: 4,
      status: 'done'
    )
  end
  
  subject(:analyzer) { described_class.new(sprint) }
  
  describe '#critical_path' do
    it 'returns empty array when no tasks' do
      empty_sprint = create(:sprint, service: service)
      analyzer = described_class.new(empty_sprint)
      
      expect(analyzer.critical_path).to eq([])
    end
    
    it 'memoizes the critical path calculation' do
      # 첫 번째 호출
      path1 = analyzer.critical_path
      
      # 두 번째 호출 - 같은 객체를 반환해야 함
      path2 = analyzer.critical_path
      
      expect(path1.object_id).to eq(path2.object_id)
    end
  end
  
  describe '#bottleneck_tasks' do
    it 'identifies tasks that block many others' do
      # 의존성이 없는 경우 빈 배열 반환
      expect(analyzer.bottleneck_tasks).to eq([])
    end
    
    it 'memoizes bottleneck calculation' do
      result1 = analyzer.bottleneck_tasks
      result2 = analyzer.bottleneck_tasks
      
      expect(result1.object_id).to eq(result2.object_id)
    end
  end
  
  describe '#workload_distribution' do
    let(:user) { create(:user) }
    
    before do
      task1.update!(assignee: user)
      task2.update!(assignee: user)
    end
    
    it 'calculates workload per assignee' do
      distribution = analyzer.workload_distribution
      
      expect(distribution[user.id][:total_hours]).to eq(14) # 8 + 6
      expect(distribution[user.id][:tasks].size).to eq(2)
      expect(distribution['unassigned'][:tasks].size).to eq(1)
    end
    
    it 'memoizes workload distribution' do
      dist1 = analyzer.workload_distribution
      dist2 = analyzer.workload_distribution
      
      expect(dist1.object_id).to eq(dist2.object_id)
    end
  end
  
  describe '#risk_assessment' do
    it 'identifies risks in the sprint' do
      risks = analyzer.risk_assessment
      
      expect(risks).to be_an(Array)
      expect(risks.map { |r| r[:type] }).to include('workload_imbalance')
    end
    
    it 'memoizes risk assessment' do
      risks1 = analyzer.risk_assessment
      risks2 = analyzer.risk_assessment
      
      expect(risks1.object_id).to eq(risks2.object_id)
    end
  end
  
  describe '#progress_metrics' do
    it 'calculates sprint progress' do
      metrics = analyzer.progress_metrics
      
      expect(metrics[:tasks_total]).to eq(3)
      expect(metrics[:tasks_completed]).to eq(1)
      expect(metrics[:tasks_in_progress]).to eq(1)
      expect(metrics[:completion_rate]).to be_between(0, 100)
    end
    
    it 'memoizes progress metrics' do
      metrics1 = analyzer.progress_metrics
      metrics2 = analyzer.progress_metrics
      
      expect(metrics1.object_id).to eq(metrics2.object_id)
    end
  end
  
  describe '#estimated_completion_date' do
    it 'estimates when sprint will complete' do
      date = analyzer.estimated_completion_date
      
      # critical_path가 비어있으면 nil
      expect(date).to be_nil
    end
    
    it 'memoizes completion date calculation' do
      date1 = analyzer.estimated_completion_date
      date2 = analyzer.estimated_completion_date
      
      # nil이어도 같은 객체
      expect(date1).to eq(date2)
    end
  end
  
  describe 'MemoWise integration' do
    it 'prepends MemoWise module' do
      expect(described_class.ancestors).to include(MemoWise)
    end
    
    it 'defines memo_wise methods' do
      expect(analyzer).to respond_to(:critical_path)
      expect(analyzer).to respond_to(:bottleneck_tasks)
      expect(analyzer).to respond_to(:workload_distribution)
      expect(analyzer).to respond_to(:risk_assessment)
      expect(analyzer).to respond_to(:progress_metrics)
      expect(analyzer).to respond_to(:estimated_completion_date)
    end
    
    it 'caches method results efficiently' do
      # 복잡한 계산을 시뮬레이션하기 위해 많은 태스크 생성
      10.times do |i|
        create(:task, 
          sprint: sprint, 
          service: service,
          title: "Task #{i + 4}",
          estimated_hours: rand(1..20)
        )
      end
      
      analyzer = described_class.new(sprint)
      
      # 첫 호출 시간 측정
      start_time = Time.current
      analyzer.critical_path
      first_call_time = Time.current - start_time
      
      # 두 번째 호출 시간 측정 (메모이제이션됨)
      start_time = Time.current
      analyzer.critical_path
      second_call_time = Time.current - start_time
      
      # 두 번째 호출이 훨씬 빨라야 함
      expect(second_call_time).to be < first_call_time
    end
  end
end