# frozen_string_literal: true

module Web
  class TasksController < TenantBaseController
    before_action :initialize_service
    before_action :set_task_dto, only: [:show, :edit]
    
    # GET /tasks
    def index
      authorize! :index, Task
      
      result = @task_service.list(filter_params)
      
      if result.success?
        data = result.value!
        @tasks = data[:tasks]
        @paginated_tasks = Kaminari.paginate_array(
          @tasks,
          total_count: data[:pagination][:total_count]
        ).page(data[:pagination][:current_page]).per(data[:pagination][:per_page])
        @statistics = @task_service.statistics.value!
      else
        flash[:alert] = "Failed to load tasks"
        @tasks = []
        @paginated_tasks = Kaminari.paginate_array([])
        @statistics = nil
      end
    end
    
    # GET /tasks/:id
    def show
      authorize! :show, Task
      
      # Task DTO already loaded in before_action
      return redirect_to tasks_path, alert: "Task not found" unless @task_dto
    end
    
    # GET /tasks/new
    def new
      authorize! :new, Task
      
      @task_dto = Dto::TaskDto.new(
        id: '',
        title: '',
        description: '',
        status: 'todo',
        priority: 'medium',
        organization_id: current_organization.id,
        assignee_id: nil,
        due_date: nil,
        tags: []
      )
      
      @available_sprints = @task_service.available_sprints
      @available_assignees = @task_service.available_assignees
    end
    
    # GET /tasks/:id/edit
    def edit
      authorize! :edit, Task
      
      return redirect_to tasks_path, alert: "Task not found" unless @task_dto
      
      @available_sprints = @task_service.available_sprints
      @available_assignees = @task_service.available_assignees
    end
    
    # POST /tasks
    def create
      authorize! :create, Task
      
      result = @task_service.create(task_params)
      
      if result.success?
        redirect_to task_path(result.value!.id), notice: 'Task was successfully created.'
      else
        @task_dto = Dto::TaskDto.new(task_params.merge(
          id: '',
          organization_id: current_organization.id
        ))
        @available_sprints = @task_service.available_sprints
        @available_assignees = @task_service.available_assignees
        flash.now[:alert] = format_errors(result.failure)
        render :new
      end
    end
    
    # PATCH/PUT /tasks/:id
    def update
      authorize! :update, Task
      
      result = @task_service.update(params[:id], task_params)
      
      if result.success?
        redirect_to task_path(result.value!.id), notice: 'Task was successfully updated.'
      else
        set_task_dto
        @available_sprints = @task_service.available_sprints
        @available_assignees = @task_service.available_assignees
        flash.now[:alert] = format_errors(result.failure)
        render :edit
      end
    end
    
    # DELETE /tasks/:id
    def destroy
      authorize! :destroy, Task
      
      result = @task_service.destroy(params[:id])
      
      if result.success?
        redirect_to tasks_path, notice: 'Task was successfully destroyed.'
      else
        redirect_to tasks_path, alert: 'Failed to delete task.'
      end
    end
    
    # PATCH /tasks/:id/assign
    def assign
      authorize! :assign, Task
      
      result = @task_service.assign(params[:id], params[:assignee_id])
      
      if result.success?
        redirect_to task_path(result.value!.id), notice: 'Task assigned successfully.'
      else
        redirect_to task_path(params[:id]), alert: format_errors(result.failure)
      end
    end
    
    # PATCH /tasks/:id/status
    def change_status
      authorize! :update, Task
      
      result = @task_service.change_status(params[:id], params[:status])
      
      if result.success?
        redirect_to task_path(result.value!.id), notice: 'Status updated successfully.'
      else
        redirect_to task_path(params[:id]), alert: format_errors(result.failure)
      end
    end
    
    private
    
    def initialize_service
      @task_service = TaskService.new(
        organization: current_organization,
        user: current_user
      )
    end
    
    def set_task_dto
      result = @task_service.find(params[:id])
      
      if result.success?
        @task_dto = result.value!
      else
        @task_dto = nil
      end
    end
    
    def task_params
      params.require(:task).permit(
        :title, :description, :status, :priority, 
        :due_date, :assignee_id, :sprint_id,
        :estimated_hours, :actual_hours,
        tags: []
      )
    end
    
    def filter_params
      params.permit(
        :status, :priority, :assignee_id, :sprint_id,
        :unassigned, :overdue, :due_soon,
        :sort_by, :page, :per_page
      )
    end
    
    def format_errors(errors)
      case errors
      when :not_found
        "Task not found"
      when :invalid_status
        "Invalid status"
      when :invalid_assignee
        "Invalid assignee"
      when :not_member
        "Assignee is not a member of this organization"
      when ActiveModel::Errors
        errors.full_messages.join(", ")
      else
        "An error occurred"
      end
    end
  end
end