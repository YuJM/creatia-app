# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TasksController, type: :controller do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let(:membership) { create(:organization_membership, user: user, organization: organization) }
  let(:task) { create(:task, organization: organization) }

  before do
    sign_in user
    ActsAsTenant.current_tenant = organization
    allow(controller).to receive(:current_organization).and_return(organization)
    allow(controller).to receive(:current_organization_membership).and_return(membership)
  end

  describe 'POST #create' do
    let(:task_params) do
      {
        title: '테스트 작업',
        description: '테스트 설명',
        priority: 'medium',
        due_date: 1.week.from_now.to_date
      }
    end

    context 'GitHub 연동이 비활성화된 경우' do
      before do
        allow(organization).to receive(:github_integration_active?).and_return(false)
      end

      it '일반 Task를 성공적으로 생성한다' do
        post :create, params: { task: task_params }
        
        expect(response).to have_http_status(:created)
        expect(Task.last.title).to eq('테스트 작업')
      end
    end

    context 'GitHub 연동이 활성화된 경우' do
      before do
        allow(organization).to receive(:github_integration_active?).and_return(true)
        allow(membership).to receive(:developer_role?).and_return(true)
        
        # CreateTaskWithBranchService mock
        allow(CreateTaskWithBranchService).to receive(:new).and_return(
          double(call: double(success?: true, value!: task))
        )
      end

      it 'create_github_branch 파라미터가 true일 때 GitHub 브랜치 생성 서비스를 호출한다' do
        expect(CreateTaskWithBranchService).to receive(:new).with(
          hash_including(task_params),
          user,
          organization
        )

        post :create, params: { task: task_params, create_github_branch: 'true' }
        
        expect(response).to have_http_status(:created)
      end

      it 'create_github_branch 파라미터가 없으면 일반 Task를 생성한다' do
        expect(CreateTaskWithBranchService).not_to receive(:new)

        post :create, params: { task: task_params }
        
        expect(response).to have_http_status(:created)
      end
    end
  end

  describe 'GET #metrics' do
    before do
      allow(controller).to receive(:set_task).and_return(nil)
      controller.instance_variable_set(:@task, task)
    end

    it 'Task 메트릭 정보를 반환한다' do
      get :metrics, params: { id: task.id }
      
      expect(response).to have_http_status(:success)
      
      json_response = JSON.parse(response.body)
      expect(json_response).to have_key('metrics')
      expect(json_response).to have_key('user_friendly')
      
      expect(json_response['metrics']).to have_key('completion_percentage')
      expect(json_response['metrics']).to have_key('complexity_score')
      expect(json_response['user_friendly']).to have_key('efficiency_status')
      expect(json_response['user_friendly']).to have_key('complexity_description')
    end

    it '올바른 복잡도 설명을 반환한다' do
      get :metrics, params: { id: task.id }
      
      json_response = JSON.parse(response.body)
      complexity_desc = json_response['user_friendly']['complexity_description']
      
      expect(complexity_desc).to match(/🟢|🟡|🟠|🔴/)
      expect(complexity_desc).to include('작업')
    end
  end

  describe 'GET #show' do
    before do
      allow(controller).to receive(:set_task).and_return(nil)
      controller.instance_variable_set(:@task, task)
    end

    it 'Task 정보와 함께 메트릭을 포함하여 반환한다' do
      get :show, params: { id: task.id }
      
      expect(response).to have_http_status(:success)
      expect(assigns(:task_metrics)).to be_a(TaskMetrics)
    end
  end

  describe 'private methods' do
    describe '#github_integration_enabled?' do
      context '개발자 역할이고 GitHub 통합이 활성화된 경우' do
        before do
          allow(membership).to receive(:developer_role?).and_return(true)
          allow(organization).to receive(:github_integration_active?).and_return(true)
        end

        it 'true를 반환한다' do
          expect(controller.send(:github_integration_enabled?)).to be true
        end
      end

      context '개발자 역할이 아닌 경우' do
        before do
          allow(membership).to receive(:developer_role?).and_return(false)
        end

        it 'false를 반환한다' do
          expect(controller.send(:github_integration_enabled?)).to be false
        end
      end
    end

    describe '#calculate_completion_percentage' do
      it 'todo 상태에 대해 0%를 반환한다' do
        task.status = 'todo'
        result = controller.send(:calculate_completion_percentage, task)
        expect(result).to eq(0.0)
      end

      it 'in_progress 상태에 대해 50%를 반환한다' do
        task.status = 'in_progress'
        result = controller.send(:calculate_completion_percentage, task)
        expect(result).to eq(50.0)
      end

      it 'done 상태에 대해 100%를 반환한다' do
        task.status = 'done'
        result = controller.send(:calculate_completion_percentage, task)
        expect(result).to eq(100.0)
      end
    end
  end
end