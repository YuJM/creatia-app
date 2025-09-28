# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TaskMetrics do
  let(:task_metrics) do
    described_class.new(
      estimated_hours: 8.0,
      actual_hours: 10.0,
      completion_percentage: 75.0,
      complexity_score: 5
    )
  end

  describe 'initialization' do
    it 'creates task metrics with default values' do
      basic_metrics = described_class.new
      
      expect(basic_metrics.completion_percentage).to eq(0.0)
      expect(basic_metrics.complexity_score).to eq(1)
      expect(basic_metrics.estimated_hours).to be_nil
    end

    it 'creates task metrics with provided values' do
      expect(task_metrics.estimated_hours).to eq(8.0)
      expect(task_metrics.actual_hours).to eq(10.0)
      expect(task_metrics.completion_percentage).to eq(75.0)
      expect(task_metrics.complexity_score).to eq(5)
    end
  end

  describe '#overdue?' do
    it 'returns true when actual hours exceed estimated' do
      expect(task_metrics.overdue?).to be true
    end

    it 'returns false when actual hours are within estimate' do
      metrics = described_class.new(estimated_hours: 10.0, actual_hours: 8.0)
      expect(metrics.overdue?).to be false
    end

    it 'returns false when hours are not set' do
      metrics = described_class.new
      expect(metrics.overdue?).to be false
    end
  end

  describe '#efficiency_ratio' do
    it 'calculates efficiency ratio correctly' do
      expect(task_metrics.efficiency_ratio).to eq(0.8)
    end

    it 'returns 0.0 when estimated hours is zero' do
      metrics = described_class.new(estimated_hours: 0.0, actual_hours: 5.0)
      expect(metrics.efficiency_ratio).to eq(0.0)
    end

    it 'returns 0.0 when hours are not set' do
      metrics = described_class.new
      expect(metrics.efficiency_ratio).to eq(0.0)
    end
  end

  describe '#remaining_percentage' do
    it 'calculates remaining percentage' do
      expect(task_metrics.remaining_percentage).to eq(25.0)
    end
  end

  describe '#is_on_track?' do
    it 'returns false when efficiency ratio is below 0.8' do
      # task_metrics has efficiency_ratio of 0.8 (8.0/10.0), so it should be true
      # Let's create a case with efficiency below 0.8
      overdue_metrics = described_class.new(estimated_hours: 8.0, actual_hours: 12.0)
      expect(overdue_metrics.is_on_track?).to be false
    end

    it 'returns true when efficiency ratio is 0.8 or above' do
      metrics = described_class.new(estimated_hours: 10.0, actual_hours: 10.0)
      expect(metrics.is_on_track?).to be true
    end

    it 'returns true when hours are not set' do
      metrics = described_class.new
      expect(metrics.is_on_track?).to be true
    end
  end

  describe '#complexity_level' do
    it 'returns correct complexity level' do
      expect(task_metrics.complexity_level).to eq('medium')
    end

    context 'with different complexity scores' do
      it 'returns low for scores 1-2' do
        metrics = described_class.new(complexity_score: 2)
        expect(metrics.complexity_level).to eq('low')
      end

      it 'returns high for scores 6-8' do
        metrics = described_class.new(complexity_score: 7)
        expect(metrics.complexity_level).to eq('high')
      end

      it 'returns very_high for scores 9+' do
        metrics = described_class.new(complexity_score: 10)
        expect(metrics.complexity_level).to eq('very_high')
      end
    end
  end
end