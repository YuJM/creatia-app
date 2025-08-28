# frozen_string_literal: true

require 'rails_helper'
require_relative '../../app/jobs/process_github_push_job'

RSpec.describe ProcessGithubPushJob do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:service) { create(:service, organization: organization, task_prefix: 'SHOP') }
  let!(:task) do
    t = create(:task, service: service, status: 'todo')
    # Extract the numeric part of task ID (after UUID)
    t
  end
  let(:task_id) { task.task_id }
  
  let(:webhook_data) do
    {
      ref: "refs/heads/#{task_id}-shopping-cart",
      repository: {
        name: 'creatia-app',
        full_name: 'creatia/creatia-app'
      },
      commits: [
        {
          message: "[#{task_id}] Add shopping cart model",
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
  
  describe '#perform' do
    context 'when task ID is present in webhook' do
      before do
        task # ensure task exists
      end
      
      it 'processes the webhook successfully' do
        expect(Rails.logger).to receive(:info).at_least(:once)
        
        described_class.new.perform(webhook_data)
      end
      
      context 'when branch is created' do
        let(:webhook_data_with_creation) do
          webhook_data.merge(created: true)
        end
        
        it 'updates task status to in_progress' do
          described_class.new.perform(webhook_data_with_creation)
          
          task.reload
          expect(task.status).to eq('in_progress')
        end
      end
      
      context 'when commit message contains PR keywords' do
        let(:webhook_data_with_pr) do
          webhook_data.merge(
            commits: [
              { message: 'Ready for PR review' }
            ]
          )
        end
        
        let!(:task_in_progress) do
          task.update!(status: 'in_progress')
          task
        end
        
        it 'updates task status to review' do
          task_in_progress # ensure task exists
          
          described_class.new.perform(webhook_data_with_pr)
          
          task_in_progress.reload
          expect(task_in_progress.status).to eq('review')
        end
      end
    end
    
    context 'when task ID is not present' do
      let(:webhook_data_without_task) do
        webhook_data.merge(
          ref: 'refs/heads/feature-branch',
          commits: []
        )
      end
      
      it 'does not process the webhook' do
        # Job should return early when no task ID
        expect { described_class.new.perform(webhook_data_without_task) }.not_to raise_error
      end
    end
    
    context 'when task does not exist' do
      let(:webhook_data_with_unknown_task) do
        webhook_data.merge(
          ref: 'refs/heads/UNKNOWN-999-feature'
        )
      end
      
      it 'logs but does not raise error' do
        expect { described_class.new.perform(webhook_data_with_unknown_task) }.not_to raise_error
      end
    end
    
    context 'when task ID is in commit message only' do
      let(:webhook_data_with_task_in_commit) do
        webhook_data.merge(
          ref: 'refs/heads/feature-branch',
          commits: [
            { message: "[#{task_id}] Fix cart calculations" }
          ]
        )
      end
      
      before do
        task # ensure task exists
      end
      
      it 'finds task ID from commit message' do
        expect(Rails.logger).to receive(:info).at_least(:once)
        
        described_class.new.perform(webhook_data_with_task_in_commit)
      end
    end
  end
end