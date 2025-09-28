# app/services/concerns/broadcastable.rb
module Broadcastable
  extend ActiveSupport::Concern

  private

  # Sprint broadcasts
  def broadcast_sprint_status(sprint)
    SprintChannel.broadcast_to(
      sprint,
      {
        action: 'sprint_status_changed',
        sprint: sprint_summary(sprint)
      }
    )
  end

  def broadcast_sprint_update(sprint)
    SprintChannel.broadcast_to(
      sprint,
      {
        action: 'sprint_updated',
        sprint: sprint_summary(sprint)
      }
    )
  end

  def broadcast_standup_update(sprint, standup_data)
    SprintChannel.broadcast_to(
      sprint,
      {
        action: 'standup_updated',
        sprint_id: sprint.id.to_s,
        standup: standup_data
      }
    )
  end

  def broadcast_task_added(sprint, task)
    SprintChannel.broadcast_to(
      sprint,
      {
        action: 'task_added',
        sprint_id: sprint.id.to_s,
        task: task_summary(task)
      }
    )
  end

  # Task broadcasts
  def broadcast_task_created(task)
    # Broadcast to organization channel
    ActionCable.server.broadcast(
      "tasks_organization_#{task.organization_id}",
      {
        action: 'task_created',
        task: task_summary(task)
      }
    )

    # Broadcast to sprint channel if assigned
    if task.sprint_id.present?
      ActionCable.server.broadcast(
        "tasks_sprint_#{task.sprint_id}",
        {
          action: 'task_created',
          task: task_summary(task)
        }
      )
    end
  end

  def broadcast_task_updated(task, changes)
    TaskChannel.broadcast_to(
      task,
      {
        action: 'task_updated',
        task_id: task.id.to_s,
        changes: changes,
        task: task_summary(task)
      }
    )
  end

  def broadcast_task_update(task)
    broadcast_task_updated(task, {})
  end

  def broadcast_task_assigned(task, assignee_id)
    TaskChannel.broadcast_to(
      task,
      {
        action: 'task_assigned',
        task_id: task.id.to_s,
        assignee_id: assignee_id,
        assignee_name: User.cached_find(assignee_id)&.name
      }
    )

    # Notify the assignee
    ActionCable.server.broadcast(
      "activities_user_#{assignee_id}",
      {
        action: 'task_assigned_to_you',
        task: task_summary(task)
      }
    )
  end

  def broadcast_task_status_changed(task)
    TaskChannel.broadcast_to(
      task,
      {
        action: 'task_status_changed',
        task_id: task.id.to_s,
        status: task.status,
        task: task_summary(task)
      }
    )
  end

  def broadcast_comment_added(task, comment)
    TaskChannel.broadcast_to(
      task,
      {
        action: 'comment_added',
        task_id: task.id.to_s,
        comment: comment_summary(comment)
      }
    )
  end

  def broadcast_task_blocked(task)
    TaskChannel.broadcast_to(
      task,
      {
        action: 'task_blocked',
        task_id: task.id.to_s,
        blocked_reason: task.blocked_reason,
        blocked_by: task.blocked_by_task_ids
      }
    )
  end

  def broadcast_task_unblocked(task)
    TaskChannel.broadcast_to(
      task,
      {
        action: 'task_unblocked',
        task_id: task.id.to_s
      }
    )
  end

  def broadcast_bulk_update(task_ids, changes)
    task_ids.each do |task_id|
      task = Mongodb::MongoTask.find(task_id)
      broadcast_task_updated(task, changes)
    end
  end

  # Activity broadcasts
  def broadcast_activity(activity)
    # Broadcast to organization
    ActionCable.server.broadcast(
      "activities_organization_#{activity.organization_id}",
      {
        action: 'new_activity',
        activity: activity.to_timeline_event
      }
    )

    # Broadcast to team if present
    if activity.team_id.present?
      ActionCable.server.broadcast(
        "activities_team_#{activity.team_id}",
        {
          action: 'new_activity',
          activity: activity.to_timeline_event
        }
      )
    end

    # Broadcast to mentioned users
    activity.mentioned_user_ids.each do |user_id|
      ActionCable.server.broadcast(
        "activities_user_#{user_id}",
        {
          action: 'mentioned_in_activity',
          activity: activity.to_timeline_event
        }
      )
    end

    # Broadcast to target entity
    if activity.target_type && activity.target_id
      ActionCable.server.broadcast(
        "activities_#{activity.target_type}_#{activity.target_id}",
        {
          action: 'new_activity',
          activity: activity.to_timeline_event
        }
      )
    end
  end

  # Summary helpers
  def sprint_summary(sprint)
    {
      id: sprint.id.to_s,
      name: sprint.name,
      status: sprint.status,
      start_date: sprint.start_date,
      end_date: sprint.end_date,
      committed_points: sprint.committed_points,
      completed_points: sprint.completed_points,
      task_counts: sprint.task_counts,
      health_score: sprint.health_score,
      team_id: sprint.team_id
    }
  end

  def task_summary(task)
    {
      id: task.id.to_s,
      task_id: task.task_id,
      title: task.title,
      status: task.status,
      priority: task.priority,
      assignee_id: task.assignee_id,
      assignee_name: task.assignee_name,
      story_points: task.story_points,
      sprint_id: task.sprint_id,
      is_blocked: task.is_blocked,
      completion_percentage: task.completion_percentage
    }
  end

  def comment_summary(comment)
    {
      id: comment.id.to_s,
      author_id: comment.author_id,
      author_name: comment.author_name,
      content: comment.content,
      comment_type: comment.comment_type,
      created_at: comment.created_at,
      reactions: comment.reactions
    }
  end
end