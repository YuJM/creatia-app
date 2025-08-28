# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GithubPayload do
  let(:sample_payload) do
    {
      ref: 'refs/heads/feature/SHOP-142-payment-improvement',
      before: 'abc123',
      after: 'def456',
      repository: {
        name: 'creatia-app',
        full_name: 'creatia/creatia-app'
      },
      pusher: {
        name: 'john_doe',
        email: 'john@example.com'
      },
      commits: [
        {
          id: 'commit1',
          message: '[SHOP-142] Add payment validation',
          author: {
            name: 'John Doe',
            email: 'john@example.com'
          }
        },
        {
          id: 'commit2', 
          message: 'Fix typo in payment form',
          author: {
            name: 'John Doe',
            email: 'john@example.com'
          }
        }
      ],
      forced: false,
      deleted: false,
      created: true
    }
  end

  subject(:payload) { described_class.new(sample_payload) }

  describe 'initialization' do
    it 'creates payload with required fields' do
      expect(payload.ref).to eq('refs/heads/feature/SHOP-142-payment-improvement')
      expect(payload.repository['name']).to eq('creatia-app')
    end

    it 'sets default values for optional fields' do
      expect(payload.commits).to be_an(Array)
      expect(payload.forced).to be false
      expect(payload.deleted).to be false
      expect(payload.created).to be true
    end

    it 'raises error when required fields are missing' do
      expect { described_class.new({}) }.to raise_error(ArgumentError)
    end
  end

  describe 'convenience methods' do
    describe '#branch_name' do
      it 'extracts branch name from ref' do
        expect(payload.branch_name).to eq('feature/SHOP-142-payment-improvement')
      end

      context 'when ref is not a branch' do
        before { payload.ref = 'refs/tags/v1.0.0' }

        it 'returns nil' do
          expect(payload.branch_name).to be_nil
        end
      end
    end

    describe '#repository_name' do
      it 'returns repository name' do
        expect(payload.repository_name).to eq('creatia-app')
      end
    end

    describe '#repository_full_name' do
      it 'returns full repository name' do
        expect(payload.repository_full_name).to eq('creatia/creatia-app')
      end
    end

    describe '#pusher_name' do
      it 'returns pusher name' do
        expect(payload.pusher_name).to eq('john_doe')
      end
    end

    describe '#pusher_email' do
      it 'returns pusher email' do
        expect(payload.pusher_email).to eq('john@example.com')
      end
    end

    describe '#commit_messages' do
      it 'returns array of commit messages' do
        messages = payload.commit_messages
        expect(messages).to include('[SHOP-142] Add payment validation')
        expect(messages).to include('Fix typo in payment form')
      end

      context 'when no commits' do
        before { payload.commits = nil }

        it 'returns empty array' do
          expect(payload.commit_messages).to eq([])
        end
      end
    end
  end

  describe 'task ID methods' do
    describe '#has_task_id_in_branch?' do
      it 'returns true when branch contains task ID' do
        expect(payload.has_task_id_in_branch?).to be true
      end

      context 'when branch does not contain task ID' do
        before { payload.ref = 'refs/heads/main' }

        it 'returns false' do
          expect(payload.has_task_id_in_branch?).to be false
        end
      end
    end

    describe '#extract_task_id' do
      it 'extracts task ID from branch name' do
        expect(payload.extract_task_id).to eq('SHOP-142')
      end

      context 'when no task ID in branch' do
        before { payload.ref = 'refs/heads/main' }

        it 'returns nil' do
          expect(payload.extract_task_id).to be_nil
        end
      end
    end

    describe '#commits_with_task_ids' do
      it 'returns commits containing task IDs' do
        commits = payload.commits_with_task_ids
        expect(commits.size).to eq(1)
        expect(commits.first).to include('SHOP-142')
      end
    end
  end

  describe 'branch type methods' do
    describe '#is_main_branch?' do
      it 'returns false for feature branch' do
        expect(payload.is_main_branch?).to be false
      end

      context 'when main branch' do
        before { payload.ref = 'refs/heads/main' }

        it 'returns true' do
          expect(payload.is_main_branch?).to be true
        end
      end
    end

    describe '#is_feature_branch?' do
      it 'returns true for feature branch' do
        expect(payload.is_feature_branch?).to be true
      end

      context 'when not feature branch' do
        before { payload.ref = 'refs/heads/main' }

        it 'returns false' do
          expect(payload.is_feature_branch?).to be false
        end
      end
    end

    describe '#is_hotfix_branch?' do
      it 'returns false for feature branch' do
        expect(payload.is_hotfix_branch?).to be false
      end

      context 'when hotfix branch' do
        before { payload.ref = 'refs/heads/hotfix/SHOP-143-critical-bug' }

        it 'returns true' do
          expect(payload.is_hotfix_branch?).to be true
        end
      end
    end

    describe '#is_release_branch?' do
      it 'returns false for feature branch' do
        expect(payload.is_release_branch?).to be false
      end

      context 'when release branch' do
        before { payload.ref = 'refs/heads/release/v1.2.0' }

        it 'returns true' do
          expect(payload.is_release_branch?).to be true
        end
      end
    end
  end
end