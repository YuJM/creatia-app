# frozen_string_literal: true

require 'rails_helper'
require_relative '../../app/structs/types'
require_relative '../../app/structs/task_status'

RSpec.describe TaskStatus do
  describe '#can_transition_to?' do
    context 'when state is todo' do
      let(:status) { described_class.new(state: 'todo') }
      
      it 'can transition to in_progress' do
        expect(status.can_transition_to?('in_progress')).to be true
      end
      
      it 'can transition to blocked' do
        expect(status.can_transition_to?('blocked')).to be true
      end
      
      it 'cannot transition to done' do
        expect(status.can_transition_to?('done')).to be false
      end
      
      it 'cannot transition to review' do
        expect(status.can_transition_to?('review')).to be false
      end
    end
    
    context 'when state is in_progress' do
      let(:status) { described_class.new(state: 'in_progress') }
      
      it 'can transition to blocked' do
        expect(status.can_transition_to?('blocked')).to be true
      end
      
      it 'can transition to review' do
        expect(status.can_transition_to?('review')).to be true
      end
      
      it 'can transition to done' do
        expect(status.can_transition_to?('done')).to be true
      end
      
      it 'cannot transition to todo' do
        expect(status.can_transition_to?('todo')).to be false
      end
    end
    
    context 'when state is done' do
      let(:status) { described_class.new(state: 'done') }
      
      it 'cannot transition to any state' do
        %w[todo in_progress blocked review].each do |state|
          expect(status.can_transition_to?(state)).to be false
        end
      end
    end
  end
  
  describe 'state predicates' do
    it 'responds to state check methods' do
      status = described_class.new(state: 'in_progress')
      
      expect(status.in_progress?).to be true
      expect(status.todo?).to be false
      expect(status.done?).to be false
      expect(status.blocked?).to be false
      expect(status.review?).to be false
    end
  end
  
  describe '#active?' do
    it 'returns true for in_progress and review states' do
      expect(described_class.new(state: 'in_progress').active?).to be true
      expect(described_class.new(state: 'review').active?).to be true
    end
    
    it 'returns false for other states' do
      expect(described_class.new(state: 'todo').active?).to be false
      expect(described_class.new(state: 'done').active?).to be false
      expect(described_class.new(state: 'blocked').active?).to be false
    end
  end
  
  describe '#workable?' do
    it 'returns true for non-blocked and non-done states' do
      expect(described_class.new(state: 'todo').workable?).to be true
      expect(described_class.new(state: 'in_progress').workable?).to be true
      expect(described_class.new(state: 'review').workable?).to be true
    end
    
    it 'returns false for blocked and done states' do
      expect(described_class.new(state: 'blocked').workable?).to be false
      expect(described_class.new(state: 'done').workable?).to be false
    end
  end
  
  describe '#duration' do
    let(:started_at) { 2.hours.ago }
    let(:completed_at) { 30.minutes.ago }
    
    context 'when task has started_at and completed_at' do
      let(:status) do
        described_class.new(
          state: 'done',
          started_at: started_at,
          completed_at: completed_at
        )
      end
      
      it 'calculates duration correctly' do
        expect(status.duration).to be_within(1.second).of(90.minutes)
      end
    end
    
    context 'when task has only started_at' do
      let(:status) do
        described_class.new(
          state: 'in_progress',
          started_at: started_at
        )
      end
      
      it 'calculates duration from current time' do
        expect(status.duration).to be_within(1.second).of(2.hours)
      end
    end
    
    context 'when task has no started_at' do
      let(:status) { described_class.new(state: 'todo') }
      
      it 'returns nil' do
        expect(status.duration).to be_nil
      end
    end
  end
  
  describe '#days_in_progress' do
    context 'when task started 3 days ago' do
      let(:status) do
        described_class.new(
          state: 'in_progress',
          started_at: 3.days.ago
        )
      end
      
      it 'returns correct number of days' do
        expect(status.days_in_progress).to eq(3)
      end
    end
    
    context 'when task has not started' do
      let(:status) { described_class.new(state: 'todo') }
      
      it 'returns 0' do
        expect(status.days_in_progress).to eq(0)
      end
    end
  end
end