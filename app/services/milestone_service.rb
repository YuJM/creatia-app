# frozen_string_literal: true

require 'dry-monads'

class MilestoneService
  include Dry::Monads[:result, :maybe]
  
  def initialize(organization:, current_user:)
    @organization = organization
    @current_user = current_user
    @repository = MilestoneRepository.new
  end
  
  def list(filters = {})
    filters[:organization_id] = @organization.id
    
    result = @repository.find_by_organization(@organization.id, filters)
    
    if result.success?
      milestones = result.value!
      
      # Convert to DTOs if they're MongoDB documents
      if milestones.is_a?(Hash) && milestones[:data]
        dtos = milestones[:data].map { |m| Dto::MilestoneDto.from_model(m) }
        Success(data: dtos, metadata: milestones[:metadata])
      else
        dtos = Array(milestones).map { |m| Dto::MilestoneDto.from_model(m) }
        Success(dtos)
      end
    else
      result
    end
  end
  
  def list_for_timeline(start_date:, end_date:, include_sprints: false)
    filters = {
      start_date: start_date,
      end_date: end_date,
      status: ['planning', 'active']
    }
    
    result = @repository.find_by_organization(@organization.id, filters)
    
    if result.success?
      milestones = result.value!
      
      # Load sprints for each milestone if requested
      if include_sprints
        milestones = load_sprints_for_milestones(milestones)
      end
      
      # Convert to DTOs
      if milestones.is_a?(Hash) && milestones[:data]
        dtos = milestones[:data].map { |m| Dto::MilestoneDto.from_model(m) }
        Success(dtos)
      else
        dtos = Array(milestones).map { |m| Dto::MilestoneDto.from_model(m) }
        Success(dtos)
      end
    else
      result
    end
  end
  
  def find(id)
    result = @repository.find(id)
    
    if result.success?
      milestone = result.value!
      dto = Dto::MilestoneDto.from_model(milestone)
      Success(dto)
    else
      result
    end
  end
  
  def create(params)
    attributes = prepare_attributes(params)
    attributes[:organization_id] = @organization.id
    attributes[:created_by] = @current_user
    
    # Handle owner
    if params[:owner_id].present?
      owner = User.find_by(id: params[:owner_id])
      attributes[:owner] = owner if owner
    end
    
    # Handle stakeholders
    if params[:stakeholder_ids].present?
      stakeholders = prepare_stakeholders(params[:stakeholder_ids], params[:stakeholder_roles])
      attributes[:stakeholders] = stakeholders
    end
    
    # Handle team leads
    if params[:team_lead_ids].present? && params[:team_ids].present?
      team_leads = prepare_team_leads(params[:team_lead_ids], params[:team_ids])
      attributes[:team_leads] = team_leads
    end
    
    result = @repository.create(attributes)
    
    if result.success?
      milestone = result.value!
      dto = Dto::MilestoneDto.from_model(milestone)
      Success(dto)
    else
      result
    end
  end
  
  def update(id, params)
    attributes = prepare_attributes(params)
    
    # Handle owner update
    if params.key?(:owner_id)
      if params[:owner_id].present?
        owner = User.find_by(id: params[:owner_id])
        attributes[:owner] = owner if owner
      else
        attributes[:owner] = nil
      end
    end
    
    # Handle stakeholders update
    if params.key?(:stakeholder_ids)
      stakeholders = prepare_stakeholders(params[:stakeholder_ids], params[:stakeholder_roles])
      attributes[:stakeholders] = stakeholders
    end
    
    # Handle team leads update
    if params.key?(:team_lead_ids)
      team_leads = prepare_team_leads(params[:team_lead_ids], params[:team_ids])
      attributes[:team_leads] = team_leads
    end
    
    result = @repository.update(id, attributes)
    
    if result.success?
      milestone = result.value!
      dto = Dto::MilestoneDto.from_model(milestone)
      Success(dto)
    else
      result
    end
  end
  
  def archive(id)
    @repository.delete(id)
  end
  
  def add_objective(milestone_id, title:, description:, key_results: [])
    owner = @current_user
    
    result = @repository.add_objective(
      milestone_id,
      title,
      description,
      owner: owner,
      key_results: key_results
    )
    
    if result.success?
      Success(result.value!)
    else
      result
    end
  end
  
  def add_risk(milestone_id, title:, description:, severity:, probability:)
    result = @repository.add_risk(
      milestone_id,
      title,
      description,
      severity: severity,
      probability: probability,
      raised_by: @current_user
    )
    
    if result.success?
      Success(result.value!)
    else
      result
    end
  end
  
  def update_progress(milestone_id)
    @repository.update_progress(milestone_id)
  end
  
  def update_sprint_counts(milestone_id)
    @repository.update_sprint_counts(milestone_id)
  end
  
  private
  
  def prepare_attributes(params)
    attributes = {}
    
    # Basic fields
    [:title, :description, :status, :milestone_type].each do |field|
      attributes[field] = params[field] if params.key?(field)
    end
    
    # Date fields
    [:planned_start, :planned_end, :actual_start, :actual_end].each do |field|
      if params.key?(field)
        attributes[field] = params[field].is_a?(String) ? Date.parse(params[field]) : params[field]
      end
    end
    
    # Objectives (for initial creation)
    if params[:objectives].present?
      attributes[:objectives] = params[:objectives].map do |obj|
        {
          title: obj[:title],
          description: obj[:description],
          owner: @current_user
        }
      end
    end
    
    attributes
  end
  
  def prepare_stakeholders(user_ids, roles)
    return [] unless user_ids.present?
    
    stakeholders = []
    user_ids.each_with_index do |user_id, index|
      next if user_id.blank?
      
      user = User.find_by(id: user_id)
      next unless user
      
      stakeholders << {
        user: user,
        role: roles&.dig(index) || 'Stakeholder'
      }
    end
    
    stakeholders
  end
  
  def prepare_team_leads(user_ids, team_ids)
    return [] unless user_ids.present? && team_ids.present?
    
    team_leads = []
    user_ids.each_with_index do |user_id, index|
      next if user_id.blank?
      
      user = User.find_by(id: user_id)
      team = Team.find_by(id: team_ids[index])
      next unless user && team
      
      team_leads << {
        user: user,
        team: team
      }
    end
    
    team_leads
  end
  
  def load_sprints_for_milestones(milestones)
    milestone_array = milestones.is_a?(Hash) ? milestones[:data] : Array(milestones)
    
    sprint_repo = SprintRepository.new
    milestone_array.each do |milestone|
      sprint_result = sprint_repo.find_by_milestone(milestone.id)
      if sprint_result.success?
        milestone.define_singleton_method(:sprints) { sprint_result.value! }
      else
        milestone.define_singleton_method(:sprints) { [] }
      end
    end
    
    milestones
  end
end