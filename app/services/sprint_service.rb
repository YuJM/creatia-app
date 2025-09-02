# frozen_string_literal: true

require 'dry-monads'

class SprintService
  include Dry::Monads[:result, :maybe]
  
  def initialize(organization:, current_user:)
    @organization = organization
    @current_user = current_user
    @repository = SprintRepository.new
    @task_repository = TaskRepository.new
  end
  
  def list(filters = {})
    filters[:organization_id] = @organization.id
    
    result = @repository.find_by_organization(@organization.id, filters)
    
    if result.success?
      sprints = result.value!
      
      # Convert to DTOs
      if sprints.is_a?(Hash) && sprints[:data]
        dtos = sprints[:data].map { |s| Dto::SprintDto.from_model(s) }
        Success(data: dtos, metadata: sprints[:metadata])
      else
        dtos = Array(sprints).map { |s| Dto::SprintDto.from_model(s) }
        Success(dtos)
      end
    else
      result
    end
  end
  
  def list_by_milestone(milestone_id)
    result = @repository.find_by_milestone(milestone_id)
    
    if result.success?
      sprints = result.value!
      dtos = Array(sprints).map { |s| Dto::SprintDto.from_model(s) }
      Success(dtos)
    else
      result
    end
  end
  
  def find(id)
    result = @repository.find(id)
    
    if result.success?
      sprint = result.value!
      dto = Dto::SprintDto.from_model(sprint)
      Success(dto)
    else
      result
    end
  end
  
  def find_current(team_id = nil)
    result = @repository.find_current(@organization.id, team_id)
    
    if result.success?
      sprint = result.value!
      dto = Dto::SprintDto.from_model(sprint)
      Success(dto)
    else
      result
    end
  end
  
  def create(params)
    attributes = prepare_attributes(params)
    attributes[:organization_id] = @organization.id
    attributes[:created_by] = @current_user
    
    # Handle sprint owner
    if params[:sprint_owner_id].present?
      owner = User.find_by(id: params[:sprint_owner_id])
      attributes[:sprint_owner] = owner if owner
    end
    
    # Handle scrum master
    if params[:scrum_master_id].present?
      master = User.find_by(id: params[:scrum_master_id])
      attributes[:scrum_master] = master if master
    end
    
    # Handle team members
    if params[:team_member_ids].present?
      members = prepare_team_members(params[:team_member_ids], params[:member_roles], params[:member_capacities])
      attributes[:team_members] = members
    end
    
    result = @repository.create(attributes)
    
    if result.success?
      sprint = result.value!
      dto = Dto::SprintDto.from_model(sprint)
      Success(dto)
    else
      result
    end
  end
  
  def update(id, params)
    attributes = prepare_attributes(params)
    
    # Handle sprint owner update
    if params.key?(:sprint_owner_id)
      if params[:sprint_owner_id].present?
        owner = User.find_by(id: params[:sprint_owner_id])
        attributes[:sprint_owner] = owner if owner
      else
        attributes[:sprint_owner] = nil
      end
    end
    
    # Handle scrum master update
    if params.key?(:scrum_master_id)
      if params[:scrum_master_id].present?
        master = User.find_by(id: params[:scrum_master_id])
        attributes[:scrum_master] = master if master
      else
        attributes[:scrum_master] = nil
      end
    end
    
    # Handle team members update
    if params.key?(:team_member_ids)
      members = prepare_team_members(params[:team_member_ids], params[:member_roles], params[:member_capacities])
      attributes[:team_members] = members
    end
    
    result = @repository.update(id, attributes)
    
    if result.success?
      sprint = result.value!
      dto = Dto::SprintDto.from_model(sprint)
      Success(dto)
    else
      result
    end
  end
  
  def start(id)
    result = @repository.find(id)
    
    if result.success?
      sprint = result.value!
      
      if sprint.status != 'planning'
        return Failure("Sprint must be in planning status to start")
      end
      
      update_result = @repository.update(id, {
        status: 'active',
        actual_start: Date.current
      })
      
      if update_result.success?
        sprint = update_result.value!
        dto = Dto::SprintDto.from_model(sprint)
        Success(dto)
      else
        update_result
      end
    else
      result
    end
  end
  
  def complete(id)
    result = @repository.find(id)
    
    if result.success?
      sprint = result.value!
      
      if sprint.status != 'active'
        return Failure("Sprint must be active to complete")
      end
      
      # Calculate final metrics
      completed_points = calculate_completed_points(sprint)
      
      update_result = @repository.update(id, {
        status: 'completed',
        actual_end: Date.current,
        completed_points: completed_points,
        actual_velocity: completed_points
      })
      
      if update_result.success?
        sprint = update_result.value!
        dto = Dto::SprintDto.from_model(sprint)
        Success(dto)
      else
        update_result
      end
    else
      result
    end
  end
  
  def add_task_to_sprint(sprint_id, task_id)
    sprint_result = @repository.find(sprint_id)
    task_result = @task_repository.find(task_id)
    
    if sprint_result.success? && task_result.success?
      task = task_result.value!
      @repository.add_task_to_sprint(sprint_id, task)
    else
      Failure("Sprint or task not found")
    end
  end
  
  def remove_task_from_sprint(sprint_id, task_id)
    sprint_result = @repository.find(sprint_id)
    task_result = @task_repository.find(task_id)
    
    if sprint_result.success? && task_result.success?
      task = task_result.value!
      @repository.remove_task_from_sprint(sprint_id, task)
    else
      Failure("Sprint or task not found")
    end
  end
  
  def add_blocker(sprint_id, description)
    @repository.add_blocker(
      sprint_id,
      description,
      raised_by: @current_user
    )
  end
  
  def resolve_blocker(sprint_id, blocker_id, resolution)
    @repository.resolve_blocker(
      sprint_id,
      blocker_id,
      resolution,
      resolved_by: @current_user
    )
  end
  
  def record_standup(sprint_id, attendee_ids, notes: nil, blockers: [])
    attendees = User.where(id: attendee_ids)
    
    @repository.record_standup(
      sprint_id,
      date: Date.current,
      attendees: attendees,
      notes: notes,
      blockers: blockers,
      recorded_by: @current_user
    )
  end
  
  def calculate_health_score(sprint_id)
    @repository.calculate_health_score(sprint_id)
  end
  
  def update_task_counts(sprint_id)
    @repository.update_task_counts(sprint_id)
  end
  
  def velocity_metrics(team_id: nil, limit: 5)
    @repository.velocity_metrics(@organization.id, team_id: team_id, limit: limit)
  end
  
  def burndown_data(sprint_id)
    @repository.burndown_data(sprint_id)
  end
  
  private
  
  def prepare_attributes(params)
    attributes = {}
    
    # Basic fields
    [:name, :goal, :sprint_number, :status, :milestone_id, :team_id, :service_id].each do |field|
      attributes[field] = params[field] if params.key?(field)
    end
    
    # Date fields
    [:start_date, :end_date].each do |field|
      if params.key?(field)
        attributes[field] = params[field].is_a?(String) ? Date.parse(params[field]) : params[field]
      end
    end
    
    # Numeric fields
    [:working_days, :team_capacity, :planned_velocity, :committed_points, :stretch_points].each do |field|
      attributes[field] = params[field].to_f if params.key?(field)
    end
    
    attributes
  end
  
  def prepare_team_members(user_ids, roles, capacities)
    return [] unless user_ids.present?
    
    members = []
    user_ids.each_with_index do |user_id, index|
      next if user_id.blank?
      
      user = User.find_by(id: user_id)
      next unless user
      
      members << {
        user: user,
        role: roles&.dig(index) || 'developer',
        capacity_hours: capacities&.dig(index)&.to_f || 40.0
      }
    end
    
    members
  end
  
  def calculate_completed_points(sprint)
    # Get all tasks in the sprint
    task_ids = sprint.task_ids || []
    return 0 if task_ids.empty?
    
    # Sum up story points of completed tasks
    completed_tasks = Mongodb::MongoTask.where(
      :_id.in => task_ids,
      status: 'done'
    )
    
    completed_tasks.sum(:story_points) || 0
  end
end