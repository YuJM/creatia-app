# frozen_string_literal: true

require 'dry/validation'

# GitHub Webhook 페이로드 검증을 위한 Contract
class GithubWebhookContract < Dry::Validation::Contract
  # Task ID 형식 상수
  TASK_ID_FORMAT = /[A-Z]+-\d+/
  
  params do
    required(:ref).filled(:string)
    required(:repository).hash do
      required(:name).filled(:string)
      required(:full_name).filled(:string)
      optional(:id).filled(:integer)
      optional(:private).filled(:bool)
    end
    
    optional(:before).filled(:string)
    optional(:after).filled(:string)
    optional(:created).filled(:bool)
    optional(:deleted).filled(:bool)
    optional(:forced).filled(:bool)
    
    optional(:pusher).hash do
      required(:name).filled(:string)
      optional(:email).filled(:string)
    end
    
    optional(:sender).hash do
      required(:login).filled(:string)
      optional(:id).filled(:integer)
      optional(:type).filled(:string)
    end
    
    optional(:commits).array(:hash) do
      required(:message).filled(:string)
      required(:id).filled(:string)
      required(:author).hash do
        required(:name).filled(:string)
        required(:email).filled(:string)
      end
      optional(:timestamp).filled(:string)
      optional(:url).filled(:string)
    end
    
    optional(:head_commit).hash do
      required(:message).filled(:string)
      required(:id).filled(:string)
      required(:author).hash do
        required(:name).filled(:string)
        required(:email).filled(:string)
      end
    end
  end
  
  # 브랜치명에서 Task ID 검증
  rule(:ref) do
    branch_name = value.gsub('refs/heads/', '')
    
    # Task ID가 포함된 브랜치인지 확인 (예: feature/SHOP-123, TASK-456-description)
    unless branch_name.match?(TASK_ID_FORMAT)
      key.failure('브랜치명에 유효한 Task ID(예: SHOP-123)가 포함되어야 합니다')
    end
  end
  
  # 저장소 이름 검증
  rule(:repository) do
    repo_name = value[:name]
    
    # 저장소 이름이 유효한 형식인지 확인
    unless repo_name.match?(/\A[a-zA-Z0-9._-]+\z/)
      key.failure('저장소 이름이 유효하지 않습니다')
    end
    
    # 저장소 이름 길이 제한
    if repo_name.length > 100
      key.failure('저장소 이름이 너무 깁니다 (최대 100자)')
    end
  end
  
  # 커밋 메시지 검증 (커밋이 있는 경우)
  rule(:commits).each do |index:|
    commit = value
    
    # 커밋 메시지에 Task ID가 포함되어 있는지 확인
    unless commit[:message].match?(TASK_ID_FORMAT)
      key([:commits, index, :message]).failure('커밋 메시지에 Task ID(예: [SHOP-123])가 포함되어야 합니다')
    end
    
    # 커밋 메시지 길이 제한
    if commit[:message].length > 1000
      key([:commits, index, :message]).failure('커밋 메시지가 너무 깁니다 (최대 1000자)')
    end
    
    # 이메일 형식 검증
    email = commit.dig(:author, :email)
    if email && !email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
      key([:commits, index, :author, :email]).failure('유효하지 않은 이메일 형식입니다')
    end
  end
  
  # Head commit 검증 (head_commit이 있는 경우)
  rule(:head_commit) do
    next unless value
    
    # Head commit 메시지에도 Task ID 확인
    unless value[:message].match?(TASK_ID_FORMAT)
      key([:head_commit, :message]).failure('Head commit 메시지에 Task ID가 포함되어야 합니다')
    end
    
    # 이메일 형식 검증
    email = value.dig(:author, :email)
    if email && !email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
      key([:head_commit, :author, :email]).failure('유효하지 않은 이메일 형식입니다')
    end
  end
  
  # 전체 페이로드 보안 검증
  rule do
    # 페이로드 크기 제한 (대략적으로 추정)
    total_size = values.to_json.bytesize
    if total_size > 1.megabyte
      key.failure('페이로드가 너무 큽니다 (최대 1MB)')
    end
    
    # 커밋 수 제한
    if values[:commits]&.size.to_i > 100
      key(:commits).failure('한 번에 처리할 수 있는 커밋 수를 초과했습니다 (최대 100개)')
    end
  end
end
