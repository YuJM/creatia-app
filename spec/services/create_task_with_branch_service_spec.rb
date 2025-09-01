# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CreateMongodb::MongoTaskWithBranchService do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:service) { create(:service, organization: organization) }
  let(:task_params) do
    {
      title: 'Implement shopping cart',
      description: 'Add shopping cart functionality',
      priority: 'high',
      status: 'todo'
    }
  end
  
  subject(:create_service) do
    described_class.new(
      task_params: task_params,
      user: user,
      service: service
    )
  end
  
  describe '#call' do
    context 'with valid parameters' do
      it 'returns Success with task' do
        result = create_service.call
        
        expect(result).to be_success
        expect(result.value!).to be_a(Mongodb::MongoTask)
        expect(result.value!.title).to eq('Implement shopping cart')
      end
      
      it 'creates a task' do
        expect { create_service.call }.to change { Mongodb::MongoTask.count }.by(1)
      end
      
      it 'assigns creator to task' do
        result = create_service.call
        task = result.value!
        
        expect(task.creator).to eq(user)
      end
    end
    
    context 'with GitHub integration' do
      let(:github_client) { double('Octokit::Client') }
      let(:repository) { double('Repository', default_branch: 'main') }
      let(:ref) { double('Ref', object: double(sha: 'abc123')) }
      
      before do
        allow(service).to receive(:github_repository).and_return('org/repo')
        allow(service).to receive(:github_access_token).and_return('token123')
        allow(Octokit::Client).to receive(:new).and_return(github_client)
        allow(github_client).to receive(:repository).and_return(repository)
        allow(github_client).to receive(:ref).and_return(ref)
        allow(github_client).to receive(:create_ref)
      end
      
      it 'creates GitHub branch when integration enabled' do
        expect(github_client).to receive(:create_ref)
          .with('org/repo', anything, 'abc123')
        
        create_service.call
      end
      
      it 'updates task with branch name' do
        allow(github_client).to receive(:create_ref)
        
        result = create_service.call
        task = result.value!
        
        expect(task.github_branch).to be_present
      end
    end
    
    context 'with sprint assignment' do
      let(:sprint) { create(:sprint, service: service) }
      let(:task_params_with_sprint) do
        task_params.merge(sprint_id: sprint.id)
      end
      
      subject(:create_service_with_sprint) do
        described_class.new(
          task_params: task_params_with_sprint,
          user: user,
          service: service
        )
      end
      
      it 'assigns task to sprint' do
        result = create_service_with_sprint.call
        task = result.value!
        
        expect(task.sprint).to eq(sprint)
      end
    end
    
    context 'with invalid parameters' do
      context 'when title is blank' do
        let(:task_params) { { title: '', description: 'Test' } }
        
        it 'returns Failure' do
          result = create_service.call
          
          expect(result).to be_failure
          expect(result.failure[0]).to eq(:validation_error)
        end
      end
      
      context 'when service is nil' do
        let(:service) { nil }
        
        it 'returns Failure with validation error' do
          result = create_service.call
          
          expect(result).to be_failure
          expect(result.failure).to eq([:validation_error, "서비스가 필요합니다"])
        end
      end
      
      context 'when user is nil' do
        let(:user) { nil }
        
        it 'returns Failure with validation error' do
          result = create_service.call
          
          expect(result).to be_failure
          expect(result.failure).to eq([:validation_error, "사용자가 필요합니다"])
        end
      end
    end
    
    context 'when GitHub API fails' do
      let(:github_client) { double('Octokit::Client') }
      
      before do
        allow(service).to receive(:github_repository).and_return('org/repo')
        allow(service).to receive(:github_access_token).and_return('token123')
        allow(Octokit::Client).to receive(:new).and_return(github_client)
        allow(github_client).to receive(:repository).and_raise(Octokit::NotFound)
      end
      
      it 'returns Failure but task is created' do
        result = create_service.call
        
        expect(result).to be_failure
        expect(result.failure[0]).to eq(:github_branch_error)
      end
    end
  end
end