# frozen_string_literal: true

# MongoDB 기반 완전한 알림 시스템
class Notification
  include Mongoid::Document
  include Mongoid::Timestamps

  # Constants
  STATUSES = %w[pending queued sending sent delivered read archived failed].freeze
  PRIORITIES = %w[low medium high urgent critical].freeze
  CATEGORIES = %w[task comment mention sprint team system alert announcement].freeze
  CHANNELS = %w[in_app email push sms slack webhook].freeze

  # Fields - 수신자 정보
  field :recipient_id, type: Integer
  field :recipient_type, type: String, default: 'User'
  field :recipient_email, type: String
  field :organization_id, type: Integer
  field :team_id, type: Integer
  
  # Fields - 발신자 정보
  field :sender_id, type: Integer
  field :sender_type, type: String, default: 'User'
  field :sender_name, type: String
  
  # Fields - 알림 내용
  field :type, type: String # TaskAssignedNotification, CommentMentionNotification, etc.
  field :title, type: String
  field :body, type: String
  field :preview, type: String # 짧은 미리보기 텍스트
  field :action_text, type: String # 버튼 텍스트
  field :action_url, type: String # 클릭시 이동할 URL
  field :image_url, type: String
  field :icon, type: String # 아이콘 이름 또는 이모지
  
  # Fields - 분류 및 우선순위
  field :category, type: String
  field :priority, type: String, default: 'medium'
  field :tags, type: Array, default: []
  
  # Fields - 발송 정보
  field :channels, type: Array, default: ['in_app']
  field :channel_config, type: Hash, default: {}
  # {
  #   email: { template: 'task_assigned', subject_override: nil },
  #   push: { sound: 'default', badge: 1 },
  #   slack: { webhook_url: '...', channel: '#general' }
  # }
  
  field :scheduled_for, type: Time # 예약 발송 시간
  field :expires_at, type: Time # 만료 시간
  
  # Fields - 상태 추적
  field :status, type: String, default: 'pending'
  field :channel_statuses, type: Hash, default: {}
  # { email: 'sent', push: 'delivered', in_app: 'read' }
  
  field :queued_at, type: Time
  field :sent_at, type: Time
  field :delivered_at, type: Time
  field :read_at, type: Time
  field :archived_at, type: Time
  
  field :read_count, type: Integer, default: 0
  field :click_count, type: Integer, default: 0
  field :dismissed, type: Boolean, default: false
  field :dismissed_at, type: Time
  
  # Fields - 상호작용 추적
  field :interactions, type: Array, default: []
  # [{
  #   type: 'click|dismiss|action|share',
  #   timestamp: Time,
  #   channel: 'in_app',
  #   details: { button: 'view_task', device: 'mobile' }
  # }]
  
  # Fields - 관련 엔티티
  field :related_type, type: String # Task, Sprint, Comment, etc.
  field :related_id, type: Integer
  field :related_data, type: Hash, default: {} # 관련 데이터 캐싱
  
  # Fields - 메타데이터
  field :payload, type: Hash, default: {} # 원본 페이로드
  field :metadata, type: Hash, default: {}
  field :error_logs, type: Array, default: []
  field :retry_count, type: Integer, default: 0
  field :last_retry_at, type: Time
  
  # Fields - 그룹 및 배치
  field :group_id, type: String # 그룹 알림용
  field :batch_id, type: String # 배치 발송용
  field :parent_id, type: BSON::ObjectId # 답글 알림 등
  field :thread_id, type: String # 스레드 그룹핑
  
  # Fields - 사용자 설정
  field :user_preferences_applied, type: Boolean, default: false
  field :do_not_disturb_override, type: Boolean, default: false

  # Indexes
  index({ recipient_id: 1, created_at: -1 })
  index({ recipient_id: 1, status: 1, created_at: -1 })
  index({ organization_id: 1, created_at: -1 })
  index({ sender_id: 1, created_at: -1 })
  index({ type: 1, created_at: -1 })
  index({ category: 1, priority: 1, created_at: -1 })
  index({ status: 1, scheduled_for: 1 })
  index({ read_at: 1 })
  index({ archived_at: 1 })
  index({ expires_at: 1 })
  index({ group_id: 1 })
  index({ batch_id: 1 })
  index({ thread_id: 1 })
  index({ related_type: 1, related_id: 1 })
  
  # TTL index - 1년 후 자동 삭제
  index({ archived_at: 1 }, { expire_after_seconds: 31536000 })

  # Validations
  validates :recipient_id, presence: true
  validates :type, presence: true
  validates :title, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :priority, inclusion: { in: PRIORITIES }
  validates :category, inclusion: { in: CATEGORIES }, allow_nil: true
  validate :validate_channels

  # Callbacks
  before_validation :set_defaults
  before_create :apply_user_preferences
  after_create :queue_for_delivery

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :for_recipient, ->(user_id) { where(recipient_id: user_id) }
  scope :for_organization, ->(org_id) { where(organization_id: org_id) }
  scope :by_type, ->(type) { where(type: type) }
  scope :by_category, ->(category) { where(category: category) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :by_status, ->(status) { where(status: status) }
  
  scope :unread, -> { where(read_at: nil, status: ['sent', 'delivered']) }
  scope :read, -> { where(:read_at.ne => nil) }
  scope :pending, -> { where(status: 'pending') }
  scope :scheduled, -> { where(:scheduled_for.ne => nil, :scheduled_for.gt => Time.current) }
  scope :ready_to_send, -> { where(status: 'pending').any_of({ scheduled_for: nil }, { :scheduled_for.lte => Time.current }) }
  
  scope :not_archived, -> { where(archived_at: nil) }
  scope :archived, -> { where(:archived_at.ne => nil) }
  scope :not_expired, -> { any_of({ expires_at: nil }, { :expires_at.gt => Time.current }) }
  scope :high_priority, -> { where(:priority.in => ['high', 'urgent', 'critical']) }
  
  scope :today, -> { where(:created_at.gte => Time.zone.now.beginning_of_day) }
  scope :this_week, -> { where(:created_at.gte => Time.zone.now.beginning_of_week) }
  scope :this_month, -> { where(:created_at.gte => Time.zone.now.beginning_of_month) }

  # Class methods
  class << self
    # 알림 생성 및 발송
    def notify(recipient, type, params = {})
      notification = new(
        recipient_id: recipient.id,
        recipient_type: recipient.class.name,
        recipient_email: recipient.email,
        organization_id: recipient.try(:organization_id),
        type: type,
        **params
      )
      
      notification.save!
      notification
    end

    # 대량 알림 발송
    def notify_all(recipients, type, params = {})
      batch_id = SecureRandom.uuid
      notifications = []
      
      recipients.find_each do |recipient|
        notifications << notify(
          recipient,
          type,
          params.merge(batch_id: batch_id)
        )
      end
      
      notifications
    end

    # 예약 알림 생성
    def schedule(recipient, type, scheduled_for, params = {})
      notify(
        recipient,
        type,
        params.merge(scheduled_for: scheduled_for)
      )
    end

    # 그룹 알림 생성 (여러 알림을 하나로 묶음)
    def create_group(recipients, type, params = {})
      group_id = SecureRandom.uuid
      
      recipients.map do |recipient|
        notify(
          recipient,
          type,
          params.merge(group_id: group_id)
        )
      end
    end

    # 알림 템플릿 적용
    def from_template(recipient, template_name, variables = {})
      template = NotificationTemplate.find_by(name: template_name)
      return nil unless template
      
      notify(
        recipient,
        template.type,
        title: template.render_title(variables),
        body: template.render_body(variables),
        category: template.category,
        priority: template.priority,
        channels: template.channels
      )
    end

    # 읽지 않은 알림 개수
    def unread_count_for(user_id)
      for_recipient(user_id).unread.not_expired.count
    end

    # 알림 요약 (대시보드용)
    def summary_for(user_id)
      notifications = for_recipient(user_id).not_archived.not_expired
      
      {
        total: notifications.count,
        unread: notifications.unread.count,
        high_priority: notifications.high_priority.unread.count,
        by_category: notifications.unread.group_by(&:category).transform_values(&:count),
        recent: notifications.recent.limit(5).map(&:to_summary)
      }
    end

    # 주기적으로 실행되는 정리 작업
    def cleanup_expired
      expired.destroy_all
    end

    def process_scheduled
      ready_to_send.each(&:deliver!)
    end
  end

  # Instance methods

  # 알림 발송
  def deliver!
    return false if sent? || delivered? || read?
    
    update!(status: 'queued', queued_at: Time.current)
    NotificationDeliveryJob.perform_later(id.to_s)
    true
  end

  # 채널별 발송
  def deliver_to_channel(channel)
    return false unless channels.include?(channel)
    
    case channel
    when 'in_app'
      deliver_in_app
    when 'email'
      deliver_email
    when 'push'
      deliver_push
    when 'slack'
      deliver_slack
    else
      false
    end
  end

  # 읽음 처리
  def mark_as_read!(channel = 'in_app')
    return false if read?
    
    self.read_at = Time.current
    self.read_count += 1
    self.status = 'read'
    
    if channel_statuses[channel] != 'read'
      channel_statuses[channel] = 'read'
    end
    
    save!
  end

  # 아카이브
  def archive!
    return false if archived?
    
    self.archived_at = Time.current
    self.status = 'archived'
    save!
  end

  # 상호작용 기록
  def track_interaction(type, channel = 'in_app', details = {})
    interaction = {
      type: type,
      timestamp: Time.current,
      channel: channel,
      details: details
    }
    
    self.interactions << interaction
    self.click_count += 1 if type == 'click'
    save!
  end

  # 알림 해제
  def dismiss!
    return false if dismissed?
    
    self.dismissed = true
    self.dismissed_at = Time.current
    save!
  end

  # 재시도
  def retry!
    return false if retry_count >= 3
    
    self.retry_count += 1
    self.last_retry_at = Time.current
    self.status = 'pending'
    save!
    
    deliver!
  end

  # 요약 정보
  def to_summary
    {
      id: id.to_s,
      type: type,
      title: title,
      preview: preview || body.truncate(100),
      category: category,
      priority: priority,
      read: read?,
      created_at: created_at,
      action_url: action_url
    }
  end

  # Helper methods
  def sent?
    status == 'sent'
  end

  def delivered?
    status == 'delivered'
  end

  def read?
    read_at.present?
  end

  def archived?
    archived_at.present?
  end

  def expired?
    expires_at && expires_at <= Time.current
  end

  def scheduled?
    scheduled_for && scheduled_for > Time.current
  end

  def high_priority?
    priority.in?(['high', 'urgent', 'critical'])
  end

  # 관련 모델 접근
  def recipient
    @recipient ||= recipient_type.constantize.find_by(id: recipient_id)
  rescue NameError
    nil
  end

  def sender
    @sender ||= sender_type.constantize.find_by(id: sender_id) if sender_id
  rescue NameError
    nil
  end

  def related_object
    return nil unless related_type && related_id
    @related_object ||= related_type.constantize.find_by(id: related_id)
  rescue NameError
    nil
  end

  private

  def set_defaults
    self.status ||= 'pending'
    self.priority ||= 'medium'
    self.channels ||= ['in_app']
    self.preview ||= body&.truncate(100)
  end

  def apply_user_preferences
    return if user_preferences_applied?
    
    # 사용자 알림 설정 적용
    if recipient && recipient.respond_to?(:notification_preferences)
      prefs = recipient.notification_preferences
      
      # 알림 차단 확인
      return false if prefs[:blocked_types]&.include?(type)
      
      # 채널 설정
      self.channels = prefs[:channels] if prefs[:channels].present?
      
      # 방해금지 모드 확인
      if prefs[:do_not_disturb] && !do_not_disturb_override?
        self.scheduled_for = calculate_next_available_time(prefs)
      end
    end
    
    self.user_preferences_applied = true
  end

  def queue_for_delivery
    if scheduled?
      NotificationDeliveryJob.set(wait_until: scheduled_for).perform_later(id.to_s)
    else
      NotificationDeliveryJob.perform_later(id.to_s)
    end
  end

  def validate_channels
    return if channels.blank?
    
    invalid_channels = channels - CHANNELS
    if invalid_channels.any?
      errors.add(:channels, "contains invalid channels: #{invalid_channels.join(', ')}")
    end
  end

  def deliver_in_app
    channel_statuses['in_app'] = 'delivered'
    self.delivered_at ||= Time.current
    self.status = 'delivered' if status == 'sent'
    save!
  end

  def deliver_email
    # Email 발송 로직
    NotificationMailer.send_notification(self).deliver_later
    channel_statuses['email'] = 'sent'
    save!
  rescue => e
    log_error('email', e)
    false
  end

  def deliver_push
    # Push 알림 발송 로직
    # FCM, APNS 등 사용
    channel_statuses['push'] = 'sent'
    save!
  rescue => e
    log_error('push', e)
    false
  end

  def deliver_slack
    # Slack 발송 로직
    channel_statuses['slack'] = 'sent'
    save!
  rescue => e
    log_error('slack', e)
    false
  end

  def log_error(channel, error)
    self.error_logs << {
      channel: channel,
      error: error.message,
      timestamp: Time.current
    }
    channel_statuses[channel] = 'failed'
    save!
  end

  def calculate_next_available_time(preferences)
    # 사용자의 방해금지 시간 설정에 따라 다음 발송 가능 시간 계산
    # 예: 오전 9시 ~ 오후 6시만 알림
    Time.current.tomorrow.change(hour: 9)
  end
end