# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record, :organization
  
  def initialize(user, record)
    @user = user
    @record = record
    @organization = ActsAsTenant.current_tenant
  end
  
  def index?
    organization_member?
  end
  
  def show?
    organization_member?
  end
  
  def create?
    organization_member? && !viewer?
  end
  
  def new?
    create?
  end
  
  def update?
    organization_member? && !viewer?
  end
  
  def edit?
    update?
  end
  
  def destroy?
    organization_admin?
  end
  
  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
      @organization = ActsAsTenant.current_tenant
    end
    
    def resolve
      if @organization
        @scope.where(organization: @organization)
      else
        @scope.none
      end
    end
    
    private
    
    attr_reader :user, :scope, :organization
  end
  
  private
  
  def organization_member?
    return false unless user && organization
    organization.member?(user)
  end
  
  def organization_admin?
    return false unless organization_member?
    %w[owner admin].include?(organization.role_for(user))
  end
  
  def organization_owner?
    return false unless organization_member?
    organization.role_for(user) == 'owner'
  end
  
  def viewer?
    organization.role_for(user) == 'viewer'
  end
  
  def member?
    return false unless organization_member?
    %w[owner admin member contributor viewer].include?(organization.role_for(user))
  end
  
  def owner?
    organization_owner?
  end
  
  def admin?
    organization_admin?
  end
end