# frozen_string_literal: true

# Task 관련 비즈니스 로직을 처리하는 Service
# 조회는 TaskQueryService로 위임하고 CRUD 작업에 집중
class TaskService
  include Dry::Monads[:result, :do]

  pattr_initialize [ :organization!, :user ]

  def initialize(organization, user = nil)
    @organization = organization
    @user = user
    @query_service = TaskQueryService.new(organization)
    @repository = TaskRepository.new
  end

  # Task 목록 조회 (TaskQueryService로 위임)
  def list(filters = {})
    @query_service.list_with_users(filters)
  end

  # 단일 Task 조회 (TaskQueryService로 위임)
  def find(task_id)
    @query_service.find_with_user(task_id)
  end

  # Sprint별 Task 조회 (TaskQueryService로 위임)
  def list_for_sprint(sprint_id, include_completed = false)
    @query_service.list_for_sprint(sprint_id, include_completed)
  end

  # 사용자별 할당된 Task 조회 (TaskQueryService로 위임)
  def list_for_assignee(user_id, filters = {})
    @query_service.list_for_assignee(user_id, filters)
  end

  # 대시보드 요약 (TaskQueryService로 위임)
  def dashboard_summary
    @query_service.dashboard_summary
  end

  # Task 생성
  def create(params)
    begin
      task_params = params.merge(
        organization_id: @organization.id.to_s,
        created_by_id: @user&.id&.to_s
      )

      result = @repository.create(task_params)

      case result
      when Success
        task = result.value!

        # User 스냅샷 동기화 스케줄링
        schedule_user_snapshot_sync(task)

        # 생성된 Task를 DTO로 변환하여 반환
        @query_service.find_with_user(task.id.to_s)
      when Failure
        result
      end
    rescue Mongoid::Errors::Validations => e
      Failure([:validation_error, e.record.errors.to_h])
    rescue ActiveRecord::RecordNotFound => e
      Failure([:not_found, e.message])
    rescue => e
      Rails.logger.error "[TaskService] Task 생성 실패: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      Failure([:creation_failed, e.message])
    end
  end

  # Task 수정
  def update(task_id, params)
    begin
      # User 관련 필드 변경 감지
      old_assignee_id = nil
      old_reviewer_id = nil

      if params.key?(:assignee_id) || params.key?(:reviewer_id)
        task_result = @repository.find(task_id)
        return task_result unless task_result.success?

        old_task = task_result.value!
        old_assignee_id = old_task.assignee_id
        old_reviewer_id = old_task.reviewer_id
      end

      # Repository를 통한 업데이트
      result = @repository.update(task_id, params)

      case result
      when Success
        task = result.value!

        # User 할당이 변경된 경우 스냅샷 동기화
        if params.key?(:assignee_id) && params[:assignee_id] != old_assignee_id
          schedule_user_snapshot_sync(task, :assignee)
        end

        if params.key?(:reviewer_id) && params[:reviewer_id] != old_reviewer_id
          schedule_user_snapshot_sync(task, :reviewer)
        end

        # 업데이트된 Task를 DTO로 변환하여 반환
        @query_service.find_with_user(task.id.to_s)
      when Failure
        result
      end
    rescue Mongoid::Errors::Validations => e
      Failure([:validation_error, e.record.errors.to_h])
    rescue ActiveRecord::RecordNotFound => e
      Failure([:not_found, e.message])
    rescue => e
      Rails.logger.error "[TaskService] Task 수정 실패: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      Failure([:update_failed, e.message])
    end
  end

  # Task 삭제
  def destroy(task_id)
    @repository.delete(task_id)
  end

  # Task 상태 변경
  def change_status(task_id, new_status)
    update(task_id, { status: new_status })
  end

  # Task 할당
  def assign(task_id, assignee_id)
    # 할당자 유효성 검증
    if assignee_id.present?
      assignee = User.find_by(id: assignee_id)
      return Failure(:invalid_assignee) unless assignee
      return Failure(:not_member) unless assignee.member_of?(@organization)
    end

    update(task_id, { assignee_id: assignee_id })
  end

  # 대량 Task 상태 변경
  def bulk_update_status(task_ids, new_status)
    @repository.bulk_update_status(task_ids, new_status, @organization.id.to_s)
  end

  # Task 재정렬
  def reorder(task_id, new_position, status = nil)
    @repository.reorder(task_id, new_position, status)
  end

  # 사용 가능한 Sprint 목록
  def available_sprints
    Sprint.where(organization_id: @organization.id, status: [ "planned", "active" ])
          .map { |sprint| Dto::SprintDto.from_model(sprint) }
  end

  # 사용 가능한 담당자 목록 (UserDataResolver 활용)
  def available_assignees
    user_ids = @organization.users.pluck(:id)
    return [] if user_ids.empty?

    user_resolver = UserDataResolver.new
    resolved_users = user_resolver.resolve_users_batch(user_ids.map(&:to_s))

    resolved_users.values
  end

  private

  # User 스냅샷 동기화 스케줄링
  def schedule_user_snapshot_sync(task, role_type = nil)
    return unless task

    sync_jobs = []

    if role_type.nil? || role_type == :assignee
      if task.assignee_id.present?
        sync_jobs << { task_id: task.id.to_s, user_id: task.assignee_id, role: "assignee" }
      end
    end

    if role_type.nil? || role_type == :reviewer
      if task.reviewer_id.present?
        sync_jobs << { task_id: task.id.to_s, user_id: task.reviewer_id, role: "reviewer" }
      end
    end

    sync_jobs.each do |job_data|
      UserSnapshotSyncJob.perform_later(
        job_data[:task_id],
        job_data[:user_id],
        job_data[:role]
      )
    end

    Rails.logger.info "[TaskService] #{sync_jobs.size}개 User 스냅샷 동기화 예약" if sync_jobs.any?
  end
end
