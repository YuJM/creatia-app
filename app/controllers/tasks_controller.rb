# frozen_string_literal: true

class TasksController < TenantBaseController
  before_action :set_task, only: [:show, :update, :destroy, :assign, :change_status, :reorder, :metrics]
  
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
    
    # Task 기본 정보와 함께 메트릭도 함께 로딩
    @task_metrics = TaskMetrics.new(
      estimated_hours: @task.estimated_hours,
      actual_hours: @task.actual_hours || 0.0,
      completion_percentage: calculate_completion_percentage(@task),
      complexity_score: @task.complexity_score || 1
    )
    
    render_serialized(
      TaskSerializer,
      @task,
      params: { 
        include_stats: true,
        include_metrics: true,
        metrics: @task_metrics
      }
    )
  end
  
  # POST /tasks
  # 새로운 태스크를 생성합니다.
  def create
    # GitHub 연동이 활성화된 경우에만 브랜치 생성 서비스 사용
    if github_integration_enabled? && params[:create_github_branch] == 'true'
      result = CreateTaskWithBranchService.new(
        task_params.to_h,
        current_user,
        current_organization.current_service
      ).call
      
      if result.success?
        @task = result.value!
        handle_task_creation_success(@task, github_branch_created: true)
      else
        handle_task_creation_error(result.failure)
      end
    else
      # 일반 Task 생성 (GitHub 연동 없음)
      @task = build_tenant_resource(Task, task_params)
      authorize @task
      
      if @task.save
        handle_task_creation_success(@task)
      else
        handle_task_creation_error(@task.errors)
      end
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
      handle_status_change_success(@task)
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
  
  # GET /tasks/:id/metrics
  # 특정 태스크의 메트릭 정보를 반환합니다.
  def metrics
    authorize @task
    
    @task_metrics = TaskMetrics.new(
      estimated_hours: @task.estimated_hours,
      actual_hours: @task.actual_hours || 0.0,
      completion_percentage: calculate_completion_percentage(@task),
      complexity_score: @task.complexity_score || 1
    )
    
    respond_to do |format|
      format.json do
        render json: { 
          metrics: @task_metrics.to_h,
          user_friendly: {
            efficiency_status: efficiency_status_text(@task_metrics),
            complexity_description: complexity_description(@task_metrics),
            progress_description: progress_description(@task_metrics),
            time_status: time_status_description(@task_metrics)
          }
        }
      end
      
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "task_metrics_#{@task.id}",
          TaskMetricsCardComponent.new(task: @task, task_metrics: @task_metrics)
        )
      end
    end
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
  
  # GitHub 연동 관련 helper 메서드들
  def github_integration_enabled?
    # 조직의 GitHub 설정이 활성화되어 있고, 사용자가 개발자 역할인 경우
    return false unless current_organization_membership&.developer_role?
    return false unless current_organization.respond_to?(:github_integration_active?)
    
    current_organization.github_integration_active?
  end
  
  def github_branch_url(task)
    return nil unless task.github_branch.present?
    return nil unless current_organization.respond_to?(:github_repository)
    
    repo = current_organization.github_repository
    "https://github.com/#{repo}/tree/#{task.github_branch}" if repo.present?
  end
  
  # Task 메트릭 관련 helper 메서드들
  def calculate_completion_percentage(task)
    case task.status
    when 'todo' then 0.0
    when 'in_progress' then 50.0
    when 'review' then 90.0
    when 'done' then 100.0
    else 0.0
    end
  end

  def efficiency_status_text(metrics)
    if metrics.is_on_track?
      "👍 예정대로 진행 중"
    else
      "⚠️ 일정 지연 위험"
    end
  end

  def complexity_description(metrics)
    case metrics.complexity_level
    when 'low' then "🟢 간단한 작업"
    when 'medium' then "🟡 보통 작업" 
    when 'high' then "🟠 복잡한 작업"
    when 'very_high' then "🔴 매우 복잡한 작업"
    end
  end
  
  def progress_description(metrics)
    remaining = metrics.remaining_percentage
    if remaining > 75
      "📋 시작 단계입니다"
    elsif remaining > 25
      "⚡ 진행 중입니다"
    elsif remaining > 0
      "🏁 거의 완료되었습니다"
    else
      "✅ 작업이 완료되었습니다"
    end
  end
  
  def time_status_description(metrics)
    if metrics.overdue?
      "⏰ 예상 시간을 초과했습니다"
    elsif metrics.efficiency_ratio >= 1.0
      "⚡ 예상보다 빠르게 진행 중입니다"
    else
      "📈 적정한 속도로 진행 중입니다"
    end
  end
  
  # Turbo Stream 응답 처리 메서드들
  def handle_task_creation_success(task, github_branch_created: false)
    respond_to do |format|
      format.json do
        extra_data = {}
        if github_branch_created
          extra_data.merge!({
            github_branch_created: true,
            branch_url: github_branch_url(task)
          })
        end
        
        render_with_success(TaskSerializer, task, extra_data.merge(status: :created))
      end
      
      format.turbo_stream do
        flash[:notice] = if github_branch_created
          "작업이 생성되고 GitHub 브랜치가 자동으로 생성되었습니다."
        else
          "작업이 성공적으로 생성되었습니다."
        end
        
        render turbo_stream: [
          turbo_stream.prepend("tasks_list", 
            render_to_string(partial: "tasks/task_item", locals: { task: task })
          ),
          turbo_stream.replace("task_form",
            render_to_string(partial: "tasks/form", locals: { task: Task.new })
          ),
          turbo_stream.replace("flash_messages",
            render_to_string(partial: "shared/flash_messages")
          )
        ]
      end
      
      # HTML 요청에 대한 일반적인 리다이렉트
      format.html do
        if github_branch_created
          flash[:notice] = "작업이 생성되고 GitHub 브랜치가 자동으로 생성되었습니다."
        else  
          flash[:notice] = "작업이 성공적으로 생성되었습니다."
        end
        redirect_to tasks_path
      end
    end
  end
  
  def handle_task_creation_error(errors)
    respond_to do |format|
      format.json do
        render_error(errors)
      end
      
      format.turbo_stream do
        @task ||= build_tenant_resource(Task, task_params)
        
        if errors.is_a?(ActiveModel::Errors)
          flash[:alert] = errors.full_messages.join(', ')
        else
          flash[:alert] = errors.to_s
        end
        
        render turbo_stream: [
          turbo_stream.replace("task_form",
            render_to_string(partial: "tasks/form", locals: { task: @task })
          ),
          turbo_stream.replace("flash_messages",
            render_to_string(partial: "shared/flash_messages")
          )
        ]
      end
      
      # HTML 요청에 대한 처리
      format.html do
        @task ||= build_tenant_resource(Task, task_params)
        if errors.is_a?(ActiveModel::Errors)
          flash.now[:alert] = errors.full_messages.join(', ')
        else
          flash.now[:alert] = errors.to_s
        end
        render :new, status: :unprocessable_entity
      end
    end
  end
  
  # 상태 변경 성공 시 처리 (메트릭도 함께 업데이트)
  def handle_status_change_success(task)
    respond_to do |format|
      format.json do
        render json: {
          success: true,
          message: "상태가 '#{task.status_display_name}'로 변경되었습니다.",
          task: TaskSerializer.new(task, params: serializer_context).serializable_hash
        }
      end
      
      format.turbo_stream do
        # 상태 변경시 메트릭도 함께 업데이트
        task_metrics = TaskMetrics.new(
          estimated_hours: task.estimated_hours,
          actual_hours: task.actual_hours || 0.0,
          completion_percentage: calculate_completion_percentage(task),
          complexity_score: task.complexity_score || 1
        )
        
        flash[:notice] = "상태가 '#{task.status_display_name}'로 변경되었습니다."
        
        render turbo_stream: [
          turbo_stream.replace("task_#{task.id}",
            render_to_string(partial: "tasks/task_item", locals: { task: task })
          ),
          turbo_stream.replace("task_metrics_#{task.id}",
            TaskMetricsCardComponent.new(task: task, task_metrics: task_metrics)
          ),
          turbo_stream.replace("flash_messages",
            render_to_string(partial: "shared/flash_messages")
          )
        ]
      end
      
      format.html do
        flash[:notice] = "상태가 '#{task.status_display_name}'로 변경되었습니다."
        redirect_to task_path(task)
      end
    end
  end
end
