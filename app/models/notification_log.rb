# frozen_string_literal: true

# MongoDB에 저장되는 알림 로그 및 아카이브
class NotificationLog
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields - 기본 정보
  field :notification_id, type: Integer # PostgreSQL noticed_notifications ID
  field :event_id, type: Integer # PostgreSQL noticed_events ID
  field :recipient_id, type: Integer # User ID
  field :recipient_type, type: String, default: 'User'
  field :organization_id, type: Integer
  field :team_id, type: Integer
  
  # 알림 내용
  field :type, type: String # 알림 타입 (TaskAssigned, MentionNotification, etc.)
  field :title, type: String
  field :body, type: String
  field :action_url, type: String
  field :image_url, type: String
  field :category, type: String # task, comment, mention, system, alert
  field :priority, type: String, default: 'normal' # low, normal, high, urgent
  
  # 발송 채널
  field :channels, type: Array, default: [] # ['email', 'push', 'in_app', 'slack']
  field :channel_status, type: Hash, default: {} # { email: 'sent', push: 'failed' }
  
  # 상태 추적
  field :status, type: String, default: 'pending' # pending, sent, delivered, read, archived
  field :sent_at, type: Time
  field :delivered_at, type: Time
  field :read_at, type: Time
  field :archived_at, type: Time
  field :expires_at, type: Time
  
  # 상호작용
  field :interactions, type: Array, default: []
  # [{
  #   action: 'clicked',
  #   timestamp: Time,
  #   details: { button: 'view_task' }
  # }]
  
  field :click_count, type: Integer, default: 0
  field :dismissed, type: Boolean, default: false
  field :dismissed_at, type: Time
  
  # 메타데이터
  field :params, type: Hash, default: {} # 알림 생성시 전달된 파라미터
  field :metadata, type: Hash, default: {}
  field :error_details, type: Hash # 발송 실패시 에러 정보
  
  # 관련 엔티티
  field :related_entity_type, type: String # Task, Sprint, Comment 등
  field :related_entity_id, type: Integer
  field :sender_id, type: Integer # 알림을 발생시킨 사용자
  
  # 배치 처리
  field :batch_id, type: String # 대량 발송시 배치 식별자
  field :retry_count, type: Integer, default: 0
  field :last_retry_at, type: Time

  # Indexes
  index({ recipient_id: 1, created_at: -1 })
  index({ organization_id: 1, created_at: -1 })
  index({ status: 1, created_at: -1 })
  index({ type: 1, created_at: -1 })
  index({ read_at: 1 })
  index({ archived_at: 1 })
  index({ notification_id: 1 }, { unique: true, sparse: true })
  index({ batch_id: 1 })
  index({ expires_at: 1 })
  
  # TTL index - 6개월 후 자동 삭제 (선택적)
  # index({ archived_at: 1 }, { expire_after_seconds: 15552000 })

  # Validations
  validates :recipient_id, presence: true
  validates :type, presence: true
  validates :status, inclusion: { in: %w[pending sent delivered read archived failed] }
  validates :priority, inclusion: { in: %w[low normal high urgent] }
  validates :category, inclusion: { in: %w[task comment mention system alert sprint team] }, allow_nil: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_recipient, ->(user_id) { where(recipient_id: user_id) }
  scope :by_organization, ->(org_id) { where(organization_id: org_id) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_type, ->(type) { where(type: type) }
  scope :by_category, ->(category) { where(category: category) }
  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where(:read_at.ne => nil) }
  scope :not_archived, -> { where(archived_at: nil) }
  scope :archived, -> { where(:archived_at.ne => nil) }
  scope :high_priority, -> { where(priority: ['high', 'urgent']) }
  scope :expired, -> { where(:expires_at.lte => Time.current) }
  scope :active, -> { not_archived.where(:expires_at.gt => Time.current) }
  scope :today, -> { where(created_at: { '$gte': Time.zone.now.beginning_of_day }) }
  scope :this_week, -> { where(created_at: { '$gte': Time.zone.now.beginning_of_week }) }
  scope :this_month, -> { where(created_at: { '$gte': Time.zone.now.beginning_of_month }) }

  # Class methods
  class << self
    # PostgreSQL 알림을 MongoDB로 아카이빙
    def archive_from_postgresql(notification)
      log = new(
        notification_id: notification.id,
        event_id: notification.event_id,
        recipient_id: notification.recipient_id,
        recipient_type: notification.recipient_type,
        type: notification.type,
        params: notification.params,
        read_at: notification.read_at,
        created_at: notification.created_at,
        updated_at: notification.updated_at
      )
      
      # 이벤트 정보 추가
      if notification.event
        log.title = notification.event.params['title']
        log.body = notification.event.params['body']
        log.metadata = notification.event.metadata
      end
      
      log.status = notification.read_at? ? 'read' : 'delivered'
      log.archived_at = Time.current
      
      log.save!
      log
    end

    # 대량 아카이빙
    def bulk_archive(notifications)
      archived_count = 0
      failed_count = 0
      
      notifications.find_in_batches(batch_size: 100) do |batch|
        batch.each do |notification|
          begin
            archive_from_postgresql(notification)
            archived_count += 1
          rescue => e
            Rails.logger.error "Failed to archive notification #{notification.id}: #{e.message}"
            failed_count += 1
          end
        end
      end
      
      { archived: archived_count, failed: failed_count }
    end

    # 알림 통계
    def statistics(recipient_id, period = :week)
      range = case period
              when :day then 1.day.ago..Time.current
              when :week then 1.week.ago..Time.current
              when :month then 1.month.ago..Time.current
              else 1.week.ago..Time.current
              end
      
      notifications = by_recipient(recipient_id)
                     .where(created_at: range)
      
      {
        total: notifications.count,
        unread: notifications.unread.count,
        by_type: notifications.group_by(&:type).transform_values(&:count),
        by_category: notifications.group_by(&:category).transform_values(&:count),
        by_priority: notifications.group_by(&:priority).transform_values(&:count),
        read_rate: calculate_read_rate(notifications),
        interaction_rate: calculate_interaction_rate(notifications),
        peak_hours: calculate_peak_hours(notifications)
      }
    end

    # 사용자별 알림 선호도 분석
    def user_preferences_analysis(user_id)
      notifications = by_recipient(user_id).this_month
      
      {
        most_read_types: analyze_read_patterns(notifications),
        ignored_types: analyze_ignored_patterns(notifications),
        interaction_patterns: analyze_interaction_patterns(notifications),
        optimal_send_times: analyze_optimal_times(notifications),
        channel_effectiveness: analyze_channel_effectiveness(notifications)
      }
    end

    # 조직별 알림 트렌드
    def organization_trends(org_id, days = 30)
      end_date = Date.current
      start_date = end_date - days.days
      
      daily_stats = {}
      (start_date..end_date).each do |date|
        notifications = by_organization(org_id)
                       .where(created_at: date.beginning_of_day..date.end_of_day)
        
        daily_stats[date] = {
          sent: notifications.count,
          read: notifications.read.count,
          interactions: notifications.sum(&:click_count)
        }
      end
      
      daily_stats
    end

    # 알림 효과성 분석
    def effectiveness_analysis(type = nil)
      scope = type ? by_type(type) : all
      
      {
        delivery_rate: calculate_delivery_rate(scope),
        read_rate: calculate_read_rate(scope),
        interaction_rate: calculate_interaction_rate(scope),
        avg_time_to_read: calculate_avg_time_to_read(scope),
        channel_performance: analyze_channel_performance(scope)
      }
    end

    private

    def calculate_read_rate(notifications)
      return 0 if notifications.count == 0
      (notifications.read.count.to_f / notifications.count * 100).round(1)
    end

    def calculate_interaction_rate(notifications)
      return 0 if notifications.count == 0
      
      interacted = notifications.select { |n| n.click_count > 0 || n.interactions.any? }
      (interacted.count.to_f / notifications.count * 100).round(1)
    end

    def calculate_delivery_rate(notifications)
      return 0 if notifications.count == 0
      
      delivered = notifications.where(status: ['delivered', 'read'])
      (delivered.count.to_f / notifications.count * 100).round(1)
    end

    def calculate_avg_time_to_read(notifications)
      read_times = notifications.read.map do |n|
        next unless n.read_at && n.sent_at
        n.read_at - n.sent_at
      end.compact
      
      return 0 if read_times.empty?
      
      (read_times.sum / read_times.count / 60).round # in minutes
    end

    def calculate_peak_hours(notifications)
      notifications.group_by { |n| n.created_at.hour }
                  .transform_values(&:count)
                  .sort_by { |_, count| -count }
                  .first(3)
    end

    def analyze_read_patterns(notifications)
      notifications.read
                  .group_by(&:type)
                  .transform_values(&:count)
                  .sort_by { |_, count| -count }
                  .first(5)
    end

    def analyze_ignored_patterns(notifications)
      notifications.unread
                  .where(:created_at.lte => 7.days.ago)
                  .group_by(&:type)
                  .transform_values(&:count)
                  .sort_by { |_, count| -count }
                  .first(5)
    end

    def analyze_interaction_patterns(notifications)
      notifications.select { |n| n.interactions.any? }
                  .flat_map(&:interactions)
                  .group_by { |i| i['action'] }
                  .transform_values(&:count)
    end

    def analyze_optimal_times(notifications)
      read_quickly = notifications.select do |n|
        n.read_at && n.sent_at && (n.read_at - n.sent_at) < 1.hour
      end
      
      read_quickly.group_by { |n| n.sent_at.hour }
                 .transform_values(&:count)
                 .sort_by { |_, count| -count }
                 .first(3)
    end

    def analyze_channel_effectiveness(notifications)
      channel_stats = {}
      
      notifications.each do |n|
        n.channels.each do |channel|
          channel_stats[channel] ||= { sent: 0, read: 0 }
          channel_stats[channel][:sent] += 1
          channel_stats[channel][:read] += 1 if n.read_at?
        end
      end
      
      channel_stats.transform_values do |stats|
        read_rate = stats[:sent] > 0 ? (stats[:read].to_f / stats[:sent] * 100).round(1) : 0
        stats.merge(read_rate: read_rate)
      end
    end

    def analyze_channel_performance(notifications)
      channels = {}
      
      notifications.each do |n|
        n.channel_status.each do |channel, status|
          channels[channel] ||= { total: 0, success: 0 }
          channels[channel][:total] += 1
          channels[channel][:success] += 1 if status == 'sent' || status == 'delivered'
        end
      end
      
      channels.transform_values do |stats|
        success_rate = stats[:total] > 0 ? (stats[:success].to_f / stats[:total] * 100).round(1) : 0
        stats.merge(success_rate: success_rate)
      end
    end
  end

  # Instance methods
  
  # 알림을 읽음으로 표시
  def mark_as_read!
    return if read?
    
    self.read_at = Time.current
    self.status = 'read'
    save!
  end

  # 알림 아카이빙
  def archive!
    return if archived?
    
    self.archived_at = Time.current
    self.status = 'archived'
    save!
  end

  # 상호작용 기록
  def record_interaction(action, details = {})
    interaction = {
      action: action,
      timestamp: Time.current,
      details: details
    }
    
    self.interactions << interaction
    self.click_count += 1 if action == 'clicked'
    save!
  end

  # 알림 재발송
  def retry_send!
    return false if retry_count >= 3
    
    self.retry_count += 1
    self.last_retry_at = Time.current
    self.status = 'pending'
    save!
  end

  # Helper methods
  def read?
    read_at.present?
  end

  def unread?
    read_at.nil?
  end

  def archived?
    archived_at.present?
  end

  def expired?
    expires_at && expires_at <= Time.current
  end

  def high_priority?
    priority.in?(['high', 'urgent'])
  end

  # 관련 PostgreSQL 모델과의 연동
  def recipient
    @recipient ||= User.cached_find( recipient_id)
  end

  def organization
    @organization ||= Organization.find_by(id: organization_id)
  end

  def sender
    @sender ||= User.cached_find( sender_id)
  end

  def related_entity
    return nil unless related_entity_type && related_entity_id
    
    @related_entity ||= related_entity_type.constantize.find_by(id: related_entity_id)
  rescue NameError
    nil
  end
end