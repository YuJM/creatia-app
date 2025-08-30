# frozen_string_literal: true

class SprintsController < TenantBaseController
  before_action :set_sprint, only: [:show, :update, :destroy, :plan, :metrics]
  
  # GET /sprints
  def index
    @sprints = Sprint.accessible_by(current_ability).includes(:tasks, :organization)
    
    # 필터링
    @sprints = @sprints.active if params[:status] == 'active'
    @sprints = @sprints.completed if params[:status] == 'completed'
    @sprints = @sprints.upcoming if params[:status] == 'upcoming'
    
    # 정렬
    case params[:sort]
    when 'start_date'
      @sprints = @sprints.order(:start_date, :created_at)
    when 'end_date'
      @sprints = @sprints.order(:end_date, :created_at)
    when 'progress'
      @sprints = @sprints.joins(:tasks)
                         .group('sprints.id')
                         .order('AVG(CASE WHEN tasks.status = \'done\' THEN 1.0 ELSE 0.0 END) DESC')
    else
      @sprints = @sprints.order(:start_date, :created_at)
    end
    
    authorize! :index, Sprint
    
    render_serialized(
      SprintSerializer,
      @sprints,
      params: {
        skip_organization: true,
        include_stats: params[:include_stats] == 'true',
        include_tasks: params[:include_tasks] == 'true'
      }
    )
  end
  
  # GET /sprints/:id
  def show
    authorize! :show, @sprint
    
    # Sprint 계획 서비스 실행
    @sprint_plan = SprintPlanningService.new(@sprint).call.value_or(nil)
    
    # 메트릭 계산
    @team_metrics = TeamMetrics.new(
      velocity: calculate_sprint_velocity(@sprint),
      capacity: calculate_team_capacity(@sprint),
      workload_distribution: @sprint_plan&.workload_distribution || {}
    )
    
    respond_to do |format|
      format.html # show.html.erb
      format.json do
        render_serialized(
          SprintSerializer,
          @sprint,
          params: {
            include_stats: true,
            include_plan: true,
            plan: @sprint_plan,
            metrics: @team_metrics
          }
        )
      end
      
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("sprint_#{@sprint.id}",
            SprintCardComponent.new(sprint: @sprint, sprint_plan: @sprint_plan, team_metrics: @team_metrics)
          )
        ]
      end
    end
  end
  
  # POST /sprints
  def create
    @sprint = build_tenant_resource(Sprint, sprint_params)
    authorize! :create, @sprint
    
    if @sprint.save
      handle_sprint_creation_success(@sprint)
    else
      handle_sprint_creation_error(@sprint.errors)
    end
  end
  
  # PATCH/PUT /sprints/:id
  def update
    authorize! :update, @sprint
    
    if @sprint.update(sprint_params)
      respond_to do |format|
        format.json { render_serialized(SprintSerializer, @sprint) }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "sprint_#{@sprint.id}",
            SprintCardComponent.new(sprint: @sprint)
          )
        end
      end
    else
      render_error(@sprint.errors)
    end
  end
  
  # DELETE /sprints/:id
  def destroy
    authorize! :destroy, @sprint
    
    if @sprint.destroy
      respond_to do |format|
        format.json { render_serialized(SuccessSerializer, { message: "스프린트가 삭제되었습니다." }) }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.remove("sprint_#{@sprint.id}"),
            turbo_stream.replace("flash_messages", partial: "shared/flash_messages")
          ]
        end
      end
    else
      render_error("스프린트를 삭제할 수 없습니다.")
    end
  end
  
  # GET /sprints/:id/plan
  # Sprint 계획 및 분석 정보를 반환합니다.
  def plan
    authorize! :plan, @sprint
    
    # Sprint 계획 서비스 실행
    planning_result = SprintPlanningService.new(@sprint).call
    
    if planning_result.success?
      @sprint_plan = planning_result.value!
      
      # 의존성 분석
      @dependency_analysis = DependencyAnalyzer.new(@sprint).analyze
      
      # 리스크 평가
      @risk_assessment = RiskAssessment.new(
        complexity_score: calculate_sprint_complexity(@sprint),
        timeline_risk: calculate_timeline_risk(@sprint),
        resource_availability: calculate_resource_availability(@sprint),
        dependency_complexity: @dependency_analysis[:complexity_score] || 1.0
      )
      
      respond_to do |format|
        format.json do
          render_serialized(SprintPlanningSerializer, {
            sprint_plan: @sprint_plan,
            dependency_analysis: @dependency_analysis,
            risk_assessment: @risk_assessment,
            recommendations: generate_sprint_recommendations(@sprint_plan, @risk_assessment)
          })
        end
        
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("sprint_plan_#{@sprint.id}",
              SprintPlanComponent.new(
                sprint: @sprint, 
                sprint_plan: @sprint_plan,
                dependency_analysis: @dependency_analysis,
                risk_assessment: @risk_assessment
              )
            )
          ]
        end
      end
    else
      handle_sprint_planning_error(planning_result.failure)
    end
  end
  
  # GET /sprints/:id/metrics
  # Sprint 메트릭 정보를 반환합니다.
  def metrics
    authorize! :metrics, @sprint
    
    @team_metrics = TeamMetrics.new(
      velocity: calculate_sprint_velocity(@sprint),
      capacity: calculate_team_capacity(@sprint),
      burndown_data: calculate_burndown_data(@sprint),
      completion_rate: calculate_completion_rate(@sprint)
    )
    
    respond_to do |format|
      format.json do
        render_serialized(SprintMetricsSerializer, {
          metrics: @team_metrics,
          user_friendly: {
            velocity_status: velocity_status_text(@team_metrics),
            capacity_status: capacity_status_text(@team_metrics),
            progress_description: sprint_progress_description(@team_metrics),
            burndown_trend: burndown_trend_description(@team_metrics)
          }
        })
      end
      
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "sprint_metrics_#{@sprint.id}",
          SprintMetricsCardComponent.new(sprint: @sprint, team_metrics: @team_metrics)
        )
      end
    end
  end
  
  private
  
  def set_sprint
    @sprint = Sprint.accessible_by(current_ability).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error("스프린트를 찾을 수 없습니다.", status: :not_found)
  end
  
  def sprint_params
    params.require(:sprint).permit(
      :name, :description, :start_date, :end_date, :goal, :status
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
  
  # Sprint 계획 관련 helper 메서드들
  def calculate_sprint_velocity(sprint)
    # 이전 3개 스프린트의 평균 완료 작업 수
    previous_sprints = Sprint.accessible_by(current_ability)
                      .where('end_date < ?', sprint.start_date)
                      .order(end_date: :desc)
                      .limit(3)
    
    return 0.0 if previous_sprints.empty?
    
    total_completed = previous_sprints.sum { |s| s.tasks.done.count }
    (total_completed.to_f / previous_sprints.count).round(1)
  end
  
  def calculate_team_capacity(sprint)
    # 스프린트 기간 동안의 팀 작업 가능 시간 (시간 단위)
    working_days = calculate_working_days(sprint.start_date, sprint.end_date)
    team_size = current_organization.users.active.count
    
    # 1인당 하루 6시간 작업 가정
    (working_days * team_size * 6.0).round(1)
  end
  
  def calculate_working_days(start_date, end_date)
    # 주말 제외한 작업일 계산
    days = 0
    current_date = start_date
    
    while current_date <= end_date
      days += 1 unless current_date.weekend?
      current_date += 1.day
    end
    
    days
  end
  
  def calculate_sprint_complexity(sprint)
    return 1.0 if sprint.tasks.empty?
    
    # 작업들의 평균 복잡도
    total_complexity = sprint.tasks.sum { |task| task.complexity_score || 1.0 }
    (total_complexity / sprint.tasks.count).round(1)
  end
  
  def calculate_timeline_risk(sprint)
    # 마감일까지 남은 시간 대비 작업량
    remaining_days = (sprint.end_date - Date.current).to_i
    return 1.0 if remaining_days <= 0
    
    incomplete_tasks = sprint.tasks.where.not(status: 'done').count
    risk_score = incomplete_tasks.to_f / remaining_days
    
    [risk_score, 1.0].min
  end
  
  def calculate_resource_availability(sprint)
    # 팀원들의 가용성 (0.0 ~ 1.0)
    # 현재는 단순하게 0.8로 고정 (실제로는 휴가, 다른 업무 등 고려)
    0.8
  end
  
  def calculate_burndown_data(sprint)
    # 번다운 차트 데이터 생성
    data = []
    current_date = sprint.start_date
    
    while current_date <= [sprint.end_date, Date.current].min
      remaining_tasks = sprint.tasks.where('created_at <= ? AND (status != ? OR updated_at > ?)', 
                                         current_date.end_of_day, 'done', current_date.end_of_day).count
      
      data << {
        date: current_date,
        remaining: remaining_tasks,
        ideal: calculate_ideal_burndown(sprint, current_date)
      }
      
      current_date += 1.day
    end
    
    data
  end
  
  def calculate_ideal_burndown(sprint, date)
    total_days = (sprint.end_date - sprint.start_date).to_i
    elapsed_days = (date - sprint.start_date).to_i
    total_tasks = sprint.tasks.count
    
    return 0 if total_days <= 0
    
    remaining_ratio = [(total_days - elapsed_days).to_f / total_days, 0].max
    (total_tasks * remaining_ratio).round
  end
  
  def calculate_completion_rate(sprint)
    return 0.0 if sprint.tasks.empty?
    
    completed_tasks = sprint.tasks.done.count
    (completed_tasks.to_f / sprint.tasks.count * 100).round(1)
  end
  
  def generate_sprint_recommendations(sprint_plan, risk_assessment)
    recommendations = []
    
    # 높은 리스크 시 권장사항
    if risk_assessment.high_risk?
      recommendations << {
        type: 'warning',
        title: '높은 리스크 감지',
        message: '스프린트 목표 달성이 어려울 수 있습니다. 작업 범위를 축소하거나 추가 리소스를 확보하세요.',
        priority: 'high'
      }
    end
    
    # 복잡도가 높은 경우
    if risk_assessment.complexity_score > 7
      recommendations << {
        type: 'info',
        title: '높은 복잡도',
        message: '복잡한 작업들이 많습니다. 더 세부적인 계획과 정기적인 체크인을 권장합니다.',
        priority: 'medium'
      }
    end
    
    # 의존성이 많은 경우
    if sprint_plan.respond_to?(:dependency_count) && sprint_plan.dependency_count > 5
      recommendations << {
        type: 'warning',
        title: '높은 의존성',
        message: '작업간 의존성이 많습니다. 병목 지점을 주의 깊게 관리하세요.',
        priority: 'medium'
      }
    end
    
    recommendations
  end
  
  # 상태 변경 성공 시 처리
  def handle_sprint_creation_success(sprint)
    respond_to do |format|
      format.json do
        render_with_success(SprintSerializer, sprint, status: :created)
      end
      
      format.turbo_stream do
        flash[:notice] = "스프린트가 성공적으로 생성되었습니다."
        
        render turbo_stream: [
          turbo_stream.prepend("sprints_list",
            SprintCardComponent.new(sprint: sprint)
          ),
          turbo_stream.replace("sprint_form",
            render_to_string(partial: "sprints/form", locals: { sprint: Sprint.new })
          ),
          turbo_stream.replace("flash_messages",
            render_to_string(partial: "shared/flash_messages")
          )
        ]
      end
      
      format.html do
        flash[:notice] = "스프린트가 성공적으로 생성되었습니다."
        redirect_to sprint_path(sprint)
      end
    end
  end
  
  def handle_sprint_creation_error(errors)
    respond_to do |format|
      format.json do
        render_error(errors)
      end
      
      format.turbo_stream do
        @sprint ||= build_tenant_resource(Sprint, sprint_params)
        
        if errors.is_a?(ActiveModel::Errors)
          flash[:alert] = errors.full_messages.join(', ')
        else
          flash[:alert] = errors.to_s
        end
        
        render turbo_stream: [
          turbo_stream.replace("sprint_form",
            render_to_string(partial: "sprints/form", locals: { sprint: @sprint })
          ),
          turbo_stream.replace("flash_messages",
            render_to_string(partial: "shared/flash_messages")
          )
        ]
      end
      
      format.html do
        @sprint ||= build_tenant_resource(Sprint, sprint_params)
        if errors.is_a?(ActiveModel::Errors)
          flash.now[:alert] = errors.full_messages.join(', ')
        else
          flash.now[:alert] = errors.to_s
        end
        render :new, status: :unprocessable_entity
      end
    end
  end
  
  def handle_sprint_planning_error(error)
    respond_to do |format|
      format.json do
        render_error("스프린트 계획 생성에 실패했습니다: #{error}", status: :unprocessable_entity)
      end
      
      format.turbo_stream do
        flash[:alert] = "스프린트 계획을 생성할 수 없습니다: #{error}"
        
        render turbo_stream: [
          turbo_stream.replace("flash_messages",
            render_to_string(partial: "shared/flash_messages")
          )
        ]
      end
    end
  end
  
  # User-friendly 메시지 생성 메서드들
  def velocity_status_text(metrics)
    if metrics.velocity > 8
      "🚀 높은 생산성"
    elsif metrics.velocity > 4
      "📈 보통 생산성"
    else
      "📉 낮은 생산성"
    end
  end
  
  def capacity_status_text(metrics)
    if metrics.capacity > 200
      "💪 충분한 용량"
    elsif metrics.capacity > 100
      "⚖️ 적정 용량"
    else
      "⚠️ 부족한 용량"
    end
  end
  
  def sprint_progress_description(metrics)
    completion_rate = metrics.completion_rate
    
    if completion_rate >= 80
      "🎉 목표 달성 임박"
    elsif completion_rate >= 50
      "💪 순조롭게 진행"
    elsif completion_rate >= 25
      "🏃‍♂️ 가속 필요"
    else
      "🚨 진행 상태 점검 필요"
    end
  end
  
  def burndown_trend_description(metrics)
    return "📊 데이터 수집 중" unless metrics.burndown_data&.any?
    
    recent_data = metrics.burndown_data.last(3)
    return "📊 데이터 부족" if recent_data.length < 2
    
    trend = recent_data.last[:remaining] - recent_data.first[:remaining]
    
    if trend > 0
      "📈 작업량 증가 중"
    elsif trend < -2
      "📉 빠른 진행"
    else
      "📊 안정적 진행"
    end
  end
end