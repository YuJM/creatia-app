# frozen_string_literal: true

require_relative 'base_repository'

# Task 도메인 Repository
class TaskRepository < BaseRepository
  def find_by_organization(organization_id, filters = {})
    filters[:organization_id] = organization_id
    all(filters)
  end

  def find_by_sprint(sprint_id, filters = {})
    filters[:sprint_id] = sprint_id
    all(filters)
  end

  def find_by_assignee(assignee_id, filters = {})
    filters[:assignee_id] = assignee_id
    all(filters)
  end

  def find_overdue(organization_id)
    filters = {
      organization_id: organization_id,
      due_date: { '$lt' => Date.current },
      status: { '$ne' => 'done' }
    }
    all(filters)
  end

  def find_due_soon(organization_id, days = 7)
    filters = {
      organization_id: organization_id,
      due_date: { '$gte' => Date.current, '$lte' => days.days.from_now.to_date },
      status: { '$ne' => 'done' }
    }
    all(filters)
  end

  def status_statistics(organization_id)
    Try do
      model_class.where(organization_id: organization_id)
                 .group(:status)
                 .count
    end.to_result
  rescue StandardError => e
    Failure([:database_error, e.message])
  end

  def priority_statistics(organization_id)
    Try do
      model_class.where(organization_id: organization_id)
                 .group(:priority)
                 .count
    end.to_result
  rescue StandardError => e
    Failure([:database_error, e.message])
  end

  def bulk_update_status(task_ids, new_status, organization_id)
    Try do
      tasks = model_class.where(
        id: task_ids,
        organization_id: organization_id
      )
      
      tasks.update_all(
        status: new_status,
        updated_at: Time.current
      )
      
      tasks.to_a
    end.to_result
  rescue StandardError => e
    Failure([:database_error, e.message])
  end

  def reorder(task_id, new_position, status = nil)
    find(task_id).bind do |task|
      Try do
        updates = { position: new_position }
        updates[:status] = status if status
        
        task.update!(updates)
        task
      end.to_result
    end
  rescue StandardError => e
    Failure([:database_error, e.message])
  end

  protected

  def model_class
    Task
  end
end