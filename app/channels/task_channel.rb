# app/channels/task_channel.rb
class TaskChannel < ApplicationCable::Channel
  def subscribed
    # Subscribe to a specific task or all tasks in an organization
    if params[:task_id]
      task = find_task
      stream_for task if task
    elsif params[:organization_id]
      stream_from "tasks_organization_#{params[:organization_id]}"
    elsif params[:sprint_id]
      stream_from "tasks_sprint_#{params[:sprint_id]}"
    end
  end

  def unsubscribed
    stop_all_streams
  end

  # Client actions
  def update_status(data)
    task = find_task_by_id(data['task_id'])
    
    if task && can_update_task?(task)
      TaskService.update_status(
        data['task_id'],
        data['status'],
        current_user.id
      )
    end
  end

  def assign_task(data)
    task = find_task_by_id(data['task_id'])
    
    if task && can_assign_task?(task)
      TaskService.assign_task(
        data['task_id'],
        data['assignee_id']
      )
    end
  end

  def add_comment(data)
    task = find_task_by_id(data['task_id'])
    
    if task && can_comment_on_task?(task)
      TaskService.add_comment(
        data['task_id'],
        {
          author_id: current_user.id,
          content: data['content'],
          type: data['comment_type'] || 'general'
        }
      )
    end
  end

  def update_subtask(data)
    task = find_task_by_id(data['task_id'])
    
    if task && can_update_task?(task)
      if data['action'] == 'complete'
        TaskService.complete_subtask(
          data['task_id'],
          data['subtask_id']
        )
      elsif data['action'] == 'add'
        TaskService.add_subtask(
          data['task_id'],
          {
            title: data['title'],
            assignee_id: data['assignee_id']
          }
        )
      end
    end
  end

  def block_task(data)
    task = find_task_by_id(data['task_id'])
    
    if task && can_update_task?(task)
      TaskService.block_task(
        data['task_id'],
        data['reason'],
        data['blocking_task_ids'] || []
      )
    end
  end

  def unblock_task(data)
    task = find_task_by_id(data['task_id'])
    
    if task && can_update_task?(task)
      TaskService.unblock_task(data['task_id'])
    end
  end

  private

  def find_task
    task_id = params[:task_id]
    find_task_by_id(task_id)
  end

  def find_task_by_id(task_id)
    task = Mongodb::MongoTask.find(task_id)
    
    # Verify organization access
    if task && task.organization_id == current_organization&.id
      task
    end
  rescue Mongoid::Errors::DocumentNotFound
    nil
  end

  def can_update_task?(task)
    task.organization_id == current_organization&.id &&
      (task.assignee_id == current_user.id || 
       task.participants.include?(current_user.id) ||
       current_user.has_role?(:admin, current_organization))
  end

  def can_assign_task?(task)
    task.organization_id == current_organization&.id &&
      current_user.has_role?(:member, current_organization)
  end

  def can_comment_on_task?(task)
    task.organization_id == current_organization&.id &&
      current_user.has_role?(:member, current_organization)
  end
end