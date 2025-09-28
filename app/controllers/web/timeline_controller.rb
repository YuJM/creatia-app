# frozen_string_literal: true

module Web
  class TimelineController < TenantBaseController
    before_action :initialize_services
    
    def index
      authorize! :index, :timeline
      
      @view_mode = params[:view_mode] || 'quarter'
      @start_date, @end_date = calculate_date_range
      
      # Fetch milestones with their sprints
      milestone_result = @milestone_service.list_for_timeline(
        start_date: @start_date,
        end_date: @end_date,
        include_sprints: true
      )
      
      if milestone_result.success?
        @milestones = milestone_result.value!
      else
        flash[:alert] = "Failed to load timeline data"
        @milestones = []
      end
      
      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end
    
    private
    
    def initialize_services
      @milestone_service = MilestoneService.new(
        organization: current_organization,
        current_user: current_user
      )
      
      @sprint_service = SprintService.new(
        organization: current_organization,
        current_user: current_user
      )
    end
    
    def calculate_date_range
      case @view_mode
      when 'month'
        start_date = params[:start_date] ? Date.parse(params[:start_date]) : Date.current.beginning_of_month
        end_date = start_date.end_of_month
      when 'quarter'
        start_date = params[:start_date] ? Date.parse(params[:start_date]) : Date.current.beginning_of_quarter
        end_date = start_date.end_of_quarter
      when 'year'
        start_date = params[:start_date] ? Date.parse(params[:start_date]) : Date.current.beginning_of_year
        end_date = start_date.end_of_year
      else
        start_date = Date.current.beginning_of_quarter
        end_date = Date.current.end_of_quarter
      end
      
      [start_date, end_date]
    end
  end
end