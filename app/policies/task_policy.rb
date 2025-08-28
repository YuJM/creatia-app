# frozen_string_literal: true

class TaskPolicy < ApplicationPolicy
  def show?
    organization_member? && (assigned_to_user? || team_member?)
  end
  
  def update?
    return false if viewer?
    assigned_to_user? || task_owner? || organization_admin?
  end
  
  def destroy?
    task_owner? || organization_admin?
  end
  
  def assign?
    organization_admin? || team_lead? || task_owner?
  end
  
  def complete?
    assigned_to_user? || task_owner?
  end
  
  def start_pomodoro?
    assigned_to_user?
  end
  
  class Scope < ApplicationPolicy::Scope
    def resolve
      if organization_admin?
        # Admin은 모든 Task 조회 가능
        scope.joins(:service).where(services: { organization_id: organization.id })
      elsif user
        # 일반 사용자는 자신이 할당받았거나 팀 내 Task만 조회
        scope.joins(:service)
             .where(services: { organization_id: organization.id })
             .where('tasks.assignee_id = ? OR tasks.team_id IN (?)', 
                    user.id, 
                    user.team_ids)
      else
        scope.none
      end
    end
    
    private
    
    def organization_admin?
      return false unless user && organization
      %w[owner admin].include?(organization.role_for(user))
    end
  end
  
  private
  
  def assigned_to_user?
    record.assignee_id == user.id
  end
  
  def task_owner?
    record.created_by_id == user.id
  end
  
  def team_member?
    return false unless record.team_id
    user.team_ids.include?(record.team_id)
  end
  
  def team_lead?
    return false unless record.team_id
    team = Team.find(record.team_id)
    team.lead_id == user.id
  end
end