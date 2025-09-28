# frozen_string_literal: true

# SprintService is autoloaded by Rails

module Web
  class SprintsController < TenantBaseController
    before_action :initialize_service
    before_action :set_sprint, only: [ :show, :edit, :update, :destroy, :board, :burndown, :start, :complete, :retrospective, :reports ]
    before_action :set_milestone, only: [ :new, :create ], if: -> { params[:milestone_id].present? }

    def index
      authorize! :index, :sprint

      result = @sprint_service.list(filter_params)

      if result.success?
        @sprints = result.value!
      else
        Rails.logger.error "Failed to load sprints: #{result.failure}"
        flash[:alert] = "Failed to load sprints"
        @sprints = []
      end
    end

    def show
      authorize! :show, :sprint

      # Load associated tasks with error handling
      task_result = @task_service.list_by_sprint(@sprint.id)
      @tasks = task_result.success? ? task_result.value! : []

      # Calculate sprint metrics
      @metrics = calculate_sprint_metrics(@tasks)
    end

    def new
      authorize! :new, :sprint

      @sprint = build_empty_sprint_dto
    end

    def create
      authorize! :create, :sprint

      result = @sprint_service.create(sprint_params)

      if result.success?
        @sprint = result.value!
        redirect_path = @milestone ? milestone_sprint_path(@milestone, @sprint) : sprint_path(@sprint)
        redirect_to redirect_path, notice: "Sprint was successfully created."
      else
        @sprint = build_sprint_dto(sprint_params)
        flash.now[:alert] = format_errors(result.failure)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize! :edit, :sprint
    end

    def update
      authorize! :update, :sprint

      result = @sprint_service.update(@sprint.id, sprint_params)

      if result.success?
        @sprint = result.value!

        respond_to do |format|
          format.html { redirect_to sprint_path(@sprint), notice: "Sprint was successfully updated." }
          format.turbo_stream
        end
      else
        flash.now[:alert] = format_errors(result.failure)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize! :destroy, :sprint

      result = @sprint_service.archive(@sprint.id)

      if result.success?
        redirect_to sprints_path, notice: "Sprint was successfully archived."
      else
        redirect_to sprints_path, alert: "Failed to archive sprint."
      end
    end

    def board
      authorize! :show, :sprint

      # Group tasks by status for Kanban board
      task_result = @task_service.list_by_sprint(@sprint.id)

      if task_result.success?
        tasks = task_result.value!
        @tasks_by_status = group_tasks_by_status(tasks)
      else
        Rails.logger.error "Failed to load tasks for sprint board: #{task_result.failure}"
        @tasks_by_status = default_status_groups
      end

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    def burndown
      authorize! :show, :sprint

      begin
        @burndown_data = @sprint_service.calculate_burndown(@sprint.id)
      rescue => e
        Rails.logger.error "Failed to calculate burndown: #{e.message}"
        @burndown_data = { error: "Unable to calculate burndown data" }
      end

      respond_to do |format|
        format.html
        format.json { render json: @burndown_data }
      end
    end

    def start
      authorize! :update, :sprint

      result = @sprint_service.start_sprint(@sprint.id)

      if result.success?
        redirect_to sprint_path(@sprint), notice: "Sprint was successfully started."
      else
        redirect_to sprint_path(@sprint), alert: format_errors(result.failure)
      end
    end

    def complete
      authorize! :update, :sprint

      result = @sprint_service.complete_sprint(@sprint.id)

      if result.success?
        redirect_to sprint_path(@sprint), notice: "Sprint was successfully completed."
      else
        redirect_to sprint_path(@sprint), alert: format_errors(result.failure)
      end
    end

    def retrospective
      authorize! :show, :sprint

      begin
        @retrospective_data = @sprint_service.get_retrospective_data(@sprint.id)
      rescue => e
        Rails.logger.error "Failed to load retrospective data: #{e.message}"
        @retrospective_data = { error: "Unable to load retrospective data" }
      end
    end

    def reports
      authorize! :show, :sprint

      begin
        @report_data = @sprint_service.generate_report(@sprint.id)
      rescue => e
        Rails.logger.error "Failed to generate report: #{e.message}"
        @report_data = { error: "Unable to generate report" }
      end

      respond_to do |format|
        format.html
        format.pdf do
          # PDF 생성은 향후 구현
          render plain: "PDF generation not yet implemented", status: :not_implemented
        end
      end
    end

    private

    def initialize_service
      @sprint_service = SprintService.new(
        organization: current_organization,
        current_user: current_user
      )

      # TaskService 존재 확인
      if defined?(TaskService)
        @task_service = TaskService.new(
          organization: current_organization,
          current_user: current_user
        )
      else
        Rails.logger.warn "TaskService not found - task-related features may not work"
      end
    end

    def set_sprint
      result = @sprint_service.find(params[:id])

      if result.success?
        @sprint = result.value!
      else
        Rails.logger.warn "Sprint not found: #{params[:id]}"
        redirect_to sprints_path, alert: "Sprint not found"
      end
    end

    def set_milestone
      return unless params[:milestone_id].present?

      milestone_service = MilestoneService.new(
        organization: current_organization,
        current_user: current_user
      )

      result = milestone_service.find(params[:milestone_id])

      if result.success?
        @milestone = result.value!
      else
        Rails.logger.warn "Milestone not found: #{params[:milestone_id]}"
        redirect_to milestones_path, alert: "Milestone not found"
      end
    end

    def sprint_params
      params.require(:sprint).permit(
        :name, :goal, :start_date, :end_date,
        :milestone_id, :team_id, :planned_velocity,
        :status, :committed_points
      ).tap do |permitted|
        # 날짜 검증
        [:start_date, :end_date].each do |date_field|
          if permitted[date_field].present?
            begin
              Date.parse(permitted[date_field])
            rescue ArgumentError
              permitted.delete(date_field)
              Rails.logger.warn "Invalid date format for #{date_field}: #{params[:sprint][date_field]}"
            end
          end
        end

        # 숫자 필드 검증
        [:committed_points, :planned_velocity].each do |numeric_field|
          if permitted[numeric_field].present?
            permitted[numeric_field] = permitted[numeric_field].to_i
          end
        end
      end
    end

    def filter_params
      params.permit(:status, :milestone_id, :team_id, :page, :per_page)
            .reject { |_, v| v.blank? }
    end

    def build_empty_sprint_dto
      Dto::SprintDto.new(
        id: "",
        name: "",
        goal: "",
        organization_id: current_organization.id,
        milestone_id: @milestone&.id,
        status: "planning",
        start_date: Date.current.beginning_of_week,
        end_date: Date.current.beginning_of_week + 2.weeks,
        committed_points: 0.0,
        completed_points: 0.0,
        created_at: DateTime.current,
        updated_at: DateTime.current
      )
    end

    def build_sprint_dto(params)
      Dto::SprintDto.new(
        id: "",
        name: params[:name] || "",
        goal: params[:goal] || "",
        organization_id: current_organization.id,
        milestone_id: params[:milestone_id] || @milestone&.id,
        status: params[:status] || "planning",
        start_date: params[:start_date] || Date.current.beginning_of_week,
        end_date: params[:end_date] || (Date.current.beginning_of_week + 2.weeks),
        committed_points: (params[:committed_points] || 0).to_f,
        completed_points: 0.0,
        created_at: DateTime.current,
        updated_at: DateTime.current
      )
    rescue => e
      Rails.logger.error "Error building sprint DTO: #{e.message}"
      build_empty_sprint_dto
    end

    def calculate_sprint_metrics(tasks)
      return default_metrics if tasks.blank?

      {
        total_tasks: tasks.count,
        completed_tasks: tasks.count { |t| t.status == "done" },
        in_progress_tasks: tasks.count { |t| t.status == "in_progress" },
        todo_tasks: tasks.count { |t| t.status == "todo" },
        blocked_tasks: tasks.count { |t| t.status == "blocked" },
        completion_percentage: calculate_completion_percentage(tasks)
      }
    rescue => e
      Rails.logger.error "Error calculating sprint metrics: #{e.message}"
      default_metrics
    end

    def calculate_completion_percentage(tasks)
      return 0 if tasks.empty?
      
      completed_count = tasks.count { |t| t.status == "done" }
      (completed_count.to_f / tasks.count * 100).round
    end

    def default_metrics
      {
        total_tasks: 0,
        completed_tasks: 0,
        in_progress_tasks: 0,
        todo_tasks: 0,
        blocked_tasks: 0,
        completion_percentage: 0
      }
    end

    def group_tasks_by_status(tasks)
      return default_status_groups if tasks.blank?

      {
        "todo" => tasks.select { |t| t.status == "todo" },
        "in_progress" => tasks.select { |t| t.status == "in_progress" },
        "review" => tasks.select { |t| t.status == "review" },
        "done" => tasks.select { |t| t.status == "done" },
        "blocked" => tasks.select { |t| t.status == "blocked" }
      }
    rescue => e
      Rails.logger.error "Error grouping tasks by status: #{e.message}"
      default_status_groups
    end

    def default_status_groups
      {
        "todo" => [],
        "in_progress" => [],
        "review" => [],
        "done" => [],
        "blocked" => []
      }
    end

    def format_errors(failure)
      case failure
      when Array
        error_type, error_data = failure
        case error_type
        when :validation_error
          format_validation_errors(error_data)
        when :database_error, :invalid_id, :missing_required
          error_data.to_s
        else
          failure.join("; ")
        end
      when Hash
        failure.map { |k, v| "#{k.to_s.humanize}: #{Array(v).join(', ')}" }.join("; ")
      else
        failure.to_s
      end
    end

    def format_validation_errors(errors)
      return "Validation failed" unless errors.is_a?(Hash)
      
      errors.map do |field, messages|
        messages = Array(messages)
        "#{field.to_s.humanize}: #{messages.join(', ')}"
      end.join("; ")
    end
  end
end