# frozen_string_literal: true

class TaskPolicy < ApplicationPolicy
  def index?
    return false if viewer?
    organization_member?
  end
  
  def show?
    return false unless organization_member?
    return true if organization_admin?
    assigned_to_user? || team_member? || task_owner?
  end
  
  def update?
    return false if viewer?
    assigned_to_user? || task_owner? || organization_admin?
  end
  
  def complete?
    return false if viewer?
    assigned_to_user? || task_owner?
  end
  
  def start_pomodoro?
    return false if viewer?
    assigned_to_user?
  end
  
  def destroy?
    task_owner? || organization_admin?
  end
  
  def assign?
    organization_admin? || team_lead? || task_owner?
  end
  
  
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user && organization
      
      if organization_admin?
        # Admin은 모든 Task 조회 가능
        scope.joins(:service).where(services: { organization_id: organization.id })
      elsif organization.role_for(user)
        # 일반 사용자는 자신이 할당받았거나 팀 내 Task만 조회
        team_ids = user.team_ids.presence || [-1]  # -1은 절대 매칭되지 않는 값
        scope.joins(:service)
             .where(services: { organization_id: organization.id })
             .where('tasks.assignee_id = ? OR tasks.team_id IN (?)', 
                    user.id, 
                    team_ids)
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
    return false unless user
    record.assignee_id == user.id
  end
  
  def task_owner?
    return false unless user && record
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