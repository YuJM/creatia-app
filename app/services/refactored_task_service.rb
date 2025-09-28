# frozen_string_literal: true

require 'dry-initializer'
require 'dry-monads'

# dry-initializer와 의존성 주입을 사용한 리팩토링된 TaskService
class RefactoredTaskService
  extend Dry::Initializer
  include Dry::Monads[:result, :maybe, :try]
  include Inject['repositories.task', 'validators.task_create', 'validators.task_update']

  # dry-initializer로 의존성 정의
  param :organization, type: Types.Interface(:id, :users, :id)
  option :user, type: Types.Interface(:id, :name), optional: true
  option :current_user, type: Types.Interface(:id), optional: true

  # Task 목록 조회 (Maybe 모나드 사용)
  def list(filters = {})
    validated_filters = validate_filters(filters)
    
    task_repository.find_by_organization(organization.id, validated_filters)
      .bind { |tasks| Success(tasks.map { |task| build_task_dto(task) }) }
  end

  # 단일 Task 조회 (Maybe 체이닝)
  def find(task_id)
    Maybe(task_id)
      .bind { |id| validate_task_id(id) }
      .bind { |id| find_task_in_organization(id) }
      .to_result(:task_not_found)
      .bind { |task| Success(build_task_dto(task)) }
  end

  # Task 생성 (Transaction 사용)
  def create(params)
    creation_transaction = TaskCreationTransaction.new
    
    input = {
      params: params,
      user: current_user || user,
      organization: organization,
      service: find_service_context(params[:service_id])
    }
    
    creation_transaction.call(input).bind do |result|
      Success(result[:task])
    end
  end

  # Task 업데이트 (복합 validation)
  def update(task_id, params)
    Try { validate_update_params(params) }
      .to_result
      .bind { |validated| find_and_authorize_task(task_id) }
      .bind { |task| perform_update(task, params) }
      .bind { |task| Success(build_task_dto(task)) }
  end

  # Task 상태 변경 (상태 전이 검증)
  def change_status(task_id, new_status, context = {})
    find_and_authorize_task(task_id)
      .bind { |task| validate_status_transition(task, new_status) }
      .bind { |task| apply_status_change(task, new_status, context) }
      .bind { |task| trigger_status_change_events(task, new_status, context) }
      .bind { |task| Success(build_task_dto(task)) }
  end

  # Task 할당 (팀 멤버십 검증)
  def assign(task_id, assignee_id, context = {})
    find_and_authorize_task(task_id)
      .bind { |task| validate_assignee_eligibility(assignee_id) }
      .bind { |assignee| perform_assignment(task_id, assignee, context) }
      .bind { |task| trigger_assignment_events(task, context) }
      .bind { |task| Success(build_task_dto(task)) }
  end

  # Task 통계 (집계 쿼리)
  def statistics
    Try do
      {
        basic_stats: basic_statistics,
        status_breakdown: status_breakdown,
        priority_distribution: priority_distribution,
        assignee_workload: assignee_workload,
        time_metrics: time_metrics
      }
    end.to_result.bind { |stats| Success(Dto::TaskStatisticsDto.new(stats)) }
  end

  private

  # 필터 검증 (스키마 사용)
  def validate_filters(filters)
    schema = API::V1::TaskParamsSchema::IndexSchema
    result = schema.call(filters)
    result.success? ? result.to_h : {}
  end

  # Task ID 검증
  def validate_task_id(task_id)
    return None() unless task_id.present?
    return None() unless task_id.match?(Types::ID.primitive)
    Some(task_id)
  end

  # 조직 내 Task 조회
  def find_task_in_organization(task_id)
    task_repository.find_by_organization(organization.id, { id: task_id })
      .bind { |tasks| tasks.first ? Some(tasks.first) : None() }
  end

  # Task 조회 및 권한 확인
  def find_and_authorize_task(task_id)
    find(task_id).bind do |task_dto|
      if can_modify_task?(task_dto)
        # DTO에서 모델로 변환하거나 Repository에서 직접 조회
        task_repository.find(task_id)
      else
        Failure([:permission_denied, '작업 수정 권한이 없습니다'])
      end
    end
  end

  # 담당자 자격 검증
  def validate_assignee_eligibility(assignee_id)
    return Success(nil) unless assignee_id.present?

    Maybe(User.cached_find(assignee_id))
      .bind { |user| user.member_of?(organization) ? Some(user) : None() }
      .to_result(:invalid_assignee)
  end

  # 상태 전이 검증
  def validate_status_transition(task, new_status)
    current_status = task.status
    
    valid_transitions = {
      'todo' => %w[in_progress archived],
      'in_progress' => %w[todo review done archived],
      'review' => %w[in_progress done todo],
      'done' => %w[todo in_progress],  # 재오픈 가능
      'archived' => %w[todo]  # 복원 가능
    }

    if valid_transitions[current_status]&.include?(new_status)
      Success(task)
    else
      Failure([:invalid_transition, \"#{current_status}에서 #{new_status}로 변경할 수 없습니다\"])
    end
  end

  # 상태 변경 실행
  def apply_status_change(task, new_status, context)
    updates = { status: new_status, updated_at: Time.current }
    
    # 상태별 추가 로직
    case new_status
    when 'in_progress'
      updates[:started_at] = Time.current unless task.started_at
    when 'done'
      updates[:completed_at] = Time.current
      updates[:completion_percentage] = 100
    when 'todo'
      # 재오픈 시 완료 관련 필드 초기화
      updates[:completed_at] = nil
      updates[:completion_percentage] = 0
    end
    
    task_repository.update(task.id, updates)
  end

  # 할당 실행
  def perform_assignment(task_id, assignee, context)
    updates = {
      assignee_id: assignee&.id,
      assigned_at: assignee ? Time.current : nil,
      updated_at: Time.current
    }
    
    task_repository.update(task_id, updates)
  end

  # Task DTO 생성
  def build_task_dto(task)
    Dto::TaskDto.from_model(task)
  end

  # 권한 확인
  def can_modify_task?(task_dto)
    return true if current_user&.admin?
    return true if task_dto.assignee_id == current_user&.id
    return true if current_user&.can_manage_tasks?(organization)
    false
  end

  # 서비스 컨텍스트 조회
  def find_service_context(service_id)
    return nil unless service_id
    Service.find_by(id: service_id, organization_id: organization.id)
  end

  # 업데이트 파라미터 검증
  def validate_update_params(params)
    validator = Container['validators.task_update']
    result = validator.call(params)
    
    if result.success?
      result.to_h
    else
      raise Dry::Validation::Error, result.errors.to_h
    end
  end

  # 기본 통계
  def basic_statistics
    task_repository.count({ organization_id: organization.id })
  end

  # 상태별 분류
  def status_breakdown
    task_repository.status_statistics(organization.id).value_or({})
  end

  # 우선순위 분포  
  def priority_distribution
    task_repository.priority_statistics(organization.id).value_or({})
  end

  # 담당자별 워크로드
  def assignee_workload
    # 복잡한 집계 쿼리는 Repository에 위임
    {}
  end

  # 시간 메트릭
  def time_metrics
    {
      avg_completion_time: calculate_avg_completion_time,
      overdue_count: count_overdue_tasks,
      due_soon_count: count_due_soon_tasks
    }
  end

  # 이벤트 트리거링
  def trigger_status_change_events(task, new_status, context)
    # 이벤트 발행 로직
    Success(task)
  end

  def trigger_assignment_events(task, context)
    # 할당 이벤트 발행 로직
    Success(task)
  end

  # 헬퍼 메서드들
  def calculate_avg_completion_time
    # 평균 완료 시간 계산
    0
  end

  def count_overdue_tasks
    task_repository.count({
      organization_id: organization.id,
      due_date: { '$lt' => Date.current },
      status: { '$ne' => 'done' }
    })
  end

  def count_due_soon_tasks
    task_repository.count({
      organization_id: organization.id,
      due_date: { '$gte' => Date.current, '$lte' => 7.days.from_now.to_date },
      status: { '$ne' => 'done' }
    })
  end
end