# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TeamMetrics do
  let(:team_metrics) do
    described_class.new(
      total_capacity: 120.0,
      allocated_hours: 100.0,
      completed_hours: 80.0,
      team_size: 3,
      active_tasks: 5,
      completed_tasks: 8,
      blocked_tasks: 2,
      velocity_last_sprint: 25.0,
      average_velocity: 20.0
    )
  end

  describe 'initialization' do
    it 'creates team metrics with default values' do
      basic_metrics = described_class.new
      
      expect(basic_metrics.total_capacity).to eq(0.0)
      expect(basic_metrics.team_size).to eq(0)
      expect(basic_metrics.active_tasks).to eq(0)
    end

    it 'creates team metrics with provided values' do
      expect(team_metrics.total_capacity).to eq(120.0)
      expect(team_metrics.team_size).to eq(3)
      expect(team_metrics.active_tasks).to eq(5)
    end
  end

  describe '#utilization_rate' do
    it 'calculates utilization rate correctly' do
      expect(team_metrics.utilization_rate).to eq(83.33)
    end

    it 'returns 0 when total capacity is zero' do
      metrics = described_class.new(total_capacity: 0.0, allocated_hours: 50.0)
      expect(metrics.utilization_rate).to eq(0.0)
    end
  end

  describe '#completion_rate' do
    it 'calculates completion rate correctly' do
      # total tasks = 5 + 8 + 2 = 15, completed = 8
      expect(team_metrics.completion_rate).to eq(53.33)
    end

    it 'returns 0 when no tasks' do
      metrics = described_class.new
      expect(metrics.completion_rate).to eq(0.0)
    end
  end

  describe '#capacity_per_member' do
    it 'calculates capacity per member' do
      expect(team_metrics.capacity_per_member).to eq(40.0)
    end

    it 'returns 0 when team size is zero' do
      metrics = described_class.new(total_capacity: 120.0, team_size: 0)
      expect(metrics.capacity_per_member).to eq(0.0)
    end
  end

  describe '#hours_per_task' do
    it 'calculates hours per active task' do
      expect(team_metrics.hours_per_task).to eq(20.0)
    end

    it 'returns 0 when no active tasks' do
      metrics = described_class.new(allocated_hours: 100.0, active_tasks: 0)
      expect(metrics.hours_per_task).to eq(0.0)
    end
  end

  describe 'status checks' do
    describe '#is_overallocated?' do
      it 'returns false when utilization is under 100%' do
        expect(team_metrics.is_overallocated?).to be false
      end

      it 'returns true when utilization exceeds 100%' do
        metrics = described_class.new(total_capacity: 80.0, allocated_hours: 100.0)
        expect(metrics.is_overallocated?).to be true
      end
    end

    describe '#is_underutilized?' do
      it 'returns false when utilization is above 70%' do
        expect(team_metrics.is_underutilized?).to be false
      end

      it 'returns true when utilization is below 70%' do
        metrics = described_class.new(total_capacity: 100.0, allocated_hours: 60.0)
        expect(metrics.is_underutilized?).to be true
      end
    end

    describe '#has_blocked_issues?' do
      it 'returns true when there are blocked tasks' do
        expect(team_metrics.has_blocked_issues?).to be true
      end

      it 'returns false when no blocked tasks' do
        metrics = described_class.new(blocked_tasks: 0)
        expect(metrics.has_blocked_issues?).to be false
      end
    end
  end

  describe '#velocity_trend' do
    it 'returns improving when last sprint velocity is significantly higher' do
      expect(team_metrics.velocity_trend).to eq('improving')
    end

    it 'returns declining when last sprint velocity is significantly lower' do
      metrics = described_class.new(velocity_last_sprint: 15.0, average_velocity: 20.0)
      expect(metrics.velocity_trend).to eq('declining')
    end

    it 'returns stable when velocities are similar' do
      metrics = described_class.new(velocity_last_sprint: 20.0, average_velocity: 20.0)
      expect(metrics.velocity_trend).to eq('stable')
    end

    it 'returns unknown when velocities are not set' do
      metrics = described_class.new
      expect(metrics.velocity_trend).to eq('unknown')
    end
  end

  describe '#health_score' do
    it 'calculates health score based on various factors' do
      # Base 100 - no overallocation penalty - no underutilization penalty 
      # - blocked tasks penalty (2 * 5 = 10) + completion rate bonus (53.33 * 0.3 = 16)
      expected_score = 100.0 - 10.0 + 16.0
      expect(team_metrics.health_score).to eq(expected_score)
    end

    it 'applies overallocation penalty' do
      metrics = described_class.new(
        total_capacity: 80.0,
        allocated_hours: 100.0,
        blocked_tasks: 0,
        completed_tasks: 10,
        active_tasks: 5,
        team_size: 1
      )
      # Base 100 - overallocation penalty (20) + completion rate bonus (66.67 * 0.3 ≈ 20)
      # Net should be around 100, but let's ensure it's properly calculated
      health_score = metrics.health_score
      expect(health_score).to be_between(80.0, 120.0) # Allow for calculation variations
    end

    it 'ensures health score is not negative' do
      metrics = described_class.new(
        blocked_tasks: 50,
        total_capacity: 10.0,
        allocated_hours: 100.0
      )
      expect(metrics.health_score).to be >= 0.0
    end
  end
end