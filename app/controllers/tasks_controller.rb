# frozen_string_literal: true

class TasksController < TenantBaseController
  before_action :set_task, only: [:show, :update, :destroy, :assign, :change_status, :reorder]
  
  # GET /tasks
  # 현재 조직의 태스크 목록을 반환합니다.
  def index
    @tasks = policy_scope(Task).includes(:assigned_user, :organization)
    
    # 필터링
    @tasks = @tasks.by_status(params[:status]) if params[:status].present?
    @tasks = @tasks.by_priority(params[:priority]) if params[:priority].present?
    @tasks = @tasks.assigned_to(User.find(params[:assigned_user_id])) if params[:assigned_user_id].present?
    @tasks = @tasks.unassigned if params[:unassigned] == 'true'
    @tasks = @tasks.overdue if params[:overdue] == 'true'
    @tasks = @tasks.due_soon if params[:due_soon] == 'true'
    
    # 정렬
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
    
    authorize Task
    
    render_serialized(
      TaskSerializer,
      @tasks,
      params: { 
        skip_organization: true,
        include_stats: params[:include_stats] == 'true'
      }
    )
  end
  
  # GET /tasks/:id
  # 특정 태스크의 상세 정보를 반환합니다.
  def show
    authorize @task
    
    render_serialized(
      TaskSerializer,
      @task,
      params: { include_stats: true }
    )
  end
  
  # POST /tasks
  # 새로운 태스크를 생성합니다.
  def create
    @task = build_tenant_resource(Task, task_params)
    authorize @task
    
    if @task.save
      render_with_success(
        TaskSerializer,
        @task,
        status: :created
      )
    else
      render_error(@task.errors)
    end
  end
  
  # PATCH/PUT /tasks/:id
  # 태스크 정보를 업데이트합니다.
  def update
    authorize @task
    
    if @task.update(task_params)
      render_serialized(TaskSerializer, @task)
    else
      render_error(@task.errors)
    end
  end
  
  # DELETE /tasks/:id
  # 태스크를 삭제합니다.
  def destroy
    authorize @task
    
    if @task.destroy
      render json: { success: true, message: "태스크가 삭제되었습니다." }
    else
      render_error("태스크를 삭제할 수 없습니다.")
    end
  end
  
  # PATCH /tasks/:id/assign
  # 태스크를 사용자에게 할당합니다.
  def assign
    authorize @task, :assign?
    
    if params[:assigned_user_id].present?
      user = User.find(params[:assigned_user_id])
      
      # 사용자가 현재 조직의 멤버인지 확인
      unless user.member_of?(current_organization)
        return render_error("해당 사용자는 이 조직의 멤버가 아닙니다.", status: :forbidden)
      end
      
      @task.assigned_user = user
    else
      @task.assigned_user = nil
    end
    
    if @task.save
      message = @task.assigned_user ? "#{@task.assigned_user.email}에게 할당되었습니다." : "할당이 해제되었습니다."
      render json: {
        success: true,
        message: message,
        task: TaskSerializer.new(@task, params: serializer_context).serializable_hash
      }
    else
      render_error(@task.errors)
    end
  end
  
  # PATCH /tasks/:id/status
  # 태스크의 상태를 변경합니다.
  def change_status
    authorize @task, :change_status?
    
    new_status = params[:status]
    unless Task::STATUSES.include?(new_status)
      return render_error("유효하지 않은 상태입니다.", status: :unprocessable_entity)
    end
    
    @task.status = new_status
    
    if @task.save
      render json: {
        success: true,
        message: "상태가 '#{@task.status_display_name}'로 변경되었습니다.",
        task: TaskSerializer.new(@task, params: serializer_context).serializable_hash
      }
    else
      render_error(@task.errors)
    end
  end
  
  # PATCH /tasks/:id/reorder
  # 태스크의 위치를 변경합니다 (칸반 보드용).
  def reorder
    authorize @task, :reorder?
    
    new_position = params[:position].to_i
    new_status = params[:status] || @task.status
    
    @task.status = new_status if new_status != @task.status
    @task.position = new_position
    
    if @task.save
      render json: {
        success: true,
        message: "태스크 위치가 변경되었습니다.",
        task: TaskSerializer.new(@task, params: serializer_context).serializable_hash
      }
    else
      render_error(@task.errors)
    end
  end
  
  # GET /tasks/stats
  # 태스크 통계를 반환합니다.
  def stats
    authorize Task, :index?
    
    tasks = policy_scope(Task)
    
    stats = {
      total: tasks.count,
      by_status: {
        todo: tasks.todo.count,
        in_progress: tasks.in_progress.count,
        review: tasks.review.count,
        done: tasks.done.count,
        archived: tasks.archived.count
      },
      by_priority: {
        low: tasks.low_priority.count,
        medium: tasks.medium_priority.count,
        high: tasks.high_priority.count,
        urgent: tasks.urgent.count
      },
      assigned: tasks.assigned_to(current_user).count,
      unassigned: tasks.unassigned.count,
      overdue: tasks.overdue.count,
      due_soon: tasks.due_soon.count
    }
    
    render json: { success: true, data: stats }
  end
  
  private
  
  def set_task
    @task = policy_scope(Task).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error("태스크를 찾을 수 없습니다.", status: :not_found)
  end
  
  def task_params
    params.require(:task).permit(
      :title, :description, :status, :priority, :due_date, :position,
      :assigned_user_id, :assigned_user_type
    )
  end
  
  def serializer_context
    {
      current_user: current_user,
      current_organization: current_organization,
      current_membership: current_membership,
      time_helper: helpers,
      skip_organization: true
    }
  end
end
