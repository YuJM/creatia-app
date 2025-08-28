# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Webhooks::GithubController, type: :controller do
  let(:webhook_secret) { 'test-webhook-secret' }
  let(:payload) do
    {
      ref: 'refs/heads/SHOP-142-feature',
      repository: {
        name: 'creatia-app',
        full_name: 'creatia/creatia-app'
      },
      commits: [
        {
          message: '[SHOP-142] Add shopping cart',
          author: {
            name: 'Developer',
            email: 'dev@example.com'
          }
        }
      ]
    }
  end
  let(:payload_json) { payload.to_json }

  before do
    allow(controller).to receive(:webhook_secret).and_return(webhook_secret)
    allow(ProcessGithubPushJob).to receive(:perform_later)
  end

  describe 'POST #push' do
    context 'with valid signature and payload' do
      let(:signature) do
        "sha256=#{OpenSSL::HMAC.hexdigest('sha256', webhook_secret, payload_json)}"
      end

      before do
        request.headers['X-Hub-Signature-256'] = signature
        request.headers['Content-Type'] = 'application/json'
      end

      it 'returns success' do
        post :push, body: payload_json, format: :json
        expect(response).to have_http_status(:ok)
      end

      it 'enqueues ProcessGithubPushJob' do
        expect(ProcessGithubPushJob).to receive(:perform_later).with(hash_including(
          ref: 'refs/heads/SHOP-142-feature'
        ))
        post :push, body: payload_json, format: :json
      end
    end

    context 'with invalid signature' do
      before do
        request.headers['X-Hub-Signature-256'] = 'invalid-signature'
        request.headers['Content-Type'] = 'application/json'
      end

      it 'returns unauthorized' do
        post :push, body: payload_json, format: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it 'does not enqueue job' do
        expect(ProcessGithubPushJob).not_to receive(:perform_later)
        post :push, body: payload_json, format: :json
      end
    end

    context 'with missing signature' do
      before do
        request.headers['Content-Type'] = 'application/json'
      end

      it 'returns unauthorized' do
        post :push, body: payload_json, format: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid payload' do
      let(:invalid_payload) do
        {
          ref: 'refs/heads/feature-without-task-id',
          repository: {
            name: 'creatia-app',
            full_name: 'creatia/creatia-app'
          }
        }
      end
      let(:invalid_payload_json) { invalid_payload.to_json }
      let(:signature) do
        "sha256=#{OpenSSL::HMAC.hexdigest('sha256', webhook_secret, invalid_payload_json)}"
      end

      before do
        request.headers['X-Hub-Signature-256'] = signature
        request.headers['Content-Type'] = 'application/json'
      end

      it 'returns unprocessable entity' do
        post :push, body: invalid_payload_json, format: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns validation errors' do
        post :push, body: invalid_payload_json, format: :json
        body = JSON.parse(response.body)
        expect(body['errors']).to be_present
        expect(body['errors']['ref']).to include('브랜치명에 유효한 Task ID가 없습니다')
      end

      it 'does not enqueue job' do
        expect(ProcessGithubPushJob).not_to receive(:perform_later)
        post :push, body: invalid_payload_json, format: :json
      end
    end
  end

  describe 'POST #issues' do
    let(:signature) do
      "sha256=#{OpenSSL::HMAC.hexdigest('sha256', webhook_secret, payload_json)}"
    end

    before do
      request.headers['X-Hub-Signature-256'] = signature
      request.headers['Content-Type'] = 'application/json'
    end

    it 'returns success' do
      post :issues, body: payload_json, format: :json
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST #pull_request' do
    let(:signature) do
      "sha256=#{OpenSSL::HMAC.hexdigest('sha256', webhook_secret, payload_json)}"
    end

    before do
      request.headers['X-Hub-Signature-256'] = signature
      request.headers['Content-Type'] = 'application/json'
    end

    it 'returns success' do
      post :pull_request, body: payload_json, format: :json
      expect(response).to have_http_status(:ok)
    end
  end
end