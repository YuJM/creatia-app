# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GithubWebhookContract do
  subject(:contract) { described_class.new }

  describe '#call' do
    context 'with valid push event data' do
      let(:valid_params) do
        {
          ref: 'refs/heads/SHOP-142-add-cart-feature',
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
          ]
        }
      end

      it 'passes validation' do
        result = contract.call(valid_params)
        expect(result).to be_success
      end

      it 'returns valid data structure' do
        result = contract.call(valid_params)
        expect(result.to_h[:ref]).to eq('refs/heads/SHOP-142-add-cart-feature')
        expect(result.to_h[:repository][:name]).to eq('creatia-app')
      end
    end

    context 'with missing required fields' do
      let(:invalid_params) { {} }

      it 'fails validation' do
        result = contract.call(invalid_params)
        expect(result).to be_failure
      end

      it 'returns appropriate errors' do
        result = contract.call(invalid_params)
        expect(result.errors[:ref]).to include('필수 필드입니다')
        expect(result.errors[:repository]).to include('필수 필드입니다')
      end
    end

    context 'with branch name without Task ID' do
      let(:params_without_task_id) do
        {
          ref: 'refs/heads/feature-branch',
          repository: {
            name: 'creatia-app',
            full_name: 'creatia/creatia-app'
          }
        }
      end

      it 'fails validation' do
        result = contract.call(params_without_task_id)
        expect(result).to be_failure
      end

      it 'returns Task ID error' do
        result = contract.call(params_without_task_id)
        expect(result.errors[:ref]).to include('브랜치명에 유효한 Task ID가 없습니다')
      end
    end

    context 'with commit message without Task ID' do
      let(:params_without_task_id_in_commit) do
        {
          ref: 'refs/heads/SHOP-142-feature',
          repository: {
            name: 'creatia-app',
            full_name: 'creatia/creatia-app'
          },
          commits: [
            {
              message: 'Fix typo in documentation',
              author: {
                name: 'John Doe',
                email: 'john@example.com'
              }
            }
          ]
        }
      end

      it 'fails validation' do
        result = contract.call(params_without_task_id_in_commit)
        expect(result).to be_failure
      end

      it 'returns commit message error' do
        result = contract.call(params_without_task_id_in_commit)
        expect(result.errors[:commits]).to be_present
      end
    end

    context 'with various Task ID formats' do
      it 'accepts uppercase Task ID format' do
        params = {
          ref: 'refs/heads/SHOP-123-feature',
          repository: { name: 'test', full_name: 'org/test' }
        }
        result = contract.call(params)
        expect(result).to be_success
      end

      it 'accepts Task ID in middle of branch name' do
        params = {
          ref: 'refs/heads/feature/PAY-99/implementation',
          repository: { name: 'test', full_name: 'org/test' }
        }
        result = contract.call(params)
        expect(result).to be_success
      end

      it 'accepts Task ID with brackets in commit message' do
        params = {
          ref: 'refs/heads/ADMIN-1-feature',
          repository: { name: 'test', full_name: 'org/test' },
          commits: [
            {
              message: '[ADMIN-1] Initial implementation',
              author: { name: 'Dev', email: 'dev@example.com' }
            }
          ]
        }
        result = contract.call(params)
        expect(result).to be_success
      end
    end

    context 'with optional fields' do
      let(:params_with_optional) do
        {
          ref: 'refs/heads/SHOP-142-feature',
          repository: {
            name: 'creatia-app',
            full_name: 'creatia/creatia-app'
          },
          before: 'abc123',
          after: 'def456',
          created: true,
          deleted: false,
          forced: false
        }
      end

      it 'accepts optional fields' do
        result = contract.call(params_with_optional)
        expect(result).to be_success
      end
    end
  end
end