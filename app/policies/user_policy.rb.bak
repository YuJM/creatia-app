class UserPolicy < ApplicationPolicy
  def show?
    user.present? # Only authenticated users can view profiles
  end
  
  def index?
    user&.admin? || user&.moderator?
  end
  
  def new?
    false # Handled by Devise registration
  end
  
  def create?
    false # Handled by Devise registration
  end
  
  def update?
    user&.admin? || user == record
  end
  
  def edit?
    update?
  end
  
  def destroy?
    user&.admin?
  end
  
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.nil?
        scope.none
      elsif user.admin? || user.moderator?
        scope.all
      else
        scope.where(id: user.id)
      end
    end
  end
  
  def permitted_attributes
    if user&.admin?
      [:email, :username, :name, :bio, :avatar_url, :role]
    else
      [:email, :username, :name, :bio, :avatar_url]
    end
  end
end