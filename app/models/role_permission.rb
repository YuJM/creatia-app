class RolePermission < ApplicationRecord
  # Associations
  belongs_to :role
  belongs_to :permission
  
  # Validations
  validates :role_id, uniqueness: { scope: :permission_id }
  
  # Scopes
  scope :with_conditions, -> { where.not(conditions: {}) }
  scope :with_scope, -> { where.not(scope: {}) }
  scope :unconditional, -> { where(conditions: {}, scope: {}) }
  
  # Instance methods
  def has_condition?(key)
    conditions[key.to_s].present?
  end
  
  def condition_value(key)
    conditions[key.to_s]
  end
  
  def applies_to?(context = {})
    # 조건 확인
    return false unless check_conditions(context)
    
    # 범위 확인
    return false unless check_scope(context)
    
    true
  end
  
  def own_only?
    conditions['own_only'] == true
  end
  
  def team_only?
    conditions['team_only'] == true
  end
  
  def service_restricted?
    scope['service_ids'].present?
  end
  
  def allowed_service_ids
    scope['service_ids'] || []
  end
  
  def display_conditions
    return '제한 없음' if conditions.blank? && scope.blank?
    
    parts = []
    parts << '본인 것만' if own_only?
    parts << '팀 내에서만' if team_only?
    parts << "특정 서비스만 (#{allowed_service_ids.size}개)" if service_restricted?
    
    parts.join(', ')
  end
  
  private
  
  def check_conditions(context)
    return true if conditions.blank?
    
    # own_only 조건 확인
    if conditions['own_only'] && context[:target]
      return false unless owns_target?(context[:user], context[:target])
    end
    
    # team_only 조건 확인
    if conditions['team_only'] && context[:target]
      return false unless in_same_team?(context[:user], context[:target])
    end
    
    # time_restricted 조건 확인
    if conditions['time_restricted']
      return false unless within_allowed_time?(conditions['allowed_hours'])
    end
    
    true
  end
  
  def check_scope(context)
    return true if scope.blank?
    
    # service_ids 범위 확인
    if scope['service_ids'].present? && context[:service]
      return false unless scope['service_ids'].include?(context[:service].id.to_s)
    end
    
    # team_ids 범위 확인
    if scope['team_ids'].present? && context[:team]
      return false unless scope['team_ids'].include?(context[:team].id.to_s)
    end
    
    true
  end
  
  def owns_target?(user, target)
    case target
    when Task
      target.assignee_id == user.id || target.created_by_id == user.id
    when PomodoroSession
      target.user_id == user.id
    else
      target.respond_to?(:user_id) && target.user_id == user.id
    end
  end
  
  def in_same_team?(user, target)
    return false unless target.respond_to?(:team_id)
    
    user_team_ids = user.team_members.pluck(:team_id)
    user_team_ids.include?(target.team_id)
  end
  
  def within_allowed_time?(allowed_hours)
    return true if allowed_hours.blank?
    
    current_hour = Time.current.hour
    start_hour = allowed_hours['start'] || 0
    end_hour = allowed_hours['end'] || 24
    
    current_hour >= start_hour && current_hour < end_hour
  end
end