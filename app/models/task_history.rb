# frozen_string_literal: true

# Task 상태 변경 및 활동 히스토리를 MongoDB에 저장
class TaskHistory
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  field :task_id, type: String     # MongoDB Task ID
  field :organization_id, type: String  # UUID from PostgreSQL
  field :service_id, type: String       # UUID from PostgreSQL
  field :user_id, type: String          # UUID from PostgreSQL User
  field :action, type: String # created, updated, status_changed, assigned, commented, etc.
  field :previous_state, type: Hash
  field :current_state, type: Hash
  field :field_changes, type: Hash # renamed from 'changes' to avoid conflict
  field :metadata, type: Hash, default: {}
  field :ip_address, type: String
  field :user_agent, type: String
  field :session_id, type: String

  # Indexes for performance
  index({ task_id: 1, created_at: -1 })
  index({ user_id: 1, created_at: -1 })
  index({ organization_id: 1, created_at: -1 })
  index({ service_id: 1, created_at: -1 })
  index({ action: 1, created_at: -1 })
  index({ session_id: 1 })
  index({ created_at: -1 })

  # TTL index - 90일 이후 자동 삭제 (선택적)
  # index({ created_at: 1 }, { expire_after_seconds: 7776000 })

  # Validations
  validates :task_id, presence: true
  validates :action, presence: true
  validates :user_id, presence: true

  # Constants
  ACTIONS = {
    created: 'created',
    updated: 'updated',
    status_changed: 'status_changed',
    assigned: 'assigned',
    unassigned: 'unassigned',
    commented: 'commented',
    attachment_added: 'attachment_added',
    attachment_removed: 'attachment_removed',
    label_added: 'label_added',
    label_removed: 'label_removed',
    milestone_changed: 'milestone_changed',
    priority_changed: 'priority_changed',
    due_date_changed: 'due_date_changed',
    estimation_changed: 'estimation_changed',
    sprint_changed: 'sprint_changed',
    archived: 'archived',
    restored: 'restored',
    deleted: 'deleted'
  }.freeze

  STATUSES = %w[todo in_progress in_review done cancelled].freeze

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_task, ->(task_id) { where(task_id: task_id) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_organization, ->(org_id) { where(organization_id: org_id) }
  scope :by_service, ->(service_id) { where(service_id: service_id) }
  scope :by_action, ->(action) { where(action: action) }
  scope :today, -> { where(created_at: { '$gte': Time.zone.now.beginning_of_day }) }
  scope :this_week, -> { where(created_at: { '$gte': Time.zone.now.beginning_of_week }) }
  scope :this_month, -> { where(created_at: { '$gte': Time.zone.now.beginning_of_month }) }

  # Class methods
  class << self
    def track_change(task, user, action, changes = {}, metadata = {})
      create!(
        task_id: task.id,
        organization_id: task.organization_id,
        service_id: task.service_id,
        user_id: user.id,
        action: action,
        previous_state: extract_previous_state(task, changes),
        current_state: extract_current_state(task),
        field_changes: normalize_changes(changes),
        metadata: metadata,
        ip_address: metadata[:ip_address],
        user_agent: metadata[:user_agent],
        session_id: metadata[:session_id]
      )
    end

    def status_change_history(task_id, limit = 10)
      by_task(task_id)
        .by_action('status_changed')
        .recent
        .limit(limit)
    end

    def user_activity(user_id, limit = 50)
      by_user(user_id)
        .recent
        .limit(limit)
    end

    def task_timeline(task_id)
      by_task(task_id)
        .recent
        .map { |h| format_timeline_entry(h) }
    end

    # 통계 및 분석 메서드
    def task_statistics(task_id)
      histories = by_task(task_id)
      
      {
        total_changes: histories.count,
        status_changes: histories.by_action('status_changed').count,
        assignments: histories.by_action('assigned').count,
        comments: histories.by_action('commented').count,
        last_updated: histories.recent.first&.created_at,
        unique_contributors: histories.distinct(:user_id).count,
        average_time_between_updates: calculate_average_time(histories)
      }
    end

    def organization_activity_summary(org_id, date_range = 1.week.ago..Time.current)
      by_organization(org_id)
        .where(created_at: date_range)
        .group_by(&:action)
        .transform_values(&:count)
    end

    private

    def extract_previous_state(task, changes)
      return {} unless changes.present?
      
      changes.transform_values { |v| v.is_a?(Array) ? v.first : nil }
    end

    def extract_current_state(task)
      {
        status: task.status,
        assignee_id: task.assignee_id,
        priority: task.priority,
        due_date: task.due_date,
        estimation: task.estimation,
        labels: task.labels,
        sprint_id: task.sprint_id
      }.compact
    end

    def normalize_changes(changes)
      return {} unless changes.present?
      
      changes.transform_values do |value|
        if value.is_a?(Array) && value.length == 2
          { from: value[0], to: value[1] }
        else
          value
        end
      end
    end

    def format_timeline_entry(history)
      {
        id: history.id.to_s,
        action: history.action,
        user_id: history.user_id,
        field_changes: history.field_changes,
        metadata: history.metadata,
        created_at: history.created_at
      }
    end

    def calculate_average_time(histories)
      return 0 if histories.count <= 1
      
      times = histories.pluck(:created_at).sort
      differences = times.each_cons(2).map { |a, b| b - a }
      
      return 0 if differences.empty?
      
      (differences.sum / differences.length).to_i
    end
  end

  # Instance methods
  def formatted_action
    action.humanize.capitalize
  end

  def changed_fields
    field_changes&.keys || []
  end

  def summary
    case action
    when 'status_changed'
      "Status changed from #{field_changes.dig('status', 'from')} to #{field_changes.dig('status', 'to')}"
    when 'assigned'
      "Assigned to user #{field_changes.dig('assignee_id', 'to')}"
    when 'priority_changed'
      "Priority changed from #{field_changes.dig('priority', 'from')} to #{field_changes.dig('priority', 'to')}"
    else
      formatted_action
    end
  end

  # 관련 PostgreSQL 모델과의 연동
  def task
    @task ||= Task.find(task_id)
  rescue Mongoid::Errors::DocumentNotFound
    nil
  end

  def user
    @user ||= User.cached_find( user_id)
  end

  def organization
    @organization ||= Organization.find_by(id: organization_id)
  end

  def service
    @service ||= Service.find_by(id: service_id)
  end
end