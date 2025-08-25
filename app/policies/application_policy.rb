# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record, :organization

  def initialize(user, record)
    @user = user
    @record = record
    @organization = current_organization
  end

  def index?
    member?
  end

  def show?
    member?
  end

  def create?
    member?
  end

  def new?
    create?
  end

  def update?
    admin?
  end

  def edit?
    update?
  end

  def destroy?
    admin?
  end

  private

  def current_organization
    # acts_as_tenant로 설정된 현재 조직 가져오기
    ActsAsTenant.current_tenant
  end

  def membership
    @membership ||= user&.organization_memberships&.find_by(
      organization: organization,
      active: true
    )
  end

  def member?
    return false unless user && organization
    membership.present?
  end

  def admin?
    return false unless user && organization
    membership&.role&.in?(%w[owner admin])
  end

  def owner?
    return false unless user && organization
    membership&.role == 'owner'
  end

  def viewer?
    return false unless user && organization
    membership&.role == 'viewer'
  end

  def can_manage_members?
    admin?
  end

  def can_manage_organization?
    owner?
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
      @organization = ActsAsTenant.current_tenant
    end

    def resolve
      return scope.none unless user && organization
      return scope.none unless member?
      
      # 기본적으로 현재 조직의 모든 레코드 반환
      # 각 모델별 Policy에서 오버라이드 가능
      scope.all
    end

    private

    attr_reader :user, :scope, :organization

    def membership
      @membership ||= user.organization_memberships.find_by(
        organization: organization,
        active: true
      )
    end

    def member?
      membership.present?
    end

    def admin?
      membership&.role&.in?(%w[owner admin])
    end

    def owner?
      membership&.role == 'owner'
    end
  end
end
