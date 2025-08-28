# frozen_string_literal: true

class RoadmapsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_organization
  before_action :set_service
  before_action :set_roadmap, only: [:show, :update, :destroy]

  def index
    @roadmaps = @service.roadmaps
                       .includes(:milestones, :epic_labels, :sprints)
                       .order(:created_at)
    
    @roadmap_data = Rails.cache.fetch("roadmap_data_#{@service.id}", expires_in: 5.minutes) do
      calculate_roadmap_data
    end

    respond_to do |format|
      format.html
      format.json { render_serialized(RoadmapSerializer, roadmap_json_response) }
      format.turbo_stream
    end
  end

  def show
    @milestones = @roadmap.milestones
                          .includes(:epic_labels, :tasks)
                          .order(:target_date)
    
    @timeline_data = calculate_timeline_data
    @dependency_graph = generate_dependency_graph
    @risk_analysis = analyze_roadmap_risks
    @progress_metrics = calculate_progress_metrics

    respond_to do |format|
      format.html
      format.json { render_serialized(RoadmapSerializer, roadmap_detail_json) }
      format.turbo_stream
    end
  end

  def create
    @roadmap = @service.roadmaps.build(roadmap_params)
    @roadmap.creator = current_user

    if @roadmap.save
      respond_to do |format|
        format.html { redirect_to [@organization, @service, @roadmap], notice: '로드맵이 생성되었습니다.' }
        format.turbo_stream { render :create }
        format.json { render_serialized(RoadmapSerializer, { success: true, roadmap: @roadmap }) }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render :create_error }
        format.json { render_serialized(RoadmapSerializer, { success: false, errors: @roadmap.errors }) }
      end
    end
  end

  def update
    if @roadmap.update(roadmap_params)
      # 로드맵 캐시 무효화
      Rails.cache.delete("roadmap_data_#{@service.id}")
      
      respond_to do |format|
        format.html { redirect_to [@organization, @service, @roadmap], notice: '로드맵이 업데이트되었습니다.' }
        format.turbo_stream { render :update }
        format.json { render_serialized(RoadmapSerializer, { success: true, roadmap: @roadmap }) }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render :update_error }
        format.json { render_serialized(RoadmapSerializer, { success: false, errors: @roadmap.errors }) }
      end
    end
  end

  def timeline
    @timeline_view = params[:view] || 'quarterly'
    @timeline_data = Rails.cache.fetch("roadmap_timeline_#{@service.id}_#{@timeline_view}", expires_in: 10.minutes) do
      calculate_timeline_view_data(@timeline_view)
    end

    respond_to do |format|
      format.html
      format.json { render_serialized(RoadmapSerializer, timeline_json_response) }
      format.turbo_stream
    end
  end

  def gantt
    @gantt_data = Rails.cache.fetch("roadmap_gantt_#{@service.id}", expires_in: 10.minutes) do
      calculate_gantt_data
    end

    @dependencies = analyze_task_dependencies
    @critical_path = calculate_critical_path

    respond_to do |format|
      format.html
      format.json { render_serialized(RoadmapSerializer, gantt_json_response) }
      format.turbo_stream
    end
  end

  def metrics
    @roadmap_metrics = Rails.cache.fetch("roadmap_metrics_#{@service.id}", expires_in: 2.minutes) do
      calculate_roadmap_metrics
    end

    respond_to do |format|
      format.html { render partial: 'metrics' }
      format.json { render_serialized(RoadmapSerializer, { success: true, metrics: @roadmap_metrics }) }
      format.turbo_stream
    end
  end

  private

  def set_organization
    @organization = current_user.organizations.find(params[:organization_id])
  end

  def set_service
    @service = @organization.services.find(params[:service_id])
  end

  def set_roadmap
    @roadmap = @service.roadmaps.find(params[:id])
  end

  def roadmap_params
    params.require(:roadmap).permit(
      :name, :description, :start_date, :end_date, :visibility,
      :color, :status, milestone_ids: [], epic_label_ids: []
    )
  end

  def calculate_roadmap_data
    {
      total_roadmaps: @service.roadmaps.count,
      active_roadmaps: @service.roadmaps.where(status: 'active').count,
      completed_roadmaps: @service.roadmaps.where(status: 'completed').count,
      milestones_count: @service.milestones.count,
      overdue_milestones: @service.milestones.where('target_date < ?', Date.current).where.not(status: 'completed').count,
      completion_rate: calculate_overall_completion_rate,
      timeline_health: assess_timeline_health,
      risk_score: calculate_risk_score
    }
  end

  def calculate_timeline_data
    milestones = @roadmap.milestones.includes(:tasks, :epic_labels)
    
    {
      milestones: milestones.map do |milestone|
        {
          id: milestone.id,
          name: milestone.name,
          target_date: milestone.target_date,
          completion_date: milestone.completion_date,
          status: milestone.status,
          progress: milestone.progress_percentage,
          tasks_count: milestone.tasks.count,
          completed_tasks: milestone.tasks.where(status: 'done').count,
          risk_level: assess_milestone_risk(milestone),
          dependencies: milestone.dependent_milestones.pluck(:id),
          epic_labels: milestone.epic_labels.pluck(:name, :color)
        }
      end,
      timeline_span: {
        start_date: @roadmap.start_date,
        end_date: @roadmap.end_date,
        total_weeks: (@roadmap.end_date - @roadmap.start_date).to_i / 7
      }
    }
  end

  def calculate_timeline_view_data(view)
    case view
    when 'monthly'
      group_by_month
    when 'quarterly'  
      group_by_quarter
    when 'yearly'
      group_by_year
    else
      group_by_quarter
    end
  end

  def calculate_gantt_data
    tasks = @service.tasks.includes(:epic_label, :assignees, :dependencies)
                          .where.not(status: 'archived')
                          .order(:created_at)

    {
      tasks: tasks.map do |task|
        {
          id: task.id,
          title: task.title,
          start_date: task.start_date || task.created_at.to_date,
          end_date: task.due_date || (task.start_date&.+ 3.days) || task.created_at.to_date + 3.days,
          duration: calculate_task_duration(task),
          progress: task.progress_percentage,
          assignees: task.assignees.pluck(:email),
          epic_label: task.epic_label&.name,
          color: task.epic_label&.color || '#6b7280',
          dependencies: task.dependencies.pluck(:id),
          critical_path: task.in_critical_path?,
          priority: task.priority,
          status: task.status
        }
      end
    }
  end

  def analyze_task_dependencies
    tasks = @service.tasks.includes(:dependencies, :dependents)
    
    dependencies = []
    tasks.each do |task|
      task.dependencies.each do |dependency|
        dependencies << {
          from: dependency.id,
          to: task.id,
          type: 'finish_to_start',
          lag: 0
        }
      end
    end
    
    dependencies
  end

  def calculate_critical_path
    # 임계 경로 계산 알고리즘
    # 실제로는 더 복잡한 CPM(Critical Path Method) 구현 필요
    critical_tasks = []
    
    # 임시 구현: 의존성이 많고 지연 위험이 높은 태스크들
    @service.tasks.joins(:dependencies).group('tasks.id')
                  .having('COUNT(task_dependencies.dependency_id) >= ?', 2)
                  .where('due_date < ?', 1.week.from_now)
                  .each do |task|
      critical_tasks << {
        task_id: task.id,
        slack: 0, # 여유 시간
        impact_score: calculate_impact_score(task)
      }
    end
    
    critical_tasks.sort_by { |t| -t[:impact_score] }
  end

  def calculate_roadmap_metrics
    roadmaps = @service.roadmaps.includes(:milestones, :epic_labels)
    
    {
      total_milestones: roadmaps.joins(:milestones).count,
      completed_milestones: roadmaps.joins(:milestones).where(milestones: { status: 'completed' }).count,
      overdue_milestones: roadmaps.joins(:milestones)
                                 .where('milestones.target_date < ?', Date.current)
                                 .where.not(milestones: { status: 'completed' }).count,
      average_completion_rate: roadmaps.average { |r| r.completion_percentage || 0 }.round(1),
      timeline_health: {
        on_track: roadmaps.select { |r| r.timeline_status == 'on_track' }.count,
        at_risk: roadmaps.select { |r| r.timeline_status == 'at_risk' }.count,
        delayed: roadmaps.select { |r| r.timeline_status == 'delayed' }.count
      },
      velocity_trend: calculate_velocity_trend,
      upcoming_milestones: upcoming_milestones_data,
      risk_assessment: assess_overall_risks
    }
  end

  def roadmap_json_response
    {
      success: true,
      roadmaps: @roadmaps.map { |r| roadmap_summary(r) },
      data: @roadmap_data,
      updated_at: Time.current
    }
  end

  def roadmap_detail_json
    {
      success: true,
      roadmap: {
        id: @roadmap.id,
        name: @roadmap.name,
        description: @roadmap.description,
        timeline_data: @timeline_data,
        dependency_graph: @dependency_graph,
        risk_analysis: @risk_analysis,
        progress_metrics: @progress_metrics
      }
    }
  end

  def timeline_json_response
    {
      success: true,
      timeline: @timeline_data,
      view: @timeline_view
    }
  end

  def gantt_json_response
    {
      success: true,
      gantt: @gantt_data,
      dependencies: @dependencies,
      critical_path: @critical_path
    }
  end

  # 헬퍼 메서드들
  def calculate_overall_completion_rate
    return 0 if @service.milestones.empty?
    
    completed = @service.milestones.where(status: 'completed').count
    (completed.to_f / @service.milestones.count * 100).round(1)
  end

  def assess_timeline_health
    overdue_count = @service.milestones.where('target_date < ?', Date.current)
                           .where.not(status: 'completed').count
    total_count = @service.milestones.count
    
    return 'excellent' if overdue_count == 0
    return 'good' if overdue_count.to_f / total_count < 0.1
    return 'warning' if overdue_count.to_f / total_count < 0.3
    'critical'
  end

  def calculate_risk_score
    # 0-100 점수로 위험도 계산
    risk_factors = [
      overdue_milestones_risk,
      dependency_complexity_risk,
      resource_allocation_risk,
      scope_change_risk
    ]
    
    risk_factors.sum / risk_factors.size
  end

  def assess_milestone_risk(milestone)
    risk_score = 0
    
    # 날짜 기반 위험도
    days_to_deadline = (milestone.target_date - Date.current).to_i
    risk_score += 30 if days_to_deadline < 7
    risk_score += 20 if days_to_deadline < 14
    
    # 완료율 기반 위험도
    progress = milestone.progress_percentage
    risk_score += 25 if progress < 50 && days_to_deadline < 30
    
    # 의존성 기반 위험도
    blocked_dependencies = milestone.dependencies.where.not(status: 'done').count
    risk_score += blocked_dependencies * 15
    
    case risk_score
    when 0...20 then 'low'
    when 20...50 then 'medium'  
    when 50...70 then 'high'
    else 'critical'
    end
  end

  def group_by_quarter
    milestones = @service.milestones.order(:target_date)
    quarters = {}
    
    milestones.each do |milestone|
      quarter_key = "#{milestone.target_date.year}-Q#{(milestone.target_date.month - 1) / 3 + 1}"
      quarters[quarter_key] ||= []
      quarters[quarter_key] << {
        id: milestone.id,
        name: milestone.name,
        target_date: milestone.target_date,
        status: milestone.status,
        progress: milestone.progress_percentage
      }
    end
    
    quarters
  end

  def group_by_month
    milestones = @service.milestones.order(:target_date)
    months = {}
    
    milestones.each do |milestone|
      month_key = milestone.target_date.strftime("%Y-%m")
      months[month_key] ||= []
      months[month_key] << {
        id: milestone.id,
        name: milestone.name,
        target_date: milestone.target_date,
        status: milestone.status,
        progress: milestone.progress_percentage
      }
    end
    
    months
  end

  def calculate_task_duration(task)
    if task.start_date && task.due_date
      (task.due_date - task.start_date).to_i + 1
    else
      3 # 기본값
    end
  end

  def calculate_impact_score(task)
    score = 0
    score += task.dependencies.count * 10  # 의존성 수
    score += task.dependents.count * 15    # 이 태스크에 의존하는 태스크 수
    score += priority_weight(task.priority)
    score
  end

  def priority_weight(priority)
    case priority
    when 'urgent' then 25
    when 'high' then 20
    when 'medium' then 10
    when 'low' then 5
    else 0
    end
  end

  def calculate_velocity_trend
    # 지난 4주간의 완료 속도 계산
    weeks = []
    4.times do |i|
      week_start = i.weeks.ago.beginning_of_week
      week_end = i.weeks.ago.end_of_week
      
      completed_tasks = @service.tasks.where(
        status: 'done',
        updated_at: week_start..week_end
      ).count
      
      weeks.unshift({
        week: week_start.strftime("W%U"),
        completed: completed_tasks
      })
    end
    
    weeks
  end

  def upcoming_milestones_data
    @service.milestones.where('target_date BETWEEN ? AND ?', 
                             Date.current, 1.month.from_now)
           .order(:target_date)
           .limit(5)
           .map do |milestone|
      {
        id: milestone.id,
        name: milestone.name,
        target_date: milestone.target_date,
        days_remaining: (milestone.target_date - Date.current).to_i,
        progress: milestone.progress_percentage,
        risk_level: assess_milestone_risk(milestone)
      }
    end
  end

  def assess_overall_risks
    {
      schedule_risk: calculate_schedule_risk,
      dependency_risk: calculate_dependency_risk,
      resource_risk: calculate_resource_risk,
      scope_risk: calculate_scope_risk
    }
  end

  def roadmap_summary(roadmap)
    {
      id: roadmap.id,
      name: roadmap.name,
      status: roadmap.status,
      progress: roadmap.completion_percentage,
      milestones_count: roadmap.milestones.count,
      timeline_health: roadmap.timeline_status
    }
  end

  # 위험도 계산 헬퍼 메서드들
  def overdue_milestones_risk
    overdue_count = @service.milestones.where('target_date < ?', Date.current)
                           .where.not(status: 'completed').count
    total_count = @service.milestones.count
    return 0 if total_count == 0
    
    (overdue_count.to_f / total_count * 100).round
  end

  def dependency_complexity_risk
    # 의존성 복잡도 기반 위험도
    high_dependency_tasks = @service.tasks.joins(:dependencies)
                                   .group('tasks.id')
                                   .having('COUNT(task_dependencies.dependency_id) >= ?', 3)
                                   .count
    
    total_tasks = @service.tasks.count
    return 0 if total_tasks == 0
    
    (high_dependency_tasks.to_f / total_tasks * 100).round
  end

  def resource_allocation_risk
    # 리소스 할당 위험도 (간단한 구현)
    overallocated_users = @service.organization.users
                                  .joins(:assigned_tasks)
                                  .where(tasks: { status: ['in_progress', 'todo'] })
                                  .group('users.id')
                                  .having('COUNT(tasks.id) >= ?', 10)
                                  .count
    
    total_users = @service.organization.users.count
    return 0 if total_users == 0
    
    (overallocated_users.to_f / total_users * 100).round
  end

  def scope_change_risk
    # 범위 변경 위험도 (최근 변경사항 기준)
    recent_changes = @service.tasks.where('updated_at > ?', 1.week.ago).count
    total_tasks = @service.tasks.count
    return 0 if total_tasks == 0
    
    change_rate = (recent_changes.to_f / total_tasks * 100).round
    [change_rate, 100].min # 최대 100점
  end

  def calculate_schedule_risk
    overdue_milestones_risk
  end

  def calculate_dependency_risk
    dependency_complexity_risk
  end

  def calculate_resource_risk
    resource_allocation_risk
  end

  def calculate_scope_risk
    scope_change_risk
  end
end