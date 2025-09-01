# frozen_string_literal: true

require 'dry-monads'

module API
  module V1
    # dry-rb 패턴을 활용한 API 컨트롤러
    class TasksController < ApplicationController
      include Dry::Monads[:result, :maybe]
      include Inject['repositories.task']
      
      before_action :authenticate_user!
      before_action :set_organization
      before_action :set_task_service
      
      # GET /api/v1/tasks
      def index
        schema_result = API::V1::TaskParamsSchema.validate_index(params.to_unsafe_h)
        
        if schema_result.success?
          result = @task_service.list(schema_result.to_h)
          handle_service_result(result) { |tasks| render_tasks_collection(tasks) }
        else
          render_validation_errors(schema_result.errors)
        end
      end
      
      # GET /api/v1/tasks/:id
      def show
        Maybe(params[:id])
          .bind { |id| validate_task_id(id) }
          .maybe { |id| @task_service.find(id) }
          .bind { |result| result.to_maybe }
          .case do
            on(Some) { |task| render_task(task) }
            on(None) { render_not_found }
          end
      end
      
      # POST /api/v1/tasks
      def create
        schema_result = API::V1::TaskParamsSchema.validate_create(params.to_unsafe_h)
        
        if schema_result.success?
          result = @task_service.create(schema_result[:task])
          handle_service_result(result, :created) { |task| render_task(task) }
        else
          render_validation_errors(schema_result.errors)
        end
      end
      
      # PATCH/PUT /api/v1/tasks/:id
      def update
        schema_result = API::V1::TaskParamsSchema.validate_update(params.to_unsafe_h)
        
        if schema_result.success?
          result = @task_service.update(params[:id], schema_result[:task])
          handle_service_result(result) { |task| render_task(task) }
        else
          render_validation_errors(schema_result.errors)
        end
      end
      
      # DELETE /api/v1/tasks/:id
      def destroy
        result = @task_service.destroy(params[:id])
        
        handle_service_result(result) do
          head :no_content
        end
      end
      
      # PATCH /api/v1/tasks/:id/status
      def update_status
        new_status = params.require(:status)
        
        unless Types::TaskStatus.valid?(new_status)
          return render json: { error: '유효하지 않은 상태값입니다' }, status: :bad_request
        end
        
        result = @task_service.change_status(params[:id], new_status, status_change_context)
        handle_service_result(result) { |task| render_task(task) }
      end
      
      # PATCH /api/v1/tasks/:id/assign
      def assign
        assignee_id = params[:assignee_id]
        
        result = @task_service.assign(params[:id], assignee_id, assignment_context)
        handle_service_result(result) { |task| render_task(task) }
      end
      
      # POST /api/v1/tasks/bulk_actions
      def bulk_action
        schema_result = API::V1::TaskParamsSchema.validate_bulk_action(params.to_unsafe_h)
        
        unless schema_result.success?
          return render_validation_errors(schema_result.errors)
        end
        
        bulk_params = schema_result.to_h
        result = perform_bulk_action(bulk_params)
        
        handle_service_result(result) { |tasks| render_tasks_collection(tasks) }
      end
      
      # PUT /api/v1/tasks/:id/reorder
      def reorder
        schema_result = API::V1::TaskParamsSchema.validate_reorder(params.to_unsafe_h)
        
        unless schema_result.success?
          return render_validation_errors(schema_result.errors)
        end
        
        result = task_repository.reorder(
          params[:id],
          schema_result[:position],
          schema_result[:status]
        )
        
        handle_service_result(result) { |task| render_task(Dto::EnhancedTaskDto.from_model(task)) }
      end
      
      # GET /api/v1/tasks/statistics
      def statistics
        result = @task_service.statistics
        handle_service_result(result) { |stats| render json: stats.as_json }
      end
      
      # POST /api/v1/tasks/:id/time_tracking
      def time_tracking
        schema_result = API::V1::TaskParamsSchema.validate_time_tracking(params.to_unsafe_h)
        
        unless schema_result.success?
          return render_validation_errors(schema_result.errors)
        end
        
        # 시간 추적 로직 구현
        result = handle_time_tracking(params[:id], schema_result.to_h)
        handle_service_result(result) { |data| render json: data }
      end
      
      private
      
      def set_organization
        @organization = current_user.current_organization
        render_forbidden unless @organization
      end
      
      def set_task_service
        @task_service = RefactoredTaskService.new(
          @organization,
          current_user: current_user
        )
      end
      
      # Result 모나드 처리를 위한 헬퍼
      def handle_service_result(result, success_status = :ok)
        result.case do
          on(Success) do |value|
            yield(value) if block_given?
          end
          on(Failure) do |error|
            render_service_error(error, success_status)
          end
        end
      end
      
      # 서비스 에러를 HTTP 응답으로 변환
      def render_service_error(error, _success_status)
        case error
        in [:not_found]
          render_not_found
        in [:permission_denied, String => message]
          render json: { error: message }, status: :forbidden
        in [:validation_failed, errors]
          render json: { errors: errors }, status: :unprocessable_entity
        in [:invalid_status]
          render json: { error: '유효하지 않은 상태입니다' }, status: :bad_request
        in [:invalid_assignee, String => message]
          render json: { error: message }, status: :bad_request
        in [:database_error, String => message]
          Rails.logger.error \"Database error: #{message}\"
          render json: { error: '서버 오류가 발생했습니다' }, status: :internal_server_error
        else
          Rails.logger.error \"Unhandled service error: #{error}\"
          render json: { error: '알 수 없는 오류가 발생했습니다' }, status: :internal_server_error
        end
      end
      
      # Task ID 검증
      def validate_task_id(task_id)
        Types::ID.valid?(task_id) ? Some(task_id) : None()
      end
      
      # 상태 변경 컨텍스트
      def status_change_context
        {
          changed_by: current_user.id,
          reason: params[:reason],
          timestamp: Time.current
        }
      end
      
      # 할당 컨텍스트
      def assignment_context
        {
          assigned_by: current_user.id,
          reason: params[:reason],
          timestamp: Time.current
        }
      end
      
      # 벌크 액션 처리
      def perform_bulk_action(bulk_params)
        task_ids = bulk_params[:task_ids]
        action = bulk_params[:action]
        
        case action
        when 'update_status'
          new_status = bulk_params[:status]
          task_repository.bulk_update_status(task_ids, new_status, @organization.id)
        when 'assign'
          assignee_id = bulk_params[:assignee_id]
          # 벌크 할당 로직 구현
          Success([])  # 임시
        when 'move_to_sprint'
          sprint_id = bulk_params[:sprint_id]
          # 벌크 스프린트 이동 로직
          Success([])  # 임시
        else
          Failure([:invalid_action, '유효하지 않은 액션입니다'])
        end
      end
      
      # 시간 추적 처리
      def handle_time_tracking(task_id, tracking_params)
        # 시간 추적 서비스 호출
        Success({ message: '시간이 기록되었습니다' })  # 임시
      end
      
      # 렌더링 헬퍼들
      def render_task(task)
        render json: task.as_json(context: :api)
      end
      
      def render_tasks_collection(tasks)
        render json: {
          data: tasks.map { |task| task.as_json(context: :api) },
          meta: {
            total: tasks.size,
            organization: @organization.name
          }
        }
      end
      
      def render_validation_errors(errors)
        render json: { 
          error: '입력 데이터가 유효하지 않습니다',
          details: errors.to_h 
        }, status: :unprocessable_entity
      end
      
      def render_not_found
        render json: { error: '작업을 찾을 수 없습니다' }, status: :not_found
      end
      
      def render_forbidden
        render json: { error: '권한이 없습니다' }, status: :forbidden
      end
    end
  end
end