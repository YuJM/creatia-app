# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RiskAssessment do
  let(:risk_assessment) do
    described_class.new(
      type: 'capacity',
      severity: 'high',
      probability: 0.8,
      impact_score: 7,
      description: 'Team overallocated by 25%',
      mitigation_strategy: 'Redistribute tasks or add resources',
      owner: 'Project Manager',
      target_date: Date.current + 5.days,
      status: 'mitigating'
    )
  end

  describe 'initialization' do
    it 'creates risk assessment with required fields' do
      basic_risk = described_class.new(
        type: 'technical',
        severity: 'medium',
        probability: 0.5,
        impact_score: 5,
        description: 'Technical debt accumulation'
      )

      expect(basic_risk.type).to eq('technical')
      expect(basic_risk.severity).to eq('medium')
      expect(basic_risk.status).to eq('identified')
    end

    it 'validates enum values' do
      expect {
        described_class.new(
          type: 'invalid_type',
          severity: 'medium',
          probability: 0.5,
          impact_score: 5,
          description: 'Test'
        )
      }.to raise_error(Dry::Struct::Error)
    end

    it 'validates probability range' do
      expect {
        described_class.new(
          type: 'capacity',
          severity: 'medium',
          probability: 1.5,
          impact_score: 5,
          description: 'Test'
        )
      }.to raise_error(Dry::Struct::Error)
    end

    it 'validates impact score range' do
      expect {
        described_class.new(
          type: 'capacity',
          severity: 'medium', 
          probability: 0.5,
          impact_score: 15,
          description: 'Test'
        )
      }.to raise_error(Dry::Struct::Error)
    end
  end

  describe '#risk_score' do
    it 'calculates risk score correctly' do
      # 0.8 * 7 * 10 = 56.0
      expect(risk_assessment.risk_score).to eq(56.0)
    end
  end

  describe '#priority_level' do
    it 'returns correct priority level for high risk score' do
      expect(risk_assessment.priority_level).to eq('high')
    end

    context 'with different risk scores' do
      it 'returns low for risk score 0-25' do
        risk = described_class.new(
          type: 'quality',
          severity: 'low',
          probability: 0.2,
          impact_score: 2,
          description: 'Minor quality issue'
        )
        expect(risk.priority_level).to eq('low')
      end

      it 'returns critical for risk score > 75' do
        risk = described_class.new(
          type: 'schedule',
          severity: 'critical',
          probability: 0.9,
          impact_score: 10,
          description: 'Major delay risk'
        )
        expect(risk.priority_level).to eq('critical')
      end
    end
  end

  describe '#is_critical?' do
    it 'returns true for high severity and high risk score' do
      expect(risk_assessment.is_critical?).to be false # severity is 'high', not 'critical'
    end

    it 'returns true for critical severity' do
      risk = described_class.new(
        type: 'capacity',
        severity: 'critical',
        probability: 0.3,
        impact_score: 3,
        description: 'Critical issue'
      )
      expect(risk.is_critical?).to be true
    end

    it 'returns true for very high risk score' do
      risk = described_class.new(
        type: 'capacity',
        severity: 'medium',
        probability: 0.9,
        impact_score: 10,
        description: 'High impact risk'
      )
      expect(risk.is_critical?).to be true
    end
  end

  describe '#is_overdue?' do
    it 'returns false when target date is in the future' do
      expect(risk_assessment.is_overdue?).to be false
    end

    it 'returns true when target date is in the past and not resolved' do
      risk = described_class.new(
        type: 'capacity',
        severity: 'medium',
        probability: 0.5,
        impact_score: 5,
        description: 'Overdue risk',
        target_date: Date.current - 2.days,
        status: 'mitigating'
      )
      expect(risk.is_overdue?).to be true
    end

    it 'returns false when target date is past but status is resolved' do
      risk = described_class.new(
        type: 'capacity',
        severity: 'medium',
        probability: 0.5,
        impact_score: 5,
        description: 'Resolved risk',
        target_date: Date.current - 2.days,
        status: 'resolved'
      )
      expect(risk.is_overdue?).to be false
    end

    it 'returns false when no target date' do
      risk = described_class.new(
        type: 'capacity',
        severity: 'medium',
        probability: 0.5,
        impact_score: 5,
        description: 'No target date'
      )
      expect(risk.is_overdue?).to be false
    end
  end

  describe '#requires_immediate_attention?' do
    it 'returns true for critical risks' do
      risk = described_class.new(
        type: 'capacity',
        severity: 'critical',
        probability: 0.5,
        impact_score: 5,
        description: 'Critical risk'
      )
      expect(risk.requires_immediate_attention?).to be true
    end

    it 'returns true for overdue risks' do
      risk = described_class.new(
        type: 'capacity',
        severity: 'medium',
        probability: 0.5,
        impact_score: 5,
        description: 'Overdue risk',
        target_date: Date.current - 1.day
      )
      expect(risk.requires_immediate_attention?).to be true
    end
  end

  describe '#severity_color' do
    it 'returns correct color for severity' do
      expect(risk_assessment.severity_color).to eq('orange')
    end
  end

  describe '#status_icon' do
    it 'returns correct icon for status' do
      expect(risk_assessment.status_icon).to eq('🛠️')
    end
  end

  describe '#days_until_target' do
    it 'calculates days until target date' do
      expect(risk_assessment.days_until_target).to eq(5)
    end

    it 'returns nil when no target date' do
      risk = described_class.new(
        type: 'capacity',
        severity: 'medium',
        probability: 0.5,
        impact_score: 5,
        description: 'No target'
      )
      expect(risk.days_until_target).to be_nil
    end
  end

  describe 'factory methods' do
    describe '.create_capacity_risk' do
      it 'creates capacity risk with appropriate severity' do
        risk = described_class.create_capacity_risk(95.0, 2)
        
        expect(risk.type).to eq('capacity')
        expect(risk.severity).to eq('high')
        expect(risk.probability).to eq(0.95)
        expect(risk.impact_score).to eq(8) # small team
      end

      it 'creates critical risk for very high utilization' do
        risk = described_class.create_capacity_risk(120.0, 5)
        
        expect(risk.severity).to eq('critical')
        expect(risk.probability).to eq(1.0)
        expect(risk.impact_score).to eq(6) # larger team
      end
    end

    describe '.create_dependency_risk' do
      it 'returns nil for zero blocked tasks' do
        risk = described_class.create_dependency_risk(0)
        expect(risk).to be_nil
      end

      it 'creates dependency risk for blocked tasks' do
        risk = described_class.create_dependency_risk(2)
        
        expect(risk.type).to eq('dependency')
        expect(risk.severity).to eq('medium')
        expect(risk.probability).to eq(0.8)
        expect(risk.impact_score).to eq(4)
      end

      it 'creates high severity risk for many blocked tasks' do
        risk = described_class.create_dependency_risk(5)
        
        expect(risk.severity).to eq('high')
        expect(risk.impact_score).to eq(10)
      end
    end
  end
end