# DeadlineApproachingNotifier - 마감일 접근 지능형 알림
#
# 사용 예시:
# DeadlineApproachingNotifier.with(task: task, time_until: '2 hours').deliver(task.assignee)
# DeadlineApproachingNotifier.bulk_notify_upcoming_deadlines

class DeadlineApproachingNotifier < ApplicationNotifier
  # 다중 채널 전달 설정
  
  # 실시간 브라우저 알림
  deliver_by :action_cable do |config|
    config.channel = NotificationsChannel
    config.stream = ->(recipient) { "user_#{recipient.id}" }
    config.message = -> { notification_payload }
  end
  
  # 웹 푸시 알림 (PWA 지원)
  deliver_by :web_push do |config|
    config.endpoint = ->(recipient) { recipient.web_push_subscription&.endpoint }
    config.message = -> {
      {
        title: urgency_based_title,
        body: smart_notification_body,
        icon: '/notification-icon.png',
        badge: '/notification-badge.png',
        tag: "deadline-#{params[:task].id}",
        requireInteraction: high_urgency?,
        actions: notification_actions,
        data: {
          task_id: params[:task].id,
          deadline: params[:task].deadline,
          url: task_url
        }
      }
    }
    config.if = -> { recipient.web_push_enabled? && urgent_enough? }
  end
  
  # 이메일 다이제스트 (일일 요약)
  deliver_by :email do |config|
    config.mailer = "DeadlineMailer"
    config.method = :approaching_deadline
    config.delay = smart_delay
    config.if = -> { should_send_email? }
  end
  
  # SMS 알림 (긴급 사항만)
  deliver_by :twilio do |config|
    config.phone_number = ->(recipient) { recipient.phone_number }
    config.message = -> { sms_message }
    config.if = -> { critical_deadline? && recipient.sms_enabled? }
  end
  
  # 데이터베이스 저장 (항상)
  deliver_by :database do |config|
    config.association_name = :notifications
    config.attributes = -> { database_attributes }
  end
  
  # Microsoft Teams 통합
  deliver_by :microsoft_teams do |config|
    config.webhook_url = -> { recipient.teams_webhook_url }
    config.message = -> { teams_adaptive_card }
    config.if = -> { recipient.teams_enabled? && team_task? }
  end
  
  required_param :task
  optional_param :time_until
  optional_param :urgency_override
  
  # 지능형 알림 로직
  
  def urgency_based_title
    urgency = calculate_urgency
    
    case urgency
    when :critical
      "🚨 긴급: #{params[:task].title}"
    when :high
      "⚠️ 중요: 마감 임박 - #{params[:task].title}"
    when :medium
      "📅 알림: 마감일 접근 중"
    when :low
      "📌 참고: 예정된 마감일"
    else
      "📋 작업 마감일 알림"
    end
  end
  
  def smart_notification_body
    task = params[:task]
    time_remaining = task.business_hours_until_deadline
    
    if time_remaining && time_remaining > 0
      context_aware_message(task, time_remaining)
    else
      overdue_message(task)
    end
  end
  
  private
  
  def notification_payload
    {
      id: record.id,
      type: "deadline_approaching",
      urgency: calculate_urgency,
      title: urgency_based_title,
      body: smart_notification_body,
      task: enhanced_task_data,
      suggestions: smart_suggestions,
      snooze_options: calculate_snooze_options,
      created_at: Time.current
    }
  end
  
  def enhanced_task_data
    task = params[:task]
    {
      id: task.id,
      title: task.title,
      deadline: task.deadline,
      formatted_deadline: task.format_deadline(:relative),
      urgency_level: task.urgency_level,
      urgency_class: task.urgency_class,
      priority: task.priority,
      status: task.status,
      assignee: task.assignee&.name,
      estimated_hours: task.estimated_hours,
      actual_hours: task.actual_hours,
      business_hours_remaining: task.business_hours_until_deadline,
      completion_percentage: task.progress_percentage
    }
  end
  
  def context_aware_message(task, hours_remaining)
    # Chronic을 활용한 자연어 시간 표현
    deadline_text = ChronicKorean.parse(task.deadline.to_s) ? 
                    task.deadline.strftime("%m월 %d일 %p %l시") : 
                    task.deadline.strftime("%Y-%m-%d %H:%M")
    
    # Business Time을 활용한 정확한 업무시간 계산
    if hours_remaining < 1
      "#{(hours_remaining * 60).round}분 후 마감 (#{deadline_text})"
    elsif hours_remaining < 8
      "오늘 #{deadline_text}에 마감됩니다. (업무시간 #{hours_remaining.round(1)}시간 남음)"
    elsif hours_remaining < 24
      "내일 마감 예정입니다. 준비하세요!"
    else
      business_days = task.business_days_remaining
      "#{business_days}업무일 후 마감 (#{deadline_text})"
    end
  end
  
  def overdue_message(task)
    overdue_hours = ((Time.current - task.deadline) / 1.hour).round(1)
    
    if overdue_hours < 24
      "⚠️ #{overdue_hours}시간 지연되었습니다!"
    else
      overdue_days = (overdue_hours / 24).round
      "🚨 #{overdue_days}일 지연되었습니다. 즉시 확인이 필요합니다."
    end
  end
  
  def smart_suggestions
    task = params[:task]
    suggestions = []
    
    # 상황별 지능형 제안
    if task.is_overdue?
      suggestions << "마감일 재조정 요청"
      suggestions << "담당자와 상황 공유"
    elsif task.business_hours_until_deadline.to_i < 4
      suggestions << "핵심 기능에 집중"
      suggestions << "도움 요청 고려"
    elsif task.estimated_hours && task.actual_hours
      variance = task.time_variance
      if variance && variance[:accuracy_level] == :poor
        suggestions << "예상 시간 재평가 필요"
      end
    end
    
    # Pomodoro 세션 제안
    if task.pomodoro_sessions.none?
      suggestions << "포모도로 타이머 시작"
    end
    
    suggestions
  end
  
  def calculate_urgency
    return params[:urgency_override] if params[:urgency_override]
    
    task = params[:task]
    hours_remaining = task.business_hours_until_deadline
    
    return :overdue if task.is_overdue?
    return :critical if hours_remaining && hours_remaining < 2
    return :high if hours_remaining && hours_remaining < 8
    return :medium if hours_remaining && hours_remaining < 24
    :low
  end
  
  def notification_actions
    [
      {
        action: "open",
        title: "작업 열기",
        icon: "/icons/open.png"
      },
      {
        action: "snooze",
        title: "다시 알림",
        icon: "/icons/snooze.png"
      },
      {
        action: "complete",
        title: "완료 표시",
        icon: "/icons/check.png"
      }
    ]
  end
  
  def calculate_snooze_options
    urgency = calculate_urgency
    
    case urgency
    when :critical
      ["10분", "30분", "1시간"]
    when :high
      ["30분", "1시간", "2시간"]
    when :medium
      ["1시간", "3시간", "내일"]
    else
      ["3시간", "내일", "3일 후"]
    end
  end
  
  def smart_delay
    urgency = calculate_urgency
    
    case urgency
    when :critical
      0.seconds
    when :high
      5.minutes
    when :medium
      30.minutes
    else
      2.hours
    end
  end
  
  def should_send_email?
    recipient.email_notifications_enabled? && 
    (critical_deadline? || params[:force_email])
  end
  
  def critical_deadline?
    [:critical, :high].include?(calculate_urgency)
  end
  
  def urgent_enough?
    [:critical, :high, :medium].include?(calculate_urgency)
  end
  
  def high_urgency?
    [:critical, :high].include?(calculate_urgency)
  end
  
  def team_task?
    params[:task].team.present?
  end
  
  def task_url
    Rails.application.routes.url_helpers.service_task_url(
      params[:task].service,
      params[:task],
      host: ENV['APP_HOST']
    )
  end
  
  def sms_message
    task = params[:task]
    "긴급: '#{task.title.truncate(30)}' 작업이 #{task.time_until_deadline}에 마감됩니다. 확인: #{task_url}"
  end
  
  def database_attributes
    {
      type: "DeadlineApproaching",
      task_id: params[:task].id,
      urgency: calculate_urgency,
      metadata: {
        time_until: params[:time_until],
        business_hours_remaining: params[:task].business_hours_until_deadline,
        suggestions: smart_suggestions
      },
      read: false
    }
  end
  
  def teams_adaptive_card
    task = params[:task]
    
    {
      type: "message",
      attachments: [
        {
          contentType: "application/vnd.microsoft.card.adaptive",
          content: {
            type: "AdaptiveCard",
            version: "1.2",
            body: [
              {
                type: "TextBlock",
                text: urgency_based_title,
                weight: "bolder",
                size: "medium"
              },
              {
                type: "TextBlock",
                text: smart_notification_body,
                wrap: true
              },
              {
                type: "FactSet",
                facts: [
                  { title: "작업", value: task.title },
                  { title: "마감일", value: task.format_deadline(:long) },
                  { title: "우선순위", value: task.priority_display_name },
                  { title: "담당자", value: task.assignee&.name || "미지정" }
                ]
              }
            ],
            actions: [
              {
                type: "Action.OpenUrl",
                title: "작업 보기",
                url: task_url
              }
            ]
          }
        }
      ]
    }
  end
  
  # 대량 알림 전송을 위한 클래스 메서드
  class << self
    def bulk_notify_upcoming_deadlines
      # 24시간 이내 마감 태스크
      Task.where(
        :due_date.gte => Time.current,
        :due_date.lte => 24.hours.from_now,
        :status.ne => 'done'
      ).each do |task|
        assignee = User.cached_find( task.assignee_id) if task.assignee_id
        with(task: task).deliver_later(assignee) if assignee
      end
      
      # 1시간 이내 긴급 태스크
      Task.where(
        :due_date.gte => Time.current,
        :due_date.lte => 1.hour.from_now,
        :status.ne => 'done'
      ).each do |task|
        assignee = User.cached_find( task.assignee_id) if task.assignee_id
        with(task: task, urgency_override: :critical).deliver(assignee) if assignee
      end
    end
    
    def schedule_smart_reminders
      # Groupdate를 활용한 패턴 분석으로 최적 알림 시간 결정
      # MongoDB에서는 집계 분석을 별도 서비스로 처리
      productivity_by_hour = Mongodb::MongoMetrics.by_category('productivity')
                               .where(metric_type: 'hourly_productivity')
                               .order_by(timestamp: :desc)
                               .limit(24)
                               .group_by(&:hour)
      
      # 생산성이 높은 시간대 2시간 전에 알림 전송
      optimal_reminder_times = calculate_optimal_reminder_times(productivity_by_hour)
      
      optimal_reminder_times.each do |hour|
        NotificationSchedulerJob.set(wait_until: hour.hours.from_now)
                                .perform_later('deadline_check')
      end
    end
    
    private
    
    def calculate_optimal_reminder_times(productivity_data)
      # 생산성 데이터를 기반으로 최적 알림 시간 계산
      productivity_data.sort_by { |_, count| -count }
                       .first(3)
                       .map { |hour, _| hour.to_i - 2 }
                       .select { |hour| hour.between?(7, 20) }
    end
  end
end