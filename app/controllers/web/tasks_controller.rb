# frozen_string_literal: true

module Web
  class TasksController < TenantBaseController
    before_action :set_task, only: [:show, :edit, :update, :destroy]
    
    # GET /tasks
    def index
      @tasks = Task.accessible_by(current_ability).includes(:assigned_user, :organization)
      apply_filters
      apply_sorting
      
      authorize! :index, Task
      
      @tasks = @tasks.page(params[:page]) if @tasks.respond_to?(:page)
    end
    
    # GET /tasks/:id
    def show
      authorize! :show, @task
      
      @task_metrics = TaskMetrics.new(
        estimated_hours: @task.estimated_hours,
        actual_hours: @task.actual_hours || 0.0,
        completion_percentage: calculate_completion_percentage(@task),
        complexity_score: @task.complexity_score || 1
      )
    end
    
    # GET /tasks/new
    def new
      @task = build_tenant_resource(Task)
      authorize! :new, @task
    end
    
    # GET /tasks/:id/edit
    def edit
      authorize! :edit, @task
    end
    
    # POST /tasks
    def create
      @task = build_tenant_resource(Task, task_params)
      authorize! :create, @task
      
      if @task.save
        respond_to do |format|
          format.html { redirect_to web_task_path(@task), notice: '작업이 성공적으로 생성되었습니다.' }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.prepend("tasks_list", 
                render_to_string(partial: "tasks/task_item", locals: { task: @task })
              ),
              turbo_stream.replace("task_form",
                render_to_string(partial: "tasks/form", locals: { task: Task.new })
              ),
              turbo_stream.replace("flash_messages",
                render_to_string(partial: "shared/flash_messages")
              )
            ]
          end
        end
      else
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace("task_form",
                render_to_string(partial: "tasks/form", locals: { task: @task })
              ),
              turbo_stream.replace("flash_messages",
                render_to_string(partial: "shared/flash_messages")
              )
            ]
          end
        end
      end
    end
    
    # PATCH/PUT /tasks/:id
    def update
      authorize! :update, @task
      
      if @task.update(task_params)
        respond_to do |format|
          format.html { redirect_to web_task_path(@task), notice: '작업이 성공적으로 업데이트되었습니다.' }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace("task_#{@task.id}",
                render_to_string(partial: "tasks/task_item", locals: { task: @task })
              ),
              turbo_stream.replace("flash_messages",
                render_to_string(partial: "shared/flash_messages")
              )
            ]
          end
        end
      else
        respond_to do |format|
          format.html { render :edit, status: :unprocessable_entity }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace("task_form",
                render_to_string(partial: "tasks/form", locals: { task: @task })
              ),
              turbo_stream.replace("flash_messages",
                render_to_string(partial: "shared/flash_messages")
              )
            ]
          end
        end
      end
    end
    
    # DELETE /tasks/:id
    def destroy
      authorize! :destroy, @task
      
      @task.destroy
      
      respond_to do |format|
        format.html { redirect_to web_tasks_path, notice: '작업이 삭제되었습니다.' }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.remove("task_#{@task.id}"),
            turbo_stream.replace("flash_messages",
              render_to_string(partial: "shared/flash_messages")
            )
          ]
        end
      end
    end
    
    private
    
    def set_task
      @task = Task.accessible_by(current_ability).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to web_tasks_path, alert: '작업을 찾을 수 없습니다.'
    end
    
    def task_params
      params.require(:task).permit(
        :title, :description, :status, :priority, :due_date, :position,
        :assigned_user_id, :assigned_user_type, :estimated_hours, :complexity_score
      )
    end
    
    def apply_filters
      @tasks = @tasks.by_status(params[:status]) if params[:status].present?
      @tasks = @tasks.by_priority(params[:priority]) if params[:priority].present?
      @tasks = @tasks.assigned_to(User.find(params[:assigned_user_id])) if params[:assigned_user_id].present?
      @tasks = @tasks.unassigned if params[:unassigned] == 'true'
      @tasks = @tasks.overdue if params[:overdue] == 'true'
      @tasks = @tasks.due_soon if params[:due_soon] == 'true'
    end
    
    def apply_sorting
      case params[:sort]
      when 'priority'
        @tasks = @tasks.order(
          Arel.sql("CASE priority WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 END"),
          :position, :created_at
        )
      when 'due_date'
        @tasks = @tasks.order(:due_date, :position, :created_at)
      when 'created'
        @tasks = @tasks.order(:created_at)
      else
        @tasks = @tasks.ordered
      end
    end
    
    def calculate_completion_percentage(task)
      case task.status
      when 'todo' then 0.0
      when 'in_progress' then 50.0
      when 'review' then 90.0
      when 'done' then 100.0
      else 0.0
      end
    end
  end
end