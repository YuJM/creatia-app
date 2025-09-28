# frozen_string_literal: true

module Web
  class MilestonesController < TenantBaseController
    before_action :initialize_service
    before_action :set_milestone, only: [ :show, :edit, :update, :destroy ]

    def index
      authorize! :index, :milestone

      result = @milestone_service.list(filter_params)

      if result.success?
        @milestones = result.value!
      else
        flash[:alert] = "Failed to load milestones"
        @milestones = []
      end
    end

    def show
      authorize! :show, :milestone

      # Load associated sprints
      sprint_result = @sprint_service.list_by_milestone(@milestone.id)
      @sprints = sprint_result.success? ? sprint_result.value! : []

      # Load risks, objectives, dependencies
      @objectives = @milestone.objectives || []
      @risks = @milestone.risks || []
      @dependencies = @milestone.dependencies || []
      @blockers = @milestone.blockers || []
    end

    def new
      authorize! :new, :milestone

      @milestone = Dto::MilestoneDto.new(
        id: "",
        title: "",
        description: "",
        organization_id: current_organization.id,
        status: "planning",
        milestone_type: "release",
        planned_start: Date.current,
        planned_end: Date.current + 3.months,
        progress_percentage: 0.0,
        created_at: DateTime.current,
        updated_at: DateTime.current
      )
    end

    def create
      authorize! :create, :milestone

      result = @milestone_service.create(milestone_params)

      if result.success?
        @milestone = result.value!
        redirect_to milestone_path(@milestone), notice: "Milestone was successfully created."
      else
        @milestone = build_milestone_dto(milestone_params)
        flash.now[:alert] = format_errors(result.failure)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize! :edit, :milestone
    end

    def update
      authorize! :update, :milestone

      result = @milestone_service.update(@milestone.id, milestone_params)

      if result.success?
        @milestone = result.value!

        respond_to do |format|
          format.html { redirect_to milestone_path(@milestone), notice: "Milestone was successfully updated." }
          format.turbo_stream
        end
      else
        flash.now[:alert] = format_errors(result.failure)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize! :destroy, :milestone

      result = @milestone_service.archive(@milestone.id)

      if result.success?
        redirect_to milestones_path, notice: "Milestone was successfully archived."
      else
        redirect_to milestones_path, alert: "Failed to archive milestone."
      end
    end

    private

    def initialize_service
      @milestone_service = MilestoneService.new(
        organization: current_organization,
        current_user: current_user
      )

      @sprint_service = SprintService.new(
        organization: current_organization,
        current_user: current_user
      )
    end

    def set_milestone
      result = @milestone_service.find(params[:id])

      if result.success?
        @milestone = result.value!
      else
        redirect_to milestones_path, alert: "Milestone not found"
      end
    end

    def milestone_params
      params.require(:milestone).permit(
        :title, :description, :milestone_type, :status,
        :planned_start, :planned_end, :actual_start, :actual_end,
        :owner_id,
        stakeholder_ids: [], stakeholder_roles: [],
        team_lead_ids: [], team_ids: [],
        objectives: [ :title, :description ]
      )
    end

    def filter_params
      params.permit(:status, :milestone_type, :health_status, :owner_id, :page, :per_page)
    end

    def build_milestone_dto(params)
      Dto::MilestoneDto.new(
        id: "",
        title: params[:title],
        description: params[:description],
        organization_id: current_organization.id,
        status: params[:status] || "planning",
        milestone_type: params[:milestone_type] || "release",
        planned_start: params[:planned_start],
        planned_end: params[:planned_end],
        progress_percentage: 0.0,
        created_at: DateTime.current,
        updated_at: DateTime.current
      )
    end

    def format_errors(failure)
      case failure
      when Hash
        failure.map { |k, v| "#{k.to_s.humanize}: #{Array(v).join(', ')}" }.join("; ")
      when Array
        failure.join("; ")
      else
        failure.to_s
      end
    end
  end
end
