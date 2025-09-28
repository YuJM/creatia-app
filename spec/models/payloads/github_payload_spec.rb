# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/models/payloads/github_payload'

RSpec.describe GithubPayload do
  let(:valid_payload_data) do
    {
      ref: 'refs/heads/SHOP-142-shopping-cart',
      repository: {
        name: 'creatia-app',
        full_name: 'creatia/creatia-app'
      },
      commits: [
        {
          message: '[SHOP-142] Add shopping cart model',
          author: {
            name: 'John Doe',
            email: 'john@example.com'
          }
        }
      ],
      pusher: {
        name: 'John Doe',
        email: 'john@example.com'
      },
      created: false,
      deleted: false,
      forced: false
    }
  end
  
  describe 'initialization' do
    it 'creates instance with valid data' do
      payload = described_class.new(valid_payload_data)
      
      expect(payload.ref).to eq('refs/heads/SHOP-142-shopping-cart')
      expect(payload.repository_name).to eq('creatia-app')
    end
    
    it 'allows method access' do
      payload = described_class.new(valid_payload_data)
      
      expect(payload.repository.name).to eq('creatia-app')
      expect(payload.pusher.email).to eq('john@example.com')
    end
    
    it 'allows indifferent access' do
      payload = described_class.new(valid_payload_data)
      
      expect(payload['ref']).to eq(payload[:ref])
      expect(payload.repository['name']).to eq(payload.repository[:name])
    end
  end
  
  describe '#task_id' do
    context 'when task ID is in branch name' do
      it 'extracts task ID correctly' do
        payload = described_class.new(valid_payload_data)
        expect(payload.task_id).to eq('SHOP-142')
      end
    end
    
    context 'when task ID is only in commit message' do
      let(:payload_with_task_in_commit) do
        valid_payload_data.merge(
          ref: 'refs/heads/feature-branch',
          commits: [
            { message: 'Fix [PAY-99] payment processing bug' }
          ]
        )
      end
      
      it 'extracts task ID from commit message' do
        payload = described_class.new(payload_with_task_in_commit)
        expect(payload.task_id).to eq('PAY-99')
      end
    end
    
    context 'when no task ID present' do
      let(:payload_without_task) do
        valid_payload_data.merge(
          ref: 'refs/heads/feature-branch',
          commits: []
        )
      end
      
      it 'returns nil' do
        payload = described_class.new(payload_without_task)
        expect(payload.task_id).to be_nil
      end
    end
  end
  
  describe '#branch_name' do
    it 'removes refs/heads/ prefix' do
      payload = described_class.new(valid_payload_data)
      expect(payload.branch_name).to eq('SHOP-142-shopping-cart')
    end
  end
  
  describe '#repository_full_name' do
    it 'returns repository full name' do
      payload = described_class.new(valid_payload_data)
      expect(payload.repository_full_name).to eq('creatia/creatia-app')
    end
  end
  
  describe '#author_email' do
    context 'when pusher has email' do
      it 'returns pusher email' do
        payload = described_class.new(valid_payload_data)
        expect(payload.author_email).to eq('john@example.com')
      end
    end
    
    context 'when only sender has email' do
      let(:payload_with_sender) do
        valid_payload_data.merge(
          pusher: nil,
          sender: { email: 'sender@example.com' }
        )
      end
      
      it 'returns sender email' do
        payload = described_class.new(payload_with_sender)
        expect(payload.author_email).to eq('sender@example.com')
      end
    end
  end
  
  describe '#is_branch_creation?' do
    it 'returns true when created is true' do
      payload_data = valid_payload_data.merge(created: true)
      payload = described_class.new(payload_data)
      
      expect(payload.is_branch_creation?).to be true
    end
    
    it 'returns false when created is false' do
      payload = described_class.new(valid_payload_data)
      expect(payload.is_branch_creation?).to be false
    end
  end
  
  describe '#commit_count' do
    it 'returns number of commits' do
      payload = described_class.new(valid_payload_data)
      expect(payload.commit_count).to eq(1)
    end
  end
  
  describe '#latest_commit_message' do
    context 'when head_commit exists' do
      let(:payload_with_head) do
        valid_payload_data.merge(
          head_commit: { message: 'Latest commit message' }
        )
      end
      
      it 'returns head commit message' do
        payload = described_class.new(payload_with_head)
        expect(payload.latest_commit_message).to eq('Latest commit message')
      end
    end
    
    context 'when only commits array exists' do
      it 'returns first commit message' do
        payload = described_class.new(valid_payload_data)
        expect(payload.latest_commit_message).to eq('[SHOP-142] Add shopping cart model')
      end
    end
  end
  
  describe '#to_activity_data' do
    it 'returns formatted activity data' do
      payload = described_class.new(valid_payload_data)
      activity = payload.to_activity_data
      
      expect(activity[:task_id]).to eq('SHOP-142')
      expect(activity[:branch]).to eq('SHOP-142-shopping-cart')
      expect(activity[:repository]).to eq('creatia/creatia-app')
      expect(activity[:author]).to eq('John Doe')
      expect(activity[:commits_count]).to eq(1)
    end
  end
end