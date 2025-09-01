# frozen_string_literal: true

require 'dry-transaction'

# Task 생성 트랜잭션
class TaskCreationTransaction
  include Dry::Transaction
  include Inject['validators.task_create', 'repositories.task']

  # Step 1: 파라미터 검증
  step :validate_params
  
  # Step 2: 조직 권한 확인
  step :check_organization_permission
  
  # Step 3: 서비스 컨텍스트 확인
  step :validate_service_context
  
  # Step 4: 담당자 검증
  step :validate_assignee
  
  # Step 5: Task ID 생성
  step :generate_task_id
  
  # Step 6: Task 생성
  step :create_task
  
  # Step 7: Sprint 연결
  step :link_to_sprint
  
  # Step 8: GitHub 이슈 생성
  step :create_github_issue
  
  # Step 9: DTO 생성
  map :build_dto

  private

  def validate_params(input)
    result = task_create.call(input[:params])
    
    if result.success?
      Success(input.merge(validated_params: result.to_h))
    else
      Failure([:validation_error, result.errors.to_h])
    end
  end

  def check_organization_permission(input)
    user = input[:user]
    organization = input[:organization]
    
    if user && organization && user.can_create_tasks?(organization)
      Success(input)
    else
      Failure([:permission_denied, '작업 생성 권한이 없습니다'])
    end
  end

  def validate_service_context(input)
    service = input[:service]
    params = input[:validated_params]
    
    if params[:service_id] && !service
      Failure([:not_found, '서비스를 찾을 수 없습니다'])
    else
      Success(input)
    end
  end

  def validate_assignee(input)
    assignee_id = input[:validated_params][:assignee_id]
    organization = input[:organization]
    
    if assignee_id
      assignee = User.cached_find(assignee_id)
      
      if assignee && assignee.member_of?(organization)
        Success(input.merge(assignee: assignee))
      else
        Failure([:invalid_assignee, '유효하지 않은 담당자입니다'])
      end
    else
      Success(input)
    end
  end

  def generate_task_id(input)
    service = input[:service]
    organization = input[:organization]
    
    prefix = service&.task_prefix || organization.task_prefix || 'TASK'
    sequence = organization.next_task_sequence
    
    task_id = "#{prefix}-#{sequence.to_s.rjust(3, '0')}"
    
    Success(input.merge(task_id: task_id))
  end

  def create_task(input)
    attributes = input[:validated_params].merge(
      task_id: input[:task_id],
      organization_id: input[:organization].id,
      service_id: input[:service]&.id,
      assignee_id: input[:assignee]&.id,
      created_by_id: input[:user].id,
      status: 'todo'
    )
    
    result = task_repository.create(attributes)
    
    result.bind do |task|
      Success(input.merge(task: task))
    end
  end

  def link_to_sprint(input)
    sprint_id = input[:validated_params][:sprint_id]
    task = input[:task]
    
    if sprint_id
      sprint = Sprint.find_by(id: sprint_id, organization_id: input[:organization].id)
      
      if sprint
        task.update(sprint_id: sprint.id)
        Success(input.merge(sprint: sprint))
      else
        # Sprint를 찾을 수 없어도 실패하지 않고 진행
        Success(input)
      end
    else
      Success(input)
    end
  end

  def create_github_issue(input)
    task = input[:task]
    service = input[:service]
    
    if service&.github_enabled? && input[:validated_params][:create_github_issue]
      # GitHub 이슈 생성 로직
      # 실패해도 트랜잭션 전체가 실패하지 않도록 처리
      begin
        # GitHubService.create_issue(task, service)
        Success(input)
      rescue StandardError => e
        Rails.logger.error "GitHub issue creation failed: #{e.message}"
        Success(input)
      end
    else
      Success(input)
    end
  end

  def build_dto(input)
    task = input[:task]
    Dto::EnhancedTaskDto.from_model(task)
  end
end