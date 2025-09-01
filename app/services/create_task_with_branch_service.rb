# frozen_string_literal: true

require 'dry/monads'
require 'dry/monads/do'
require 'attr_extras'
require 'octokit'

class CreateTaskWithBranchService
  extend AttrExtras::AttrInitialize
  include AttrExtras::Memoize
  include Dry::Monads[:result, :do]
  
  extend Dry::Initializer
  
  param :task_params
  param :user
  param :service
  
  def call
    validated_params = yield validate_params
    task = yield create_task(validated_params)
    yield create_github_branch(task) if github_integration_enabled?
    yield assign_to_sprint(task) if sprint_id.present?
    yield notify_team(task)
    
    Success(task)
  rescue ActiveRecord::RecordInvalid => e
    Failure([:record_invalid, e.message])
  rescue Octokit::Error => e
    Failure([:github_error, e.message])
  rescue => e
    Failure([:unexpected_error, e.message])
  end
  
  private
  
  attr_reader :task
  
  memoize def github_client
    return nil unless github_integration_enabled?
    
    Octokit::Client.new(
      access_token: service.github_access_token
    )
  end
  
  def validate_params
    return Failure([:validation_error, "서비스가 필요합니다"]) unless service
    return Failure([:validation_error, "사용자가 필요합니다"]) unless user
    return Failure([:validation_error, "제목이 필요합니다"]) if task_params[:title].blank?
    
    Success(task_params)
  end
  
  def create_task(params)
    task = service.tasks.build(params)
    task.creator = user
    
    if task.save
      Success(task)
    else
      Failure([:validation_error, task.errors.full_messages.join(', ')])
    end
  end
  
  def create_github_branch(task)
    return Success(task) unless github_client
    
    repo = service.github_repository
    default_branch = github_client.repository(repo).default_branch
    
    # Task ID를 포함한 브랜치명 생성
    branch_name = "#{task.task_id}-#{task.title.parameterize}"
    
    # 기본 브랜치의 최신 커밋 SHA 가져오기
    base_sha = github_client.ref(repo, "heads/#{default_branch}").object.sha
    
    # 새 브랜치 생성
    github_client.create_ref(
      repo,
      "refs/heads/#{branch_name}",
      base_sha
    )
    
    task.update!(github_branch: branch_name)
    Success(task)
  rescue => e
    Failure([:github_branch_error, e.message])
  end
  
  def github_integration_enabled?
    service.respond_to?(:github_repository) &&
    service.github_repository.present? && 
    service.respond_to?(:github_access_token) &&
    service.github_access_token.present?
  end
  
  def sprint_id
    task_params[:sprint_id]
  end
  
  def assign_to_sprint(task)
    sprint = service.sprints.find_by(id: sprint_id)
    
    if sprint
      task.update!(sprint: sprint)
      Success(task)
    else
      Failure([:sprint_not_found, "Sprint #{sprint_id} not found"])
    end
  end
  
  def notify_team(task)
    # Job이 정의되어 있다면 실행
    if defined?(TaskCreatedNotificationJob)
      TaskCreatedNotificationJob.perform_later(task)
    end
    
    Success(task)
  end
end