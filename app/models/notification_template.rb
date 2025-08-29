# frozen_string_literal: true

# 재사용 가능한 알림 템플릿
class NotificationTemplate
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  field :name, type: String # 템플릿 식별자
  field :type, type: String # 알림 타입
  field :category, type: String
  field :priority, type: String, default: 'normal'
  
  # 다국어 지원
  field :title_template, type: Hash, default: {}
  # { 
  #   en: "{{user}} assigned you a task: {{task_title}}",
  #   ko: "{{user}}님이 작업을 할당했습니다: {{task_title}}"
  # }
  
  field :body_template, type: Hash, default: {}
  # {
  #   en: "You have been assigned to '{{task_title}}'. Due date: {{due_date}}",
  #   ko: "'{{task_title}}' 작업이 할당되었습니다. 마감일: {{due_date}}"
  # }
  
  field :preview_template, type: Hash, default: {}
  field :action_text_template, type: Hash, default: {}
  
  # 채널별 설정
  field :channels, type: Array, default: ['in_app']
  field :channel_templates, type: Hash, default: {}
  # {
  #   email: { subject: "...", html_template: "...", text_template: "..." },
  #   push: { title: "...", body: "...", sound: "default" },
  #   slack: { format: "markdown", attachments: true }
  # }
  
  # 메타데이터
  field :icon, type: String
  field :color, type: String
  field :tags, type: Array, default: []
  field :active, type: Boolean, default: true
  field :organization_id, type: Integer # nil이면 시스템 템플릿
  
  # 변수 정의
  field :variables, type: Array, default: []
  # [
  #   { name: 'user', type: 'string', required: true },
  #   { name: 'task_title', type: 'string', required: true },
  #   { name: 'due_date', type: 'date', required: false, format: '%Y-%m-%d' }
  # ]
  
  # 조건부 로직
  field :conditions, type: Hash, default: {}
  # {
  #   priority: "task.priority == 'urgent' ? 'high' : 'normal'",
  #   channels: "user.preferences.email_enabled ? ['in_app', 'email'] : ['in_app']"
  # }

  # Indexes
  index({ name: 1 }, { unique: true })
  index({ type: 1 })
  index({ category: 1 })
  index({ organization_id: 1 })
  index({ active: 1 })

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :type, presence: true
  validates :title_template, presence: true
  validates :body_template, presence: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :system, -> { where(organization_id: nil) }
  scope :for_organization, ->(org_id) { where(organization_id: org_id) }
  scope :by_category, ->(category) { where(category: category) }

  # Class methods
  class << self
    # 시스템 템플릿 초기화
    def seed_system_templates
      create_task_templates
      create_comment_templates
      create_sprint_templates
      create_team_templates
      create_system_templates
    end

    private

    def create_task_templates
      # Task 할당 템플릿
      create!(
        name: 'task_assigned',
        type: 'TaskAssignedNotification',
        category: 'task',
        priority: 'normal',
        title_template: {
          en: '{{sender_name}} assigned you a task',
          ko: '{{sender_name}}님이 작업을 할당했습니다'
        },
        body_template: {
          en: "You have been assigned to '{{task_title}}'. {{#if due_date}}Due: {{due_date}}{{/if}}",
          ko: "'{{task_title}}' 작업이 할당되었습니다. {{#if due_date}}마감일: {{due_date}}{{/if}}"
        },
        action_text_template: {
          en: 'View Task',
          ko: '작업 보기'
        },
        icon: '📋',
        channels: ['in_app', 'email', 'push'],
        variables: [
          { name: 'sender_name', type: 'string', required: true },
          { name: 'task_title', type: 'string', required: true },
          { name: 'due_date', type: 'date', required: false }
        ]
      )

      # Task 완료 템플릿
      create!(
        name: 'task_completed',
        type: 'TaskCompletedNotification',
        category: 'task',
        priority: 'normal',
        title_template: {
          en: 'Task completed',
          ko: '작업이 완료되었습니다'
        },
        body_template: {
          en: "{{sender_name}} completed '{{task_title}}'",
          ko: "{{sender_name}}님이 '{{task_title}}' 작업을 완료했습니다"
        },
        icon: '✅',
        channels: ['in_app']
      )

      # Task 마감 임박 템플릿
      create!(
        name: 'task_due_soon',
        type: 'TaskDueSoonNotification',
        category: 'task',
        priority: 'high',
        title_template: {
          en: 'Task due soon',
          ko: '작업 마감일이 다가옵니다'
        },
        body_template: {
          en: "'{{task_title}}' is due {{due_date}}",
          ko: "'{{task_title}}' 작업이 {{due_date}}에 마감됩니다"
        },
        icon: '⏰',
        channels: ['in_app', 'email', 'push']
      )
    end

    def create_comment_templates
      # 댓글 멘션 템플릿
      create!(
        name: 'comment_mention',
        type: 'CommentMentionNotification',
        category: 'mention',
        priority: 'normal',
        title_template: {
          en: '{{sender_name}} mentioned you',
          ko: '{{sender_name}}님이 멘션했습니다'
        },
        body_template: {
          en: '{{sender_name}} mentioned you in a comment: {{comment_preview}}',
          ko: '{{sender_name}}님이 댓글에서 멘션했습니다: {{comment_preview}}'
        },
        action_text_template: {
          en: 'View Comment',
          ko: '댓글 보기'
        },
        icon: '💬',
        channels: ['in_app', 'email', 'push']
      )

      # 댓글 답글 템플릿
      create!(
        name: 'comment_reply',
        type: 'CommentReplyNotification',
        category: 'comment',
        priority: 'normal',
        title_template: {
          en: '{{sender_name}} replied to your comment',
          ko: '{{sender_name}}님이 답글을 남겼습니다'
        },
        body_template: {
          en: '{{sender_name}} replied: {{reply_preview}}',
          ko: '{{sender_name}}님의 답글: {{reply_preview}}'
        },
        icon: '💭',
        channels: ['in_app', 'email']
      )
    end

    def create_sprint_templates
      # Sprint 시작 템플릿
      create!(
        name: 'sprint_started',
        type: 'SprintStartedNotification',
        category: 'sprint',
        priority: 'normal',
        title_template: {
          en: 'Sprint started',
          ko: '스프린트가 시작되었습니다'
        },
        body_template: {
          en: "{{sprint_name}} has started. Let's achieve our goals together!",
          ko: "{{sprint_name}} 스프린트가 시작되었습니다. 목표 달성을 위해 함께 노력해요!"
        },
        action_text_template: {
          en: 'View Sprint',
          ko: '스프린트 보기'
        },
        icon: '🏃',
        channels: ['in_app', 'email']
      )

      # Sprint 종료 임박 템플릿
      create!(
        name: 'sprint_ending_soon',
        type: 'SprintEndingSoonNotification',
        category: 'sprint',
        priority: 'high',
        title_template: {
          en: 'Sprint ending soon',
          ko: '스프린트 종료가 다가옵니다'
        },
        body_template: {
          en: '{{sprint_name}} ends on {{end_date}}',
          ko: '{{sprint_name}} 스프린트가 {{end_date}}에 종료됩니다'
        },
        icon: '⏳',
        channels: ['in_app', 'push']
      )
    end

    def create_team_templates
      # 팀 초대 템플릿
      create!(
        name: 'team_invitation',
        type: 'TeamInvitationNotification',
        category: 'team',
        priority: 'normal',
        title_template: {
          en: 'Team invitation',
          ko: '팀 초대'
        },
        body_template: {
          en: "{{sender_name}} invited you to join '{{team_name}}'",
          ko: "{{sender_name}}님이 '{{team_name}}' 팀에 초대했습니다"
        },
        action_text_template: {
          en: 'View Invitation',
          ko: '초대 확인'
        },
        icon: '👥',
        channels: ['in_app', 'email']
      )

      # 새 팀원 합류 템플릿
      create!(
        name: 'team_member_joined',
        type: 'TeamMemberJoinedNotification',
        category: 'team',
        priority: 'low',
        title_template: {
          en: 'New team member',
          ko: '새로운 팀원'
        },
        body_template: {
          en: '{{member_name}} joined {{team_name}}',
          ko: '{{member_name}}님이 {{team_name}} 팀에 합류했습니다'
        },
        icon: '🤝',
        channels: ['in_app']
      )
    end

    def create_system_templates
      # 시스템 공지 템플릿
      create!(
        name: 'system_announcement',
        type: 'SystemAnnouncementNotification',
        category: 'announcement',
        priority: 'normal',
        title_template: {
          en: '{{title}}',
          ko: '{{title}}'
        },
        body_template: {
          en: '{{body}}',
          ko: '{{body}}'
        },
        icon: '📢',
        channels: ['in_app', 'email']
      )

      # 시스템 점검 템플릿
      create!(
        name: 'system_maintenance',
        type: 'SystemMaintenanceNotification',
        category: 'system',
        priority: 'high',
        title_template: {
          en: 'Scheduled maintenance',
          ko: '시스템 점검 예정'
        },
        body_template: {
          en: 'System maintenance scheduled from {{start_time}} to {{end_time}}',
          ko: '{{start_time}}부터 {{end_time}}까지 시스템 점검이 예정되어 있습니다'
        },
        icon: '🔧',
        channels: ['in_app', 'email', 'push']
      )
    end
  end

  # Instance methods

  # 템플릿 렌더링
  def render(locale = :en, variables = {})
    {
      title: render_template(title_template[locale.to_s], variables),
      body: render_template(body_template[locale.to_s], variables),
      preview: render_template(preview_template[locale.to_s], variables),
      action_text: render_template(action_text_template[locale.to_s], variables)
    }
  end

  # 특정 필드 렌더링
  def render_title(variables = {}, locale = :en)
    render_template(title_template[locale.to_s], variables)
  end

  def render_body(variables = {}, locale = :en)
    render_template(body_template[locale.to_s], variables)
  end

  # 변수 검증
  def validate_variables(provided_variables)
    required = variables.select { |v| v['required'] }.map { |v| v['name'] }
    missing = required - provided_variables.keys.map(&:to_s)
    
    if missing.any?
      errors.add(:variables, "Missing required variables: #{missing.join(', ')}")
      return false
    end
    
    true
  end

  # 조건 평가
  def evaluate_conditions(context = {})
    result = {}
    
    conditions.each do |key, expression|
      result[key] = evaluate_expression(expression, context)
    end
    
    result
  end

  private

  def render_template(template, variables)
    return '' if template.blank?
    
    rendered = template.dup
    
    # Handlebars 스타일 변수 치환
    variables.each do |key, value|
      rendered.gsub!("{{#{key}}}", value.to_s)
    end
    
    # 조건부 렌더링 (간단한 if 문)
    rendered.gsub!(/\{\{#if\s+(\w+)\}\}(.*?)\{\{\/if\}\}/m) do
      condition = $1
      content = $2
      variables[condition.to_sym].present? ? content : ''
    end
    
    # 남은 변수 제거
    rendered.gsub!(/\{\{.*?\}\}/, '')
    
    rendered
  end

  def evaluate_expression(expression, context)
    # 간단한 표현식 평가 (보안을 위해 제한적으로 구현)
    # 실제 구현에서는 더 안전한 평가 방법 사용 필요
    case expression
    when /^'(.*)'$/, /^"(.*)"$/
      $1
    when /^\d+$/
      expression.to_i
    when 'true'
      true
    when 'false'
      false
    else
      context[expression.to_sym]
    end
  end
end