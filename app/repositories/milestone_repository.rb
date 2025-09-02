# frozen_string_literal: true

require 'dry-monads'

# Milestone Repository - MongoDB Milestone 데이터 접근 계층
class MilestoneRepository < BaseRepository
  include Dry::Monads[:result]
  
  def initialize
    super
    @model_class = Mongodb::MongoMilestone
  end
  
  protected

  def model_class
    @model_class
  end

  def allowed_filter_keys
    %w[organization_id status milestone_type planned_start planned_end owner_id stakeholder_id health_status]
  end
  
  private
  
  def handle_error(error, message)
    Rails.logger.error "[MilestoneRepository] #{message}: #{error.message}"
    Rails.logger.error error.backtrace.first(5).join("\n")
    Failure([:database_error, message])
  end
  
  def format_validation_errors(error)
    [:validation_error, error.record.errors.to_h]
  end
  
  public

  # ===== CREATE =====
  def create(attributes)
    return Failure([:invalid_attributes, "Attributes cannot be nil"]) if attributes.nil?
    return Failure([:missing_required, "Organization ID is required"]) unless attributes[:organization_id].present?

    begin
      milestone = @model_class.new(attributes.except(:created_by, :owner, :stakeholders, :team_leads))
      
      # User snapshots 설정 (안전하게 처리)
      if attributes[:created_by]
        result = set_created_by_safely(milestone, attributes[:created_by])
        return result if result.failure?
      end
      
      if attributes[:owner]
        result = set_owner_safely(milestone, attributes[:owner])
        return result if result.failure?
      end
      
      if attributes[:stakeholders].present?
        result = set_stakeholders_safely(milestone, attributes[:stakeholders])
        return result if result.failure?
      end
      
      if attributes[:team_leads].present?
        result = set_team_leads_safely(milestone, attributes[:team_leads])
        return result if result.failure?
      end
      
      milestone.save!
      Success(milestone)
    rescue Mongoid::Errors::Validations => e
      Failure(format_validation_errors(e))
    rescue => e
      handle_error(e, "Failed to create milestone")
    end
  end

  # ===== READ =====
  def find_by_organization(organization_id, options = {})
    return Failure([:invalid_id, "Organization ID is required"]) unless organization_id.present?

    begin
      query = @model_class.where(organization_id: organization_id.to_s)
      
      # Status filter (안전한 값 검증)
      if options[:status].present?
        valid_statuses = %w[planning active completed on_hold cancelled]
        status_filter = Array(options[:status]).select { |s| valid_statuses.include?(s.to_s) }
        query = query.where(status: { "$in" => status_filter }) if status_filter.any?
      end
      
      # Type filter
      if options[:milestone_type].present?
        valid_types = %w[release feature business]
        if valid_types.include?(options[:milestone_type].to_s)
          query = query.where(milestone_type: options[:milestone_type])
        end
      end
      
      # Date range filter (안전한 날짜 처리)
      if options[:start_date] && options[:end_date]
        start_date = parse_date_safely(options[:start_date])
        end_date = parse_date_safely(options[:end_date])
        
        if start_date && end_date
          query = query.where(
            :planned_start.lte => end_date,
            :planned_end.gte => start_date
          )
        end
      end
      
      # Owner filter
      if options[:owner_id].present?
        query = query.where("owner_snapshot.user_id" => options[:owner_id].to_s)
      end
      
      # Stakeholder filter
      if options[:stakeholder_id].present?
        query = query.where("stakeholder_snapshots.user_id" => options[:stakeholder_id].to_s)
      end
      
      # Health status filter (computed field)
      if options[:health_status].present?
        milestone_ids = filter_by_health_status(query, options[:health_status])
        query = query.where(:_id.in => milestone_ids)
      end
      
      # Sorting
      query = apply_sorting(query, options)
      
      # Pagination
      result = paginate(query, options)
      
      Success(result)
    rescue => e
      handle_error(e, "Failed to find milestones by organization")
    end
  end

  def find_active(organization_id)
    return Failure([:invalid_id, "Organization ID is required"]) unless organization_id.present?

    begin
      milestones = @model_class.active.where(organization_id: organization_id.to_s)
                               .order(planned_end: :asc)
      
      Success(milestones)
    rescue => e
      handle_error(e, "Failed to find active milestones")
    end
  end

  def find_at_risk(organization_id)
    return Failure([:invalid_id, "Organization ID is required"]) unless organization_id.present?

    begin
      milestones = @model_class.at_risk.where(organization_id: organization_id.to_s)
      Success(milestones)
    rescue => e
      handle_error(e, "Failed to find at-risk milestones")
    end
  end

  # ===== UPDATE =====
  def update(id, attributes)
    return super(id, attributes) if attributes.nil? || id.blank?

    begin
      milestone = @model_class.find(id)
      
      # Handle user snapshot updates (안전하게 처리)
      update_attributes = attributes.dup
      
      if attributes.key?(:owner)
        result = set_owner_safely(milestone, attributes[:owner])
        return result if result.failure?
        update_attributes.delete(:owner)
      end
      
      # Handle stakeholder updates
      if attributes.key?(:stakeholders)
        result = set_stakeholders_safely(milestone, attributes[:stakeholders])
        return result if result.failure?
        update_attributes.delete(:stakeholders)
      end
      
      # Handle team lead updates
      if attributes.key?(:team_leads)
        result = set_team_leads_safely(milestone, attributes[:team_leads])
        return result if result.failure?
        update_attributes.delete(:team_leads)
      end
      
      milestone.update!(update_attributes) if update_attributes.any?
      Success(milestone)
    rescue Mongoid::Errors::DocumentNotFound
      Failure(:not_found)
    rescue Mongoid::Errors::Validations => e
      Failure(format_validation_errors(e))
    rescue => e
      handle_error(e, "Failed to update milestone")
    end
  end

  # ===== DELETE =====
  def delete(id)
    return Failure([:invalid_id, "ID cannot be blank"]) if id.blank?

    begin
      milestone = @model_class.find(id)
      
      # Archive instead of hard delete
      milestone.update!(
        status: 'cancelled',
        actual_end: Date.current
      )
      
      Success(true)
    rescue Mongoid::Errors::DocumentNotFound
      Failure(:not_found)
    rescue => e
      handle_error(e, "Failed to delete milestone")
    end
  end

  # ===== MILESTONE SPECIFIC OPERATIONS =====
  
  # Objectives & Key Results
  def add_objective(milestone_id, title, description, owner:, key_results: [])
    return Failure([:invalid_id, "Milestone ID is required"]) if milestone_id.blank?
    return Failure([:invalid_data, "Title is required"]) if title.blank?
    return Failure([:invalid_data, "Owner is required"]) unless owner

    begin
      milestone = @model_class.find(milestone_id)
      objective = milestone.add_objective(title, description, owner: owner, key_results: key_results)
      milestone.save!
      Success(objective)
    rescue Mongoid::Errors::DocumentNotFound
      Failure(:not_found)
    rescue => e
      handle_error(e, "Failed to add objective")
    end
  end

  def update_key_result(milestone_id, objective_id, key_result_id, current_value, updated_by:)
    return Failure([:invalid_id, "Milestone ID is required"]) if milestone_id.blank?
    return Failure([:invalid_data, "Current value must be a number"]) unless current_value.is_a?(Numeric)
    return Failure([:invalid_data, "Updated by user is required"]) unless updated_by

    begin
      milestone = @model_class.find(milestone_id)
      milestone.update_key_result(objective_id, key_result_id, current_value, updated_by: updated_by)
      milestone.save!
      Success(true)
    rescue Mongoid::Errors::DocumentNotFound
      Failure(:not_found)
    rescue => e
      handle_error(e, "Failed to update key result")
    end
  end

  # Risk Management
  def add_risk(milestone_id, title, description, severity:, probability:, raised_by:, owner: nil)
    return Failure([:invalid_id, "Milestone ID is required"]) if milestone_id.blank?
    return Failure([:invalid_data, "Title is required"]) if title.blank?
    
    valid_severities = %w[low medium high critical]
    return Failure([:invalid_data, "Invalid severity"]) unless valid_severities.include?(severity.to_s)
    
    valid_probabilities = %w[low medium high]
    return Failure([:invalid_data, "Invalid probability"]) unless valid_probabilities.include?(probability.to_s)

    begin
      milestone = @model_class.find(milestone_id)
      risk = milestone.add_risk(
        title, 
        description, 
        severity: severity, 
        probability: probability, 
        raised_by: raised_by, 
        owner: owner
      )
      milestone.save!
      Success(risk)
    rescue Mongoid::Errors::DocumentNotFound
      Failure(:not_found)
    rescue => e
      handle_error(e, "Failed to add risk")
    end
  end

  def update_risk_mitigation(milestone_id, risk_id, mitigation_plan, owner:)
    return Failure([:invalid_id, "Milestone ID is required"]) if milestone_id.blank?
    return Failure([:invalid_data, "Mitigation plan is required"]) if mitigation_plan.blank?

    begin
      milestone = @model_class.find(milestone_id)
      milestone.update_risk_mitigation(risk_id, mitigation_plan, owner: owner)
      milestone.save!
      Success(true)
    rescue Mongoid::Errors::DocumentNotFound
      Failure(:not_found)
    rescue => e
      handle_error(e, "Failed to update risk mitigation")
    end
  end

  # Dependency Management
  def add_dependency(milestone_id, title, description, type:, dependent_on:, owner:, due_date: nil)
    return Failure([:invalid_id, "Milestone ID is required"]) if milestone_id.blank?
    return Failure([:invalid_data, "Title is required"]) if title.blank?
    
    valid_types = %w[internal external technical business]
    return Failure([:invalid_data, "Invalid dependency type"]) unless valid_types.include?(type.to_s)

    begin
      milestone = @model_class.find(milestone_id)
      dependency = milestone.add_dependency(
        title,
        description,
        type: type,
        dependent_on: dependent_on,
        owner: owner,
        due_date: due_date
      )
      milestone.save!
      Success(dependency)
    rescue Mongoid::Errors::DocumentNotFound
      Failure(:not_found)
    rescue => e
      handle_error(e, "Failed to add dependency")
    end
  end

  # Blocker Management
  def add_blocker(milestone_id, title, description, raised_by:, severity: 'high')
    return Failure([:invalid_id, "Milestone ID is required"]) if milestone_id.blank?
    return Failure([:invalid_data, "Title is required"]) if title.blank?

    begin
      milestone = @model_class.find(milestone_id)
      blocker = milestone.add_blocker(title, description, raised_by: raised_by, severity: severity)
      milestone.save!
      Success(blocker)
    rescue Mongoid::Errors::DocumentNotFound
      Failure(:not_found)
    rescue => e
      handle_error(e, "Failed to add blocker")
    end
  end

  def assign_blocker(milestone_id, blocker_id, assignee:)
    return Failure([:invalid_id, "Milestone ID is required"]) if milestone_id.blank?
    return Failure([:invalid_data, "Assignee is required"]) unless assignee

    begin
      milestone = @model_class.find(milestone_id)
      milestone.assign_blocker(blocker_id, assignee: assignee)
      milestone.save!
      Success(true)
    rescue Mongoid::Errors::DocumentNotFound
      Failure(:not_found)
    rescue => e
      handle_error(e, "Failed to assign blocker")
    end
  end

  def resolve_blocker(milestone_id, blocker_id, resolution)
    return Failure([:invalid_id, "Milestone ID is required"]) if milestone_id.blank?
    return Failure([:invalid_data, "Resolution is required"]) if resolution.blank?

    begin
      milestone = @model_class.find(milestone_id)
      milestone.resolve_blocker(blocker_id, resolution)
      milestone.save!
      Success(true)
    rescue Mongoid::Errors::DocumentNotFound
      Failure(:not_found)
    rescue => e
      handle_error(e, "Failed to resolve blocker")
    end
  end

  # Progress Updates
  def update_progress(milestone_id)
    return Failure([:invalid_id, "Milestone ID is required"]) if milestone_id.blank?

    begin
      milestone = @model_class.find(milestone_id)
      milestone.update_progress
      Success(milestone)
    rescue Mongoid::Errors::DocumentNotFound
      Failure(:not_found)
    rescue => e
      handle_error(e, "Failed to update progress")
    end
  end

  def update_sprint_counts(milestone_id)
    return Failure([:invalid_id, "Milestone ID is required"]) if milestone_id.blank?

    begin
      milestone = @model_class.find(milestone_id)
      
      # Count sprints associated with this milestone (안전한 쿼리)
      sprint_count = Mongodb::MongoSprintV2.where(milestone_id: milestone_id.to_s).count
      completed_sprints = Mongodb::MongoSprintV2.where(
        milestone_id: milestone_id.to_s,
        status: 'completed'
      ).count
      
      milestone.update!(
        total_sprints: sprint_count,
        completed_sprints: completed_sprints
      )
      
      Success(milestone)
    rescue Mongoid::Errors::DocumentNotFound
      Failure(:not_found)
    rescue => e
      handle_error(e, "Failed to update sprint counts")
    end
  end

  # ===== AGGREGATIONS =====
  
  def progress_summary(organization_id)
    return Failure([:invalid_id, "Organization ID is required"]) unless organization_id.present?

    begin
      pipeline = [
        { "$match" => { 
          organization_id: organization_id.to_s,
          status: { "$in" => ["active", "planning"] }
        }},
        { "$group" => {
          _id: "$status",
          count: { "$sum" => 1 },
          avg_progress: { "$avg" => "$progress_percentage" },
          total_tasks: { "$sum" => "$total_tasks" },
          completed_tasks: { "$sum" => "$completed_tasks" }
        }}
      ]
      
      results = @model_class.collection.aggregate(pipeline)
      
      summary = {
        by_status: results.to_a,
        total_milestones: results.sum { |r| r["count"] },
        overall_progress: calculate_overall_progress(results)
      }
      
      Success(summary)
    rescue => e
      handle_error(e, "Failed to get progress summary")
    end
  end

  def risk_summary(organization_id)
    return Failure([:invalid_id, "Organization ID is required"]) unless organization_id.present?

    begin
      pipeline = [
        { "$match" => { 
          organization_id: organization_id.to_s,
          status: "active"
        }},
        { "$unwind" => "$risks" },
        { "$group" => {
          _id: {
            severity: "$risks.severity",
            status: "$risks.status"
          },
          count: { "$sum" => 1 }
        }},
        { "$group" => {
          _id: "$_id.severity",
          statuses: {
            "$push" => {
              status: "$_id.status",
              count: "$count"
            }
          },
          total: { "$sum" => "$count" }
        }}
      ]
      
      results = @model_class.collection.aggregate(pipeline)
      Success(results.to_a)
    rescue => e
      handle_error(e, "Failed to get risk summary")
    end
  end

  def timeline_analysis(organization_id)
    return Failure([:invalid_id, "Organization ID is required"]) unless organization_id.present?

    begin
      active_milestones = @model_class.active.where(organization_id: organization_id.to_s)
      
      analysis = {
        on_track: [],
        at_risk: [],
        overdue: []
      }
      
      active_milestones.each do |milestone|
        summary = milestone_summary(milestone)
        
        if milestone.respond_to?(:is_overdue?) && milestone.is_overdue?
          analysis[:overdue] << summary
        elsif milestone.respond_to?(:health_status) && milestone.health_status == 'at_risk'
          analysis[:at_risk] << summary
        else
          analysis[:on_track] << summary
        end
      end
      
      Success(analysis)
    rescue => e
      handle_error(e, "Failed to analyze timeline")
    end
  end

  private

  def set_created_by_safely(milestone, user)
    return Success(milestone) unless user
    
    begin
      milestone.set_created_by(user)
      Success(milestone)
    rescue => e
      Rails.logger.error "Failed to set created_by: #{e.message}"
      Failure([:user_snapshot_error, "Failed to set created_by user"])
    end
  end

  def set_owner_safely(milestone, user)
    return Success(milestone) unless user
    
    begin
      milestone.set_owner(user)
      Success(milestone)
    rescue => e
      Rails.logger.error "Failed to set owner: #{e.message}"
      Failure([:user_snapshot_error, "Failed to set owner user"])
    end
  end

  def set_stakeholders_safely(milestone, stakeholders)
    return Success(milestone) unless stakeholders.present?
    
    begin
      milestone.stakeholder_snapshots = []
      stakeholders.each do |stakeholder_data|
        next unless stakeholder_data[:user]
        milestone.add_stakeholder(
          stakeholder_data[:user],
          role: stakeholder_data[:role] || 'Stakeholder'
        )
      end
      Success(milestone)
    rescue => e
      Rails.logger.error "Failed to set stakeholders: #{e.message}"
      Failure([:user_snapshot_error, "Failed to set stakeholders"])
    end
  end

  def set_team_leads_safely(milestone, team_leads)
    return Success(milestone) unless team_leads.present?
    
    begin
      milestone.team_lead_snapshots = []
      team_leads.each do |lead_data|
        next unless lead_data[:user] && lead_data[:team]
        milestone.add_team_lead(lead_data[:user], lead_data[:team])
      end
      Success(milestone)
    rescue => e
      Rails.logger.error "Failed to set team leads: #{e.message}"
      Failure([:user_snapshot_error, "Failed to set team leads"])
    end
  end

  def parse_date_safely(date_input)
    return nil unless date_input.present?
    
    case date_input
    when Date, Time, DateTime
      date_input
    when String
      Date.parse(date_input) rescue nil
    else
      nil
    end
  end

  # paginate 메서드는 BaseRepository에서 상속받아 사용
  
  def apply_sorting(query, options)
    sort_by = options[:sort_by].to_s
    sort_order = options[:sort_order].to_s == 'desc' ? :desc : :asc
    
    case sort_by
    when 'planned_start'
      query.order(planned_start: sort_order)
    when 'planned_end'
      query.order(planned_end: sort_order)
    when 'progress'
      query.order(progress_percentage: sort_order)
    when 'created_at'
      query.order(created_at: sort_order)
    else
      query.order(planned_end: :asc)
    end
  end

  def filter_by_health_status(query, health_status)
    # Since health_status is calculated, we need to fetch and filter
    milestones = query.to_a
    filtered = milestones.select do |m|
      m.respond_to?(:health_status) && m.health_status == health_status
    end
    filtered.map(&:id)
  end

  def milestone_summary(milestone)
    {
      id: milestone.id.to_s,
      title: milestone.title,
      progress_percentage: milestone.progress_percentage || 0,
      days_remaining: milestone.respond_to?(:days_remaining) ? milestone.days_remaining : nil,
      health_status: milestone.respond_to?(:health_status) ? milestone.health_status : 'unknown',
      owner: milestone.owner_snapshot
    }
  end

  def calculate_overall_progress(results)
    total_tasks = results.sum { |r| r["total_tasks"] || 0 }
    completed_tasks = results.sum { |r| r["completed_tasks"] || 0 }
    
    return 0 if total_tasks.zero?
    
    (completed_tasks.to_f / total_tasks * 100).round(2)
  end
end