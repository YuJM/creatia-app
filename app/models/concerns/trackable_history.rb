# frozen_string_literal: true

# Task 변경사항을 MongoDB TaskHistory에 자동으로 기록하는 concern
module TrackableHistory
  extend ActiveSupport::Concern

  included do
    # Thread-safe attribute to track current user
    attr_accessor :current_user_for_history
    
    # Callbacks
    after_create :track_creation
    after_update :track_update
    after_destroy :track_deletion
    
    # Track specific field changes
    TRACKED_FIELDS = %w[
      status assignee_id priority due_date estimation 
      sprint_id team_id title description labels
    ].freeze
  end

  private

  def track_creation
    return unless should_track_history?
    
    TaskHistory.track_change(
      self,
      current_user_for_history || default_system_user,
      'created',
      {},
      build_metadata
    )
  rescue => e
    Rails.logger.error "Failed to track task creation: #{e.message}"
  end

  def track_update
    return unless should_track_history?
    return if saved_changes.keys == ['updated_at'] # Skip if only timestamp changed
    
    tracked_changes = extract_tracked_changes
    return if tracked_changes.empty?
    
    # Track main update
    TaskHistory.track_change(
      self,
      current_user_for_history || default_system_user,
      determine_action(tracked_changes),
      tracked_changes,
      build_metadata
    )
    
    # Track specific actions
    track_specific_actions(tracked_changes)
  rescue => e
    Rails.logger.error "Failed to track task update: #{e.message}"
  end

  def track_deletion
    return unless should_track_history?
    
    TaskHistory.track_change(
      self,
      current_user_for_history || default_system_user,
      'deleted',
      {},
      build_metadata.merge(deleted_data: attributes)
    )
  rescue => e
    Rails.logger.error "Failed to track task deletion: #{e.message}"
  end

  def track_specific_actions(changes)
    # Track status change
    if changes['status'].present?
      action = case changes['status'][1]
               when 'done' then 'completed'
               when 'archived' then 'archived'
               when 'in_progress' then 'started'
               else 'status_changed'
               end
      
      TaskHistory.track_change(
        self,
        current_user_for_history || default_system_user,
        action,
        { status: changes['status'] },
        build_metadata
      )
    end
    
    # Track assignment change
    if changes['assignee_id'].present?
      action = changes['assignee_id'][1].nil? ? 'unassigned' : 'assigned'
      
      TaskHistory.track_change(
        self,
        current_user_for_history || default_system_user,
        action,
        { assignee_id: changes['assignee_id'] },
        build_metadata
      )
    end
    
    # Track priority change
    if changes['priority'].present?
      TaskHistory.track_change(
        self,
        current_user_for_history || default_system_user,
        'priority_changed',
        { priority: changes['priority'] },
        build_metadata
      )
    end
    
    # Track due date change
    if changes['due_date'].present?
      TaskHistory.track_change(
        self,
        current_user_for_history || default_system_user,
        'due_date_changed',
        { due_date: changes['due_date'] },
        build_metadata
      )
    end
    
    # Track sprint change
    if changes['sprint_id'].present?
      TaskHistory.track_change(
        self,
        current_user_for_history || default_system_user,
        'sprint_changed',
        { sprint_id: changes['sprint_id'] },
        build_metadata
      )
    end
  end

  def extract_tracked_changes
    saved_changes.slice(*TRACKED_FIELDS).reject { |_, v| v[0] == v[1] }
  end

  def determine_action(changes)
    return 'status_changed' if changes['status'].present?
    return 'assigned' if changes['assignee_id'].present?
    return 'priority_changed' if changes['priority'].present?
    'updated'
  end

  def should_track_history?
    # MongoDB가 설정되어 있고 TaskHistory 모델이 존재하는지 확인
    defined?(TaskHistory) && Mongoid.configured?
  end

  def build_metadata
    metadata = {
      timestamp: Time.current,
      source: 'rails_app'
    }
    
    # Request context가 있으면 추가
    if defined?(RequestStore) && RequestStore.store[:current_request].present?
      request = RequestStore.store[:current_request]
      metadata.merge!(
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        session_id: request.session.id
      )
    end
    
    metadata
  end

  def default_system_user
    # System user를 나타내는 특별한 user 객체
    # 실제 구현에서는 system user를 생성하거나 가져와야 함
    OpenStruct.new(id: 0, name: 'System')
  end

  module ClassMethods
    # 벌크 업데이트 시 히스토리 추적
    def bulk_update_with_history(tasks, attributes, user)
      tasks.each do |task|
        task.current_user_for_history = user
        task.update(attributes)
      end
    end
    
    # 히스토리 추적 없이 업데이트 (마이그레이션 등에 사용)
    def update_without_history(attributes)
      skip_callback :update, :after, :track_update
      update(attributes)
    ensure
      set_callback :update, :after, :track_update
    end
  end
end