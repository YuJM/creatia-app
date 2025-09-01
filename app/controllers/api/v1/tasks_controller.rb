# frozen_string_literal: true

module Api
  module V1
    class TasksController < BaseController
      before_action :set_task, only: [:show, :update, :destroy, :assign, :change_status, :reorder, :metrics]
      
      # GET /api/v1/tasks
      def index
        @tasks = ::Task.accessible_by(current_ability).includes(:assigned_user, :organization)
        
        apply_filters
        apply_sorting
        apply_pagination
        
        authorize! :index, Task
        
        render_serialized(
          TaskSerializer,
          @tasks,
          params: { 
            skip_organization: true,
            include_stats: params[:include_stats] == 'true'
          }
        )
      end
      
      # GET /api/v1/tasks/:id
      def show
        authorize! :show, @task
        
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
      
      # POST /api/v1/tasks
      def create
        @task = build_tenant_resource(Task, task_params)
        authorize! :create, @task
        
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
      
      # PATCH/PUT /api/v1/tasks/:id
      def update
        authorize! :update, @task
        
        if @task.update(task_params)
          render_serialized(TaskSerializer, @task)
        else
          render_error(@task.errors)
        end
      end
      
      # DELETE /api/v1/tasks/:id
      def destroy
        authorize! :destroy, @task
        
        if @task.destroy
          render_serialized(SuccessSerializer, { message: "작업이 삭제되었습니다." })
        else
          render_error("작업을 삭제할 수 없습니다.")
        end
      end
      
      # PATCH /api/v1/tasks/:id/assign
      def assign
        authorize! :assign, @task
        
        if params[:assigned_user_id].present?
          user = User.find(params[:assigned_user_id])
          
          unless user.member_of?(current_organization)
            return render_error("해당 사용자는 이 조직의 멤버가 아닙니다.", status: :forbidden)
          end
          
          @task.assigned_user = user
        else
          @task.assigned_user = nil
        end
        
        if @task.save
          message = @task.assigned_user ? "#{@task.assigned_user.email}에게 할당되었습니다." : "할당이 해제되었습니다."
          render_with_success(TaskSerializer, @task, params: { message: message })
        else
          render_error(@task.errors)
        end
      end
      
      # PATCH /api/v1/tasks/:id/status
      def change_status
        authorize! :update, @task
        
        new_status = params[:status]
        unless Task::STATUSES.include?(new_status)
          return render_error("유효하지 않은 상태입니다.", status: :unprocessable_entity)
        end
        
        @task.status = new_status
        
        if @task.save
          render_with_success(TaskSerializer, @task, params: {
            message: "상태가 '#{@task.status_display_name}'로 변경되었습니다."
          })
        else
          render_error(@task.errors)
        end
      end
      
      # PATCH /api/v1/tasks/:id/reorder
      def reorder
        authorize! :update, @task
        
        new_position = params[:position].to_i
        new_status = params[:status] || @task.status
        
        @task.status = new_status if new_status != @task.status
        @task.position = new_position
        
        if @task.save
          render_with_success(TaskSerializer, @task, params: {
            message: "작업 위치가 변경되었습니다."
          })
        else
          render_error(@task.errors)
        end
      end
      
      # GET /api/v1/tasks/stats
      def stats
        authorize! :index, Task
        
        tasks = ::Task.accessible_by(current_ability)
        
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
        
        render_serialized(TaskStatsSerializer, stats)
      end
      
      # GET /api/v1/tasks/:id/metrics
      def metrics
        authorize! :show, @task
        
        @task_metrics = TaskMetrics.new(
          estimated_hours: @task.estimated_hours,
          actual_hours: @task.actual_hours || 0.0,
          completion_percentage: calculate_completion_percentage(@task),
          complexity_score: @task.complexity_score || 1
        )
        
        render_serialized(TaskMetricsSerializer, @task_metrics, params: {
          include_descriptions: true,
          efficiency_status: efficiency_status_text(@task_metrics),
          complexity_description: complexity_description(@task_metrics),
          progress_description: progress_description(@task_metrics),
          time_status: time_status_description(@task_metrics)
        })
      end
      
      private
      
      def set_task
        @task = ::Task.accessible_by(current_ability).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_error("작업을 찾을 수 없습니다.", status: :not_found)
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
      
      def apply_pagination
        @tasks = @tasks.page(params[:page]).per(params[:per_page] || 25) if @tasks.respond_to?(:page)
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
      
      def efficiency_status_text(metrics)
        metrics.is_on_track? ? "👍 예정대로 진행 중" : "⚠️ 일정 지연 위험"
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
    end
  end
end