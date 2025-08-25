# frozen_string_literal: true

class TaskPolicy < ApplicationPolicy
  def index?
    member?
  end

  def show?
    member?
  end

  def create?
    member?
  end

  def update?
    assigned_to_me? || admin?
  end

  def destroy?
    admin?
  end

  # 할당 관련 권한
  def assign?
    admin?
  end

  def unassign?
    assigned_to_me? || admin?
  end

  # 상태 변경 권한
  def change_status?
    assigned_to_me? || admin?
  end

  # 우선순위 변경 권한
  def change_priority?
    admin?
  end

  # 위치 변경 권한 (칸반 보드 드래그 앤 드롭)
  def reorder?
    member?
  end

  private

  def assigned_to_me?
    return false unless record.assigned_user
    record.assigned_user == user
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user && organization

      # 멤버는 모든 태스크를 볼 수 있음
      # 추후 프로젝트별, 팀별 제한 가능
      if member?
        scope.includes(:assigned_user, :organization)
      else
        scope.none
      end
    end
  end
end
