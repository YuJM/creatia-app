# frozen_string_literal: true

require 'dry-monads'

# Sprint Repository - MongoDB Sprint 데이터 접근 계층
class SprintRepository < BaseRepository
  include Dry::Monads[:result]
  
  def initialize
    super
    @model_class = Mongodb::MongoSprintV2
  end
  
  private
  
  def handle_error(error, message)
    Rails.logger.error "[SprintRepository] #{message}: #{error.message}"
    Rails.logger.error error.backtrace.first(5).join("\n")
    Failure([:database_error, message])
  end
  
  def format_validation_errors(error)
    [:validation_error, error.record.errors.to_h]
  end
  
  # paginate 메서드는 BaseRepository에서 상속받아 사용
  
  public

  # ===== CREATE =====
  def create(attributes)
    sprint = @model_class.new(attributes)
    
    # User snapshots 설정
    if attributes[:created_by]
      sprint.set_created_by(attributes[:created_by])
    end
    
    if attributes[:sprint_owner]
      sprint.set_sprint_owner(attributes[:sprint_owner])
    end
    
    if attributes[:scrum_master]
      sprint.set_scrum_master(attributes[:scrum_master])
    end
    
    if attributes[:team_members].present?
      attributes[:team_members].each do |member_data|
        sprint.add_team_member(
          member_data[:user],
          role: member_data[:role],
          capacity_hours: member_data[:capacity_hours]
        )
      end
    end
    
    sprint.save!
    Success(sprint)
  rescue Mongoid::Errors::Validations => e
    Failure(format_validation_errors(e))
  rescue => e
    handle_error(e, "Failed to create sprint")
  end

  # ===== READ =====
  def find(id)
    sprint = @model_class.find(id)
    Success(sprint)
  rescue Mongoid::Errors::DocumentNotFound
    Failure(:not_found)
  rescue => e
    handle_error(e, "Failed to find sprint")
  end

  def find_by_organization(organization_id, options = {})
    query = @model_class.where(organization_id: organization_id.to_s)
    
    # Status filter
    query = query.where(status: options[:status]) if options[:status]
    
    # Date range filter
    if options[:start_date] && options[:end_date]
      query = query.where(
        :start_date.lte => options[:end_date],
        :end_date.gte => options[:start_date]
      )
    end
    
    # Team filter
    query = query.where(team_id: options[:team_id].to_s) if options[:team_id]
    
    # Sprint owner filter
    if options[:sprint_owner_id]
      query = query.where("sprint_owner_snapshot.user_id" => options[:sprint_owner_id].to_s)
    end
    
    # Sorting
    query = apply_sorting(query, options)
    
    # Pagination
    result = paginate(query, options)
    
    Success(result)
  rescue => e
    handle_error(e, "Failed to find sprints by organization")
  end

  def find_current(organization_id, team_id = nil)
    query = @model_class.current.where(organization_id: organization_id.to_s)
    query = query.where(team_id: team_id.to_s) if team_id
    
    sprint = query.first
    
    if sprint
      Success(sprint)
    else
      Failure(:not_found)
    end
  rescue => e
    handle_error(e, "Failed to find current sprint")
  end

  def find_by_milestone(milestone_id)
    sprints = @model_class.where(milestone_id: milestone_id.to_s)
                          .order(sprint_number: :asc)
    
    Success(sprints)
  rescue => e
    handle_error(e, "Failed to find sprints by milestone")
  end

  # ===== UPDATE =====
  def update(id, attributes)
    sprint = @model_class.find(id)
    
    # Handle user snapshot updates
    if attributes[:sprint_owner]
      sprint.set_sprint_owner(attributes.delete(:sprint_owner))
    end
    
    if attributes[:scrum_master]
      sprint.set_scrum_master(attributes.delete(:scrum_master))
    end
    
    # Handle team member updates
    if attributes.key?(:team_members)
      team_members = attributes.delete(:team_members)
      
      # Clear existing and add new
      sprint.team_member_snapshots = []
      team_members.each do |member_data|
        sprint.add_team_member(
          member_data[:user],
          role: member_data[:role],
          capacity_hours: member_data[:capacity_hours]
        )
      end
    end
    
    sprint.update!(attributes)
    Success(sprint)
  rescue Mongoid::Errors::DocumentNotFound
    Failure(:not_found)
  rescue Mongoid::Errors::Validations => e
    Failure(format_validation_errors(e))
  rescue => e
    handle_error(e, "Failed to update sprint")
  end

  # ===== DELETE =====
  def delete(id)
    sprint = @model_class.find(id)
    
    # Archive instead of hard delete
    sprint.update!(
      status: 'cancelled',
      archived_at: DateTime.current
    )
    
    Success(true)
  rescue Mongoid::Errors::DocumentNotFound
    Failure(:not_found)
  rescue => e
    handle_error(e, "Failed to delete sprint")
  end

  # ===== SPRINT SPECIFIC OPERATIONS =====
  
  def add_task_to_sprint(sprint_id, task)
    sprint = @model_class.find(sprint_id)
    sprint.add_task(task)
    Success(sprint)
  rescue Mongoid::Errors::DocumentNotFound
    Failure(:not_found)
  rescue => e
    handle_error(e, "Failed to add task to sprint")
  end

  def remove_task_from_sprint(sprint_id, task)
    sprint = @model_class.find(sprint_id)
    sprint.remove_task(task)
    Success(sprint)
  rescue Mongoid::Errors::DocumentNotFound
    Failure(:not_found)
  rescue => e
    handle_error(e, "Failed to remove task from sprint")
  end

  def add_blocker(sprint_id, description, raised_by:, assigned_to: nil)
    sprint = @model_class.find(sprint_id)
    blocker = sprint.add_blocker(description, raised_by: raised_by, assigned_to: assigned_to)
    sprint.save!
    Success(blocker)
  rescue Mongoid::Errors::DocumentNotFound
    Failure(:not_found)
  rescue => e
    handle_error(e, "Failed to add blocker")
  end

  def resolve_blocker(sprint_id, blocker_id, resolution, resolved_by:)
    sprint = @model_class.find(sprint_id)
    sprint.resolve_blocker(blocker_id, resolution, resolved_by: resolved_by)
    sprint.save!
    Success(true)
  rescue Mongoid::Errors::DocumentNotFound
    Failure(:not_found)
  rescue => e
    handle_error(e, "Failed to resolve blocker")
  end

  def add_scope_change(sprint_id, description, requested_by:, impact:)
    sprint = @model_class.find(sprint_id)
    change = sprint.add_scope_change(description, requested_by: requested_by, impact: impact)
    sprint.save!
    Success(change)
  rescue Mongoid::Errors::DocumentNotFound
    Failure(:not_found)
  rescue => e
    handle_error(e, "Failed to add scope change")
  end

  def approve_scope_change(sprint_id, change_id, approved_by:)
    sprint = @model_class.find(sprint_id)
    sprint.approve_scope_change(change_id, approved_by: approved_by)
    sprint.save!
    Success(true)
  rescue Mongoid::Errors::DocumentNotFound
    Failure(:not_found)
  rescue => e
    handle_error(e, "Failed to approve scope change")
  end

  def record_standup(sprint_id, date:, attendees:, notes: nil, blockers: [], recorded_by:)
    sprint = @model_class.find(sprint_id)
    sprint.record_standup(date, attendees, notes: notes, blockers: blockers, recorded_by: recorded_by)
    sprint.save!
    Success(true)
  rescue Mongoid::Errors::DocumentNotFound
    Failure(:not_found)
  rescue => e
    handle_error(e, "Failed to record standup")
  end

  def update_planning_session(sprint_id, session_data)
    sprint = @model_class.find(sprint_id)
    sprint.set_planning_session(
      date: session_data[:date],
      duration_minutes: session_data[:duration_minutes],
      attendees: session_data[:attendees],
      facilitator: session_data[:facilitator],
      notes: session_data[:notes],
      decisions: session_data[:decisions]
    )
    sprint.save!
    Success(true)
  rescue Mongoid::Errors::DocumentNotFound
    Failure(:not_found)
  rescue => e
    handle_error(e, "Failed to update planning session")
  end

  def calculate_health_score(sprint_id)
    sprint = @model_class.find(sprint_id)
    score = sprint.calculate_health_score
    sprint.save!
    Success(score)
  rescue Mongoid::Errors::DocumentNotFound
    Failure(:not_found)
  rescue => e
    handle_error(e, "Failed to calculate health score")
  end

  def update_task_counts(sprint_id)
    sprint = @model_class.find(sprint_id)
    sprint.update_task_counts
    Success(sprint)
  rescue Mongoid::Errors::DocumentNotFound
    Failure(:not_found)
  rescue => e
    handle_error(e, "Failed to update task counts")
  end

  # ===== AGGREGATIONS =====
  
  def velocity_metrics(organization_id, team_id: nil, limit: 5)
    pipeline = [
      { "$match" => { 
        organization_id: organization_id.to_s,
        status: "completed"
      }},
      { "$sort" => { end_date: -1 }},
      { "$limit" => limit }
    ]
    
    pipeline[0]["$match"]["team_id"] = team_id.to_s if team_id
    
    pipeline << {
      "$group" => {
        _id: nil,
        avg_velocity: { "$avg" => "$actual_velocity" },
        max_velocity: { "$max" => "$actual_velocity" },
        min_velocity: { "$min" => "$actual_velocity" },
        avg_completed_points: { "$avg" => "$completed_points" },
        total_sprints: { "$sum" => 1 }
      }
    }
    
    result = @model_class.collection.aggregate(pipeline).first
    Success(result || {})
  rescue => e
    handle_error(e, "Failed to calculate velocity metrics")
  end

  def burndown_data(sprint_id)
    sprint = @model_class.find(sprint_id)
    
    data = {
      sprint_id: sprint.id.to_s,
      start_date: sprint.start_date,
      end_date: sprint.end_date,
      total_points: sprint.committed_points,
      burndown_points: sprint.burndown_data,
      ideal_burndown: calculate_ideal_burndown(sprint)
    }
    
    Success(data)
  rescue Mongoid::Errors::DocumentNotFound
    Failure(:not_found)
  rescue => e
    handle_error(e, "Failed to get burndown data")
  end

  private

  def apply_sorting(query, options)
    sort_by = options[:sort_by] || 'start_date'
    sort_order = options[:sort_order] || 'desc'
    
    case sort_by
    when 'start_date'
      query.order(start_date: sort_order)
    when 'end_date'
      query.order(end_date: sort_order)
    when 'sprint_number'
      query.order(sprint_number: sort_order)
    when 'health_score'
      query.order(health_score: sort_order)
    else
      query.order(created_at: :desc)
    end
  end

  def calculate_ideal_burndown(sprint)
    return [] unless sprint.start_date && sprint.end_date && sprint.committed_points
    
    total_days = (sprint.end_date - sprint.start_date).to_i + 1
    daily_burn_rate = sprint.committed_points.to_f / total_days
    
    (0..total_days).map do |day|
      {
        day: day,
        date: sprint.start_date + day.days,
        remaining_points: sprint.committed_points - (daily_burn_rate * day)
      }
    end
  end
end