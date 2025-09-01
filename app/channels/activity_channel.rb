# app/channels/activity_channel.rb
class ActivityChannel < ApplicationCable::Channel
  def subscribed
    # Subscribe to activity streams
    if params[:organization_id]
      # Organization-wide activity stream
      stream_from "activities_organization_#{params[:organization_id]}"
    elsif params[:team_id]
      # Team activity stream
      stream_from "activities_team_#{params[:team_id]}"
    elsif params[:user_id] && params[:user_id] == current_user.id.to_s
      # Personal activity stream
      stream_from "activities_user_#{current_user.id}"
    elsif params[:target_type] && params[:target_id]
      # Specific entity activity stream (e.g., task, sprint)
      stream_from "activities_#{params[:target_type]}_#{params[:target_id]}"
    end
  end

  def unsubscribed
    stop_all_streams
  end

  # Mark activities as read
  def mark_as_read(data)
    activity_ids = data['activity_ids']
    
    if activity_ids.present?
      activities = Mongodb::MongoActivity.where(
        :_id.in => activity_ids,
        organization_id: current_organization&.id
      )
      
      activities.each do |activity|
        # Track read status if needed
        # activity.mark_as_read(current_user.id)
      end
      
      # Broadcast read status update
      ActionCable.server.broadcast(
        "activities_user_#{current_user.id}",
        {
          action: 'activities_read',
          activity_ids: activity_ids,
          user_id: current_user.id
        }
      )
    end
  end

  # Filter activities
  def apply_filter(data)
    filters = data['filters'] || {}
    
    # Build query based on filters
    query = Mongodb::MongoActivity.by_organization(current_organization.id)
    
    query = query.by_actor(filters['actor_id']) if filters['actor_id']
    query = query.where(action: filters['action']) if filters['action']
    query = query.where(target_type: filters['target_type']) if filters['target_type']
    
    # Time range filters
    if filters['from_date']
      query = query.where(:created_at.gte => Date.parse(filters['from_date']))
    end
    
    if filters['to_date']
      query = query.where(:created_at.lte => Date.parse(filters['to_date']).end_of_day)
    end
    
    # Pagination
    page = (filters['page'] || 1).to_i
    per_page = (filters['per_page'] || 20).to_i
    
    activities = query
      .recent
      .skip((page - 1) * per_page)
      .limit(per_page)
    
    # Send filtered results to the client
    transmit({
      action: 'filtered_activities',
      activities: activities.map(&:to_timeline_event),
      page: page,
      total_count: query.count
    })
  end

  private

  def can_access_organization_activities?
    current_organization && 
      current_user.has_role?(:member, current_organization)
  end

  def can_access_team_activities?(team_id)
    team = Team.find_by(id: team_id)
    team && team.users.include?(current_user)
  end
end