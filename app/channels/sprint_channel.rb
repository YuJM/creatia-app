# app/channels/sprint_channel.rb
class SprintChannel < ApplicationCable::Channel
  def subscribed
    sprint = find_sprint
    stream_for sprint if sprint
  end

  def unsubscribed
    stop_all_streams
  end

  # Client actions
  def update_task_status(data)
    task = Mongodb::MongoTask.find(data['task_id'])
    
    if can_update_task?(task)
      SprintService.update_task_status(
        data['task_id'],
        data['status'],
        current_user.id
      )
    end
  end

  def add_standup_update(data)
    sprint = find_sprint
    
    if sprint && can_manage_sprint?(sprint)
      SprintService.update_daily_standup(
        sprint.id,
        {
          attendees: data['attendees'],
          updates: data['updates'],
          duration: data['duration']
        }
      )
    end
  end

  private

  def find_sprint
    sprint_id = params[:sprint_id]
    sprint = Mongodb::MongoSprint.find(sprint_id)
    
    # Verify organization access
    if sprint && sprint.organization_id == current_organization&.id
      sprint
    end
  rescue Mongoid::Errors::DocumentNotFound
    nil
  end

  def can_update_task?(task)
    # Check if user can update this task
    task.organization_id == current_organization&.id &&
      (task.assignee_id == current_user.id || 
       current_user.has_role?(:admin, current_organization))
  end

  def can_manage_sprint?(sprint)
    # Check if user can manage this sprint
    sprint.organization_id == current_organization&.id &&
      current_user.has_role?(:member, current_organization)
  end
end