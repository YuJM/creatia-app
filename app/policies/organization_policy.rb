# frozen_string_literal: true

class OrganizationPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    member?
  end

  def create?
    user.present?
  end

  def update?
    owner?
  end

  def destroy?
    owner?
  end

  def switch?
    member?
  end

  # 조직 설정 관리
  def manage_settings?
    owner?
  end

  # 멤버 관리
  def manage_members?
    admin?
  end

  # 빌링 관리
  def manage_billing?
    owner?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # 사용자가 멤버인 조직들만 반환
      return scope.none unless user

      user.organizations.active
    end
  end
end
