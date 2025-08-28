# frozen_string_literal: true

require 'dry-validation'

class GithubWebhookContract < ApplicationContract
  params do
    required(:ref).filled(:string)
    required(:repository).hash do
      required(:name).filled(:string)
      required(:full_name).filled(:string)
    end
    optional(:commits).array(:hash) do
      required(:message).filled(:string)
      required(:author).hash do
        required(:name).filled(:string)
        required(:email).filled(:string)
      end
    end
    optional(:before).maybe(:string)
    optional(:after).maybe(:string)
    optional(:pusher).maybe(:hash)
    optional(:sender).maybe(:hash)
    optional(:created).maybe(:bool)
    optional(:deleted).maybe(:bool)
    optional(:forced).maybe(:bool)
    optional(:head_commit).maybe(:hash)
  end
  
  rule(:ref) do
    # Task ID 형식 검증 (예: SHOP-142, PAY-23)
    unless value.match?(/[A-Z]+-\d+/)
      key.failure('브랜치명에 유효한 Task ID가 없습니다')
    end
  end
  
  rule(:commits).each do
    unless value[:message].match?(/\[?[A-Z]+-\d+\]?/)
      key.failure('커밋 메시지에 Task ID가 포함되어야 합니다')
    end
  end
end