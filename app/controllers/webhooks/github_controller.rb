# frozen_string_literal: true

class Webhooks::GithubController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_github_signature
  
  def push
    contract = GithubWebhookContract.new
    result = contract.call(webhook_params)
    
    if result.success?
      ProcessGithubPushJob.perform_later(result.to_h)
      head :ok
    else
      render json: { errors: result.errors.to_h }, status: :unprocessable_entity
    end
  end
  
  def issues
    # Issues webhook 처리
    head :ok
  end
  
  def pull_request
    # Pull Request webhook 처리
    head :ok
  end
  
  private
  
  def webhook_params
    params.permit!.to_h.deep_symbolize_keys
  end
  
  def verify_github_signature
    request_body = request.body.read
    signature = "sha256=#{OpenSSL::HMAC.hexdigest('sha256', webhook_secret, request_body)}"
    
    unless Rack::Utils.secure_compare(signature, request.headers['X-Hub-Signature-256'].to_s)
      head :unauthorized and return
    end
    
    request.body.rewind
  end
  
  def webhook_secret
    ENV['GITHUB_WEBHOOK_SECRET'] || Rails.application.credentials.dig(:github, :webhook_secret) || 'default-secret'
  end
end