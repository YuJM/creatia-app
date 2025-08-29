# frozen_string_literal: true

# 사용자 액션 및 행동 패턴을 MongoDB에 저장
class UserActionLog
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  field :user_id, type: Integer
  field :organization_id, type: Integer
  field :action_type, type: String # view, click, edit, delete, create, search, filter, export
  field :resource_type, type: String # Task, Sprint, Service, Dashboard, Report, etc.
  field :resource_id, type: Integer
  field :resource_name, type: String
  field :session_id, type: String
  field :ip_address, type: String
  field :user_agent, type: String
  field :referrer, type: String
  field :request_method, type: String
  field :request_path, type: String
  field :request_params, type: Hash, default: {}
  field :response_status, type: Integer
  field :duration_ms, type: Integer # 액션 수행 시간 (밀리초)
  field :metadata, type: Hash, default: {}
  field :device_info, type: Hash, default: {}
  field :location_info, type: Hash, default: {}

  # Indexes for performance
  index({ user_id: 1, created_at: -1 })
  index({ organization_id: 1, created_at: -1 })
  index({ session_id: 1, created_at: -1 })
  index({ action_type: 1, created_at: -1 })
  index({ resource_type: 1, resource_id: 1 })
  index({ created_at: -1 })
  index({ ip_address: 1 })

  # TTL index - 30일 이후 자동 삭제 (선택적)
  # index({ created_at: 1 }, { expire_after_seconds: 2592000 })

  # Validations
  validates :user_id, presence: true
  validates :action_type, presence: true
  validates :resource_type, presence: true

  # Constants
  ACTION_TYPES = {
    # 조회 액션
    view: 'view',
    preview: 'preview',
    
    # 상호작용 액션
    click: 'click',
    hover: 'hover',
    scroll: 'scroll',
    
    # CRUD 액션
    create: 'create',
    edit: 'edit',
    update: 'update',
    delete: 'delete',
    archive: 'archive',
    restore: 'restore',
    
    # 검색 및 필터
    search: 'search',
    filter: 'filter',
    sort: 'sort',
    
    # 파일 작업
    upload: 'upload',
    download: 'download',
    export: 'export',
    import: 'import',
    
    # 협업
    share: 'share',
    comment: 'comment',
    mention: 'mention',
    assign: 'assign',
    
    # 시스템
    login: 'login',
    logout: 'logout',
    session_start: 'session_start',
    session_end: 'session_end'
  }.freeze

  RESOURCE_TYPES = %w[
    Task Sprint Service Organization Team User
    Dashboard Report PomodoroSession
    File Comment Notification Setting
  ].freeze

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_organization, ->(org_id) { where(organization_id: org_id) }
  scope :by_session, ->(session_id) { where(session_id: session_id) }
  scope :by_action, ->(action_type) { where(action_type: action_type) }
  scope :by_resource, ->(type, id = nil) { 
    query = where(resource_type: type)
    query = query.where(resource_id: id) if id
    query
  }
  scope :today, -> { where(created_at: { '$gte': Time.zone.now.beginning_of_day }) }
  scope :this_week, -> { where(created_at: { '$gte': Time.zone.now.beginning_of_week }) }
  scope :this_month, -> { where(created_at: { '$gte': Time.zone.now.beginning_of_month }) }
  scope :date_range, ->(start_date, end_date) { 
    where(created_at: { '$gte': start_date, '$lte': end_date }) 
  }

  # Class methods
  class << self
    def track(user, action_type, resource, request = nil, metadata = {})
      log_data = {
        user_id: user.id,
        organization_id: user.current_organization_id,
        action_type: action_type,
        resource_type: resource.class.name,
        resource_id: resource.try(:id),
        resource_name: resource.try(:name) || resource.try(:title),
        metadata: metadata
      }

      if request.present?
        log_data.merge!(
          session_id: request.session.id,
          ip_address: request.remote_ip,
          user_agent: request.user_agent,
          referrer: request.referrer,
          request_method: request.request_method,
          request_path: request.path,
          request_params: sanitize_params(request.params),
          device_info: extract_device_info(request.user_agent)
        )
      end

      create!(log_data)
    end

    # 사용자 행동 패턴 분석
    def user_behavior_pattern(user_id, days = 7)
      start_date = days.days.ago
      logs = by_user(user_id).date_range(start_date, Time.current)

      {
        total_actions: logs.count,
        unique_sessions: logs.distinct(:session_id).count,
        most_used_features: logs.group_by(&:resource_type)
                                 .transform_values(&:count)
                                 .sort_by { |_, v| -v }
                                 .first(5),
        action_distribution: logs.group_by(&:action_type)
                                 .transform_values(&:count),
        peak_hours: calculate_peak_hours(logs),
        average_session_duration: calculate_session_duration(logs),
        daily_activity: daily_activity_chart(logs)
      }
    end

    # 리소스 사용 통계
    def resource_usage_stats(resource_type, resource_id = nil)
      query = by_resource(resource_type, resource_id)
      
      {
        total_views: query.by_action('view').count,
        unique_viewers: query.by_action('view').distinct(:user_id).count,
        total_edits: query.by_action('edit').count,
        unique_editors: query.by_action('edit').distinct(:user_id).count,
        last_accessed: query.recent.first&.created_at,
        access_trend: access_trend_data(query),
        top_users: top_users_for_resource(query)
      }
    end

    # 조직 전체 활동 히트맵
    def organization_activity_heatmap(org_id)
      logs = by_organization(org_id).this_week
      
      heatmap_data = {}
      7.times do |day|
        24.times do |hour|
          heatmap_data["#{day}_#{hour}"] = 0
        end
      end

      logs.each do |log|
        day = log.created_at.wday
        hour = log.created_at.hour
        heatmap_data["#{day}_#{hour}"] += 1
      end

      heatmap_data
    end

    # 실시간 활동 스트림
    def activity_stream(organization_id, limit = 20)
      by_organization(organization_id)
        .recent
        .limit(limit)
        .map { |log| format_activity_entry(log) }
    end

    # 세션 분석
    def session_analysis(session_id)
      logs = by_session(session_id).order(created_at: :asc)
      
      return {} if logs.empty?

      {
        session_id: session_id,
        user_id: logs.first.user_id,
        start_time: logs.first.created_at,
        end_time: logs.last.created_at,
        duration_minutes: ((logs.last.created_at - logs.first.created_at) / 60).round,
        total_actions: logs.count,
        resources_accessed: logs.map { |l| "#{l.resource_type}##{l.resource_id}" }.uniq.count,
        action_timeline: logs.map { |l| format_timeline_action(l) }
      }
    end

    # 검색 패턴 분석
    def search_patterns(organization_id, days = 30)
      by_organization(organization_id)
        .by_action('search')
        .date_range(days.days.ago, Time.current)
        .pluck(:request_params)
        .map { |params| params['q'] || params['query'] }
        .compact
        .group_by(&:itself)
        .transform_values(&:count)
        .sort_by { |_, v| -v }
        .first(20)
    end

    private

    def sanitize_params(params)
      params.except('controller', 'action', 'password', 'password_confirmation', 'token', 'secret')
    end

    def extract_device_info(user_agent)
      return {} unless user_agent.present?

      browser = Browser.new(user_agent)
      
      {
        browser: browser.name,
        browser_version: browser.version,
        platform: browser.platform.name,
        device_type: browser.device.name,
        is_mobile: browser.device.mobile?,
        is_tablet: browser.device.tablet?,
        is_bot: browser.bot?
      }
    rescue
      {}
    end

    def calculate_peak_hours(logs)
      logs.group_by { |l| l.created_at.hour }
          .transform_values(&:count)
          .sort_by { |_, v| -v }
          .first(3)
          .map { |hour, count| { hour: hour, count: count } }
    end

    def calculate_session_duration(logs)
      sessions = logs.group_by(&:session_id)
      
      durations = sessions.map do |_, session_logs|
        sorted_logs = session_logs.sort_by(&:created_at)
        (sorted_logs.last.created_at - sorted_logs.first.created_at) / 60
      end

      return 0 if durations.empty?
      
      (durations.sum / durations.length).round
    end

    def daily_activity_chart(logs)
      logs.group_by { |l| l.created_at.to_date }
          .transform_values(&:count)
          .sort
          .last(7)
    end

    def access_trend_data(query)
      query.this_week
           .group_by { |l| l.created_at.to_date }
           .transform_values(&:count)
    end

    def top_users_for_resource(query)
      query.group_by(&:user_id)
           .transform_values(&:count)
           .sort_by { |_, v| -v }
           .first(5)
           .map { |user_id, count| 
             { 
               user_id: user_id, 
               count: count,
               user: User.find_by(id: user_id)&.name
             } 
           }
    end

    def format_activity_entry(log)
      {
        id: log.id.to_s,
        user_id: log.user_id,
        action: log.action_type,
        resource: "#{log.resource_type}##{log.resource_id}",
        resource_name: log.resource_name,
        created_at: log.created_at,
        metadata: log.metadata
      }
    end

    def format_timeline_action(log)
      {
        time: log.created_at,
        action: log.action_type,
        resource: "#{log.resource_type}##{log.resource_id}",
        duration_ms: log.duration_ms
      }
    end
  end

  # Instance methods
  def user
    @user ||= User.find_by(id: user_id)
  end

  def organization
    @organization ||= Organization.find_by(id: organization_id)
  end

  def resource
    return nil unless resource_type.present? && resource_id.present?
    
    @resource ||= resource_type.constantize.find_by(id: resource_id)
  rescue NameError
    nil
  end

  def session_duration
    return nil unless session_id.present?
    
    session_logs = self.class.by_session(session_id)
    return nil if session_logs.count < 2
    
    first_log = session_logs.order(created_at: :asc).first
    last_log = session_logs.order(created_at: :desc).first
    
    ((last_log.created_at - first_log.created_at) / 60).round
  end

  def formatted_action
    "#{action_type.humanize} #{resource_type}"
  end

  def mobile?
    device_info['is_mobile'] == true
  end

  def desktop?
    !mobile? && device_info['is_tablet'] != true
  end
end