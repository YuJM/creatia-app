# frozen_string_literal: true

# Milestone Repository - MongoDB Milestone 데이터 접근 계층
class MilestoneRepository < BaseRepository
  def initialize
    super
    @model_class = Mongodb::MongoMilestone
  end

  # ===== CREATE =====
  def create(attributes)
    milestone = @model_class.new(attributes)
    
    # User snapshots 설정
    if attributes[:created_by]
      milestone.set_created_by(attributes[:created_by])
    end
    
    if attributes[:owner]
      milestone.set_owner(attributes[:owner])
    end
    
    if attributes[:stakeholders].present?
      attributes[:stakeholders].each do |stakeholder_data|
        milestone.add_stakeholder(
          stakeholder_data[:user],
          role: stakeholder_data[:role]
        )
      end
    end
    
    if attributes[:team_leads].present?
      attributes[:team_leads].each do |lead_data|
        milestone.add_team_lead(lead_data[:user], lead_data[:team])
      end
    end
    
    milestone.save!
    Result.success(milestone)
  rescue Mongoid::Errors::Validations => e
    Result.failure(format_validation_errors(e))
  rescue => e
    handle_error(e, "Failed to create milestone")
  end

  # ===== READ =====
  def find(id)
    milestone = @model_class.find(id)
    Result.success(milestone)
  rescue Mongoid::Errors::DocumentNotFound
    Result.failure(:not_found)
  rescue => e
    handle_error(e, "Failed to find milestone")
  end

  def find_by_organization(organization_id, options = {})
    query = @model_class.where(organization_id: organization_id.to_s)
    
    # Status filter
    query = query.where(status: options[:status]) if options[:status]
    
    # Type filter
    query = query.where(milestone_type: options[:milestone_type]) if options[:milestone_type]
    
    # Date range filter
    if options[:start_date] && options[:end_date]
      query = query.where(
        :planned_start.lte => options[:end_date],
        :planned_end.gte => options[:start_date]
      )
    end
    
    # Owner filter
    if options[:owner_id]
      query = query.where("owner_snapshot.user_id" => options[:owner_id].to_s)
    end
    
    # Stakeholder filter
    if options[:stakeholder_id]
      query = query.where("stakeholder_snapshots.user_id" => options[:stakeholder_id].to_s)
    end
    
    # Health status filter
    if options[:health_status]
      milestone_ids = filter_by_health_status(query, options[:health_status])
      query = query.where(:_id.in => milestone_ids)
    end
    
    # Sorting
    query = apply_sorting(query, options)
    
    # Pagination
    result = paginate(query, options)
    
    Result.success(result)
  rescue => e
    handle_error(e, "Failed to find milestones by organization")
  end

  def find_active(organization_id)
    milestones = @model_class.active.where(organization_id: organization_id.to_s)
                             .order(planned_end: :asc)
    
    Result.success(milestones)
  rescue => e
    handle_error(e, "Failed to find active milestones")
  end

  def find_at_risk(organization_id)
    milestones = @model_class.at_risk.where(organization_id: organization_id.to_s)
    
    Result.success(milestones)
  rescue => e
    handle_error(e, "Failed to find at-risk milestones")
  end

  # ===== UPDATE =====
  def update(id, attributes)
    milestone = @model_class.find(id)
    
    # Handle user snapshot updates
    if attributes[:owner]
      milestone.set_owner(attributes.delete(:owner))
    end
    
    # Handle stakeholder updates
    if attributes.key?(:stakeholders)
      stakeholders = attributes.delete(:stakeholders)
      
      # Clear existing and add new
      milestone.stakeholder_snapshots = []
      stakeholders.each do |stakeholder_data|
        milestone.add_stakeholder(
          stakeholder_data[:user],
          role: stakeholder_data[:role]
        )
      end
    end
    
    # Handle team lead updates
    if attributes.key?(:team_leads)
      team_leads = attributes.delete(:team_leads)
      
      # Clear existing and add new
      milestone.team_lead_snapshots = []
      team_leads.each do |lead_data|
        milestone.add_team_lead(lead_data[:user], lead_data[:team])
      end
    end
    
    milestone.update!(attributes)
    Result.success(milestone)
  rescue Mongoid::Errors::DocumentNotFound
    Result.failure(:not_found)
  rescue Mongoid::Errors::Validations => e
    Result.failure(format_validation_errors(e))
  rescue => e
    handle_error(e, "Failed to update milestone")
  end

  # ===== DELETE =====
  def delete(id)
    milestone = @model_class.find(id)
    
    # Archive instead of hard delete
    milestone.update!(
      status: 'cancelled',
      actual_end: Date.current
    )
    
    Result.success(true)
  rescue Mongoid::Errors::DocumentNotFound
    Result.failure(:not_found)
  rescue => e
    handle_error(e, "Failed to delete milestone")
  end

  # ===== MILESTONE SPECIFIC OPERATIONS =====
  
  # Objectives & Key Results
  def add_objective(milestone_id, title, description, owner:, key_results: [])
    milestone = @model_class.find(milestone_id)
    objective = milestone.add_objective(title, description, owner: owner, key_results: key_results)
    milestone.save!
    Result.success(objective)
  rescue Mongoid::Errors::DocumentNotFound
    Result.failure(:not_found)
  rescue => e
    handle_error(e, "Failed to add objective")
  end

  def update_key_result(milestone_id, objective_id, key_result_id, current_value, updated_by:)
    milestone = @model_class.find(milestone_id)
    milestone.update_key_result(objective_id, key_result_id, current_value, updated_by: updated_by)
    milestone.save!
    Result.success(true)
  rescue Mongoid::Errors::DocumentNotFound
    Result.failure(:not_found)
  rescue => e
    handle_error(e, "Failed to update key result")
  end

  # Risk Management
  def add_risk(milestone_id, title, description, severity:, probability:, raised_by:, owner: nil)
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
    Result.success(risk)
  rescue Mongoid::Errors::DocumentNotFound
    Result.failure(:not_found)
  rescue => e
    handle_error(e, "Failed to add risk")
  end

  def update_risk_mitigation(milestone_id, risk_id, mitigation_plan, owner:)
    milestone = @model_class.find(milestone_id)
    milestone.update_risk_mitigation(risk_id, mitigation_plan, owner: owner)
    milestone.save!
    Result.success(true)
  rescue Mongoid::Errors::DocumentNotFound
    Result.failure(:not_found)
  rescue => e
    handle_error(e, "Failed to update risk mitigation")
  end

  # Dependency Management
  def add_dependency(milestone_id, title, description, type:, dependent_on:, owner:, due_date: nil)
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
    Result.success(dependency)
  rescue Mongoid::Errors::DocumentNotFound
    Result.failure(:not_found)
  rescue => e
    handle_error(e, "Failed to add dependency")
  end

  # Blocker Management
  def add_blocker(milestone_id, title, description, raised_by:, severity: 'high')
    milestone = @model_class.find(milestone_id)
    blocker = milestone.add_blocker(title, description, raised_by: raised_by, severity: severity)
    milestone.save!
    Result.success(blocker)
  rescue Mongoid::Errors::DocumentNotFound
    Result.failure(:not_found)
  rescue => e
    handle_error(e, "Failed to add blocker")
  end

  def assign_blocker(milestone_id, blocker_id, assignee:)
    milestone = @model_class.find(milestone_id)
    milestone.assign_blocker(blocker_id, assignee: assignee)
    milestone.save!
    Result.success(true)
  rescue Mongoid::Errors::DocumentNotFound
    Result.failure(:not_found)
  rescue => e
    handle_error(e, "Failed to assign blocker")
  end

  def resolve_blocker(milestone_id, blocker_id, resolution)
    milestone = @model_class.find(milestone_id)
    milestone.resolve_blocker(blocker_id, resolution)
    milestone.save!
    Result.success(true)
  rescue Mongoid::Errors::DocumentNotFound
    Result.failure(:not_found)
  rescue => e
    handle_error(e, "Failed to resolve blocker")
  end

  # Progress Updates
  def update_progress(milestone_id)
    milestone = @model_class.find(milestone_id)
    milestone.update_progress
    Result.success(milestone)
  rescue Mongoid::Errors::DocumentNotFound
    Result.failure(:not_found)
  rescue => e
    handle_error(e, "Failed to update progress")
  end

  def update_sprint_counts(milestone_id)
    milestone = @model_class.find(milestone_id)
    
    # Count sprints associated with this milestone
    sprint_count = Mongodb::MongoSprintV2.where(milestone_id: milestone_id.to_s).count
    completed_sprints = Mongodb::MongoSprintV2.where(
      milestone_id: milestone_id.to_s,
      status: 'completed'
    ).count
    
    milestone.update!(
      total_sprints: sprint_count,
      completed_sprints: completed_sprints
    )
    
    Result.success(milestone)
  rescue Mongoid::Errors::DocumentNotFound
    Result.failure(:not_found)
  rescue => e
    handle_error(e, "Failed to update sprint counts")
  end

  # ===== AGGREGATIONS =====
  
  def progress_summary(organization_id)
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
    
    Result.success(summary)
  rescue => e
    handle_error(e, "Failed to get progress summary")
  end

  def risk_summary(organization_id)
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
    Result.success(results.to_a)
  rescue => e
    handle_error(e, "Failed to get risk summary")
  end

  def timeline_analysis(organization_id)
    active_milestones = @model_class.active.where(organization_id: organization_id.to_s)
    
    analysis = {
      on_track: [],
      at_risk: [],
      overdue: []
    }
    
    active_milestones.each do |milestone|
      if milestone.is_overdue?
        analysis[:overdue] << milestone_summary(milestone)
      elsif milestone.health_status == 'at_risk'
        analysis[:at_risk] << milestone_summary(milestone)
      else
        analysis[:on_track] << milestone_summary(milestone)
      end
    end
    
    Result.success(analysis)
  rescue => e
    handle_error(e, "Failed to analyze timeline")
  end

  private

  def apply_sorting(query, options)
    sort_by = options[:sort_by] || 'planned_end'
    sort_order = options[:sort_order] || 'asc'
    
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
    filtered = milestones.select { |m| m.health_status == health_status }
    filtered.map(&:id)
  end

  def milestone_summary(milestone)
    {
      id: milestone.id.to_s,
      title: milestone.title,
      progress_percentage: milestone.progress_percentage,
      days_remaining: milestone.days_remaining,
      health_status: milestone.health_status,
      owner: milestone.owner_snapshot
    }
  end

  def calculate_overall_progress(results)
    total_tasks = results.sum { |r| r["total_tasks"] }
    completed_tasks = results.sum { |r| r["completed_tasks"] }
    
    return 0 if total_tasks.zero?
    
    (completed_tasks.to_f / total_tasks * 100).round(2)
  end
end