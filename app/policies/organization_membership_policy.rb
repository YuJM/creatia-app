# frozen_string_literal: true

class OrganizationMembershipPolicy < ApplicationPolicy
  def index?
    member?
  end

  def show?
    own_membership? || admin?
  end

  def create?
    admin?
  end

  def update?
    # 자신의 멤버십은 제한적으로 수정 가능 (예: 알림 설정)
    # 다른 사람의 멤버십은 관리자만 수정 가능
    return true if own_membership? && can_update_own_membership?
    # Owner는 다른 owner도 수정 가능
    return true if owner?
    return false if target_is_owner?
    admin?
  end

  def destroy?
    # 자신의 멤버십 탈퇴는 소유자가 아닌 경우 가능
    return true if own_membership? && !target_is_owner? && !viewer?
    # 다른 사람의 멤버십 제거는 관리자가 가능 (단, 소유자는 제거 불가)
    return false if target_is_owner?
    admin?
  end

  # 역할 변경
  def change_role?
    # 자신의 역할은 변경 불가 (ただし、ownerが他のownerのロールを変更するのは可能)
    if own_membership?
      return false
    end
    # 소유자는 다른 멤버(owner 포함)의 역할을 변경할 수 있음
    return true if owner?
    # 관리자는 소유자가 아닌 멤버의 역할 변경 가능
    return false if target_is_owner?
    admin?
  end

  # 멤버십 활성화/비활성화
  def toggle_active?
    return false if own_membership?  # 자신의 멤버십은 toggle 불가
    return false if target_is_owner?
    admin?
  end

  private

  def own_membership?
    record.user == user
  end

  def target_is_owner?
    record.role == 'owner'
  end

  def promoting_to_owner?
    # 파라미터에서 새로운 역할이 owner인지 확인
    # 실제 구현에서는 context나 params를 통해 확인
    false # 기본값
  end

  def can_update_own_membership?
    # 자신의 멤버십에서 수정 가능한 항목들 (예: 알림 설정 등)
    # 역할이나 조직 변경은 불가
    true
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user && organization

      # 관리자는 모든 멤버십을 볼 수 있음
      if user && organization && %w[owner admin].include?(organization.role_for(user))
        return scope.where(organization: organization)
      end

      # 일반 멤버는 활성화된 멤버십만 볼 수 있음
      scope.where(organization: organization, active: true)
    end
    
    private
    
    def admin?
      return false unless user && organization
      %w[owner admin].include?(organization.role_for(user))
    end
  end
end
