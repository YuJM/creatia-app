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
    # Owner는 다른 owner를 수정할 수 없음
    return false if target_is_owner? && !own_membership?
    # 관리자나 소유자만 수정 가능
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
    # 자신의 역할은 변경 불가
    return false if own_membership?
    # Owner도 다른 owner의 역할은 변경 불가
    return false if target_is_owner?
    # 소유자나 관리자만 다른 멤버의 역할 변경 가능
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
  
  def changing_owner_role?
    # Owner의 역할을 변경하려는지 확인
    target_is_owner? && record.respond_to?(:role_was) && record.role_was == 'owner'
  end

  def can_update_own_membership?
    # 자신의 멤버십에서 수정 가능한 항목들 (예: 알림 설정 등)
    # 역할이나 조직 변경은 불가
    true
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user
      return scope.none unless organization

      # 관리자는 모든 멤버십을 볼 수 있음
      if %w[owner admin].include?(organization.role_for(user))
        return scope.where(organization: organization)
      end

      # 일반 멤버는 활성화된 멤버십만 볼 수 있음
      if organization.role_for(user)
        return scope.where(organization: organization, active: true)
      end
      
      # 멤버가 아닌 경우 아무것도 볼 수 없음
      scope.none
    end
    
    private
    
    def admin?
      return false unless user && organization
      %w[owner admin].include?(organization.role_for(user))
    end
  end
end
