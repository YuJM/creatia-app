# SprintNotifier - 스프린트 관련 알림 시스템
#
# 사용 예시:
# SprintNotifier.with(sprint: sprint, event_type: :starting).deliver(team_members)
# SprintNotifier.with(sprint: sprint, event_type: :ending_soon).deliver_later(team_members)

class SprintNotifier < ApplicationNotifier
  # ActionCable을 통한 실시간 알림
  deliver_by :action_cable do |config|
    config.channel = NotificationsChannel
    config.stream = ->(recipient) { "user_#{recipient.id}" }
    config.message = -> { 
      {
        id: record.id,
        type: "sprint_notification",
        event_type: params[:event_type],
        title: notification_title,
        body: notification_body,
        sprint: sprint_data,
        action_url: sprint_url,
        priority: notification_priority,
        created_at: Time.current
      }
    }
  end
  
  # 이메일 알림 (중요 이벤트만)
  deliver_by :email do |config|
    config.mailer = "SprintMailer"
    config.method = :sprint_notification
    config.delay = 1.minute
    config.if = -> { recipient.email_notifications_enabled? && important_event? }
  end
  
  # 데이터베이스에 알림 저장
  deliver_by :database do |config|
    config.association_name = :notifications
    config.attributes = -> {
      {
        type: "SprintNotification",
        sprint_id: params[:sprint].id,
        event_type: params[:event_type],
        metadata: event_metadata,
        read: false
      }
    }
  end
  
  # Slack 통합
  deliver_by :slack do |config|
    config.url = -> { recipient.slack_webhook_url }
    config.json = -> { slack_message }
    config.if = -> { recipient.slack_notifications_enabled? && team_event? }
  end
  
  # 필수 파라미터
  required_param :sprint
  required_param :event_type # :starting, :ending_soon, :completed, :review_reminder, :velocity_update
  
  # 알림 제목
  def notification_title
    case params[:event_type]
    when :starting
      "🚀 스프린트 시작"
    when :ending_soon
      "⏰ 스프린트 종료 임박"
    when :completed
      "✅ 스프린트 완료"
    when :review_reminder
      "📝 스프린트 리뷰"
    when :velocity_update
      "📊 벨로시티 업데이트"
    when :planning_reminder
      "📋 스프린트 계획 리마인더"
    else
      "📌 스프린트 알림"
    end
  end
  
  # 알림 내용
  def notification_body
    sprint = params[:sprint]
    
    case params[:event_type]
    when :starting
      "「#{sprint.name}」 스프린트가 시작되었습니다. #{sprint.business_days_total}일간 진행됩니다."
    when :ending_soon
      "「#{sprint.name}」 스프린트가 #{sprint.business_days_remaining}일 후 종료됩니다. (진행률: #{sprint.completion_percentage}%)"
    when :completed
      "「#{sprint.name}」 스프린트가 완료되었습니다. 벨로시티: #{sprint.velocity} 포인트"
    when :review_reminder
      "「#{sprint.name}」 스프린트 리뷰 미팅을 잊지 마세요!"
    when :velocity_update
      "「#{sprint.name}」 현재 벨로시티: #{sprint.velocity}/#{sprint.planned_points} 포인트"
    when :planning_reminder
      "다음 스프린트 계획 세션이 #{params[:time_until] || '곧'} 시작됩니다."
    else
      "「#{sprint.name}」 스프린트를 확인해주세요."
    end
  end
  
  private
  
  def sprint_data
    sprint = params[:sprint]
    {
      id: sprint.id,
      name: sprint.name,
      start_date: sprint.start_date,
      end_date: sprint.end_date,
      status: sprint.status,
      progress: sprint.progress_percentage,
      velocity: sprint.velocity,
      planned_points: sprint.planned_points,
      business_days_remaining: sprint.business_days_remaining
    }
  end
  
  def sprint_url
    Rails.application.routes.url_helpers.service_sprint_url(
      params[:sprint].service,
      params[:sprint],
      host: ENV['APP_HOST']
    )
  end
  
  def notification_priority
    case params[:event_type]
    when :ending_soon, :review_reminder
      'high'
    when :starting, :completed
      'medium'
    else
      'normal'
    end
  end
  
  def important_event?
    [:starting, :ending_soon, :completed, :review_reminder].include?(params[:event_type])
  end
  
  def team_event?
    [:starting, :completed, :review_reminder].include?(params[:event_type])
  end
  
  def event_metadata
    {
      event_type: params[:event_type],
      sprint_status: params[:sprint].status,
      velocity: params[:sprint].velocity,
      completion: params[:sprint].completion_percentage
    }
  end
  
  def slack_message
    sprint = params[:sprint]
    
    {
      text: notification_title,
      blocks: [
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*#{notification_title}*\n#{notification_body}"
          }
        },
        {
          type: "section",
          fields: [
            {
              type: "mrkdwn",
              text: "*기간:*\n#{sprint.start_date.strftime('%m/%d')} - #{sprint.end_date.strftime('%m/%d')}"
            },
            {
              type: "mrkdwn",
              text: "*진행률:*\n#{sprint.completion_percentage}%"
            },
            {
              type: "mrkdwn",
              text: "*벨로시티:*\n#{sprint.velocity}/#{sprint.planned_points}"
            },
            {
              type: "mrkdwn",
              text: "*남은 일수:*\n#{sprint.business_days_remaining}일"
            }
          ]
        },
        {
          type: "actions",
          elements: [
            {
              type: "button",
              text: { type: "plain_text", text: "스프린트 보기" },
              url: sprint_url
            }
          ]
        }
      ],
      attachments: [
        {
          color: slack_color,
          fields: burndown_chart_fields
        }
      ] if params[:event_type] == :velocity_update
    }.compact
  end
  
  def slack_color
    case params[:event_type]
    when :starting
      "#36a64f" # Green
    when :ending_soon
      "#ff9900" # Orange
    when :completed
      "#0099ff" # Blue
    else
      "#cccccc" # Gray
    end
  end
  
  def burndown_chart_fields
    sprint = params[:sprint]
    
    [{
      title: "번다운 차트 요약",
      value: "이상적 포인트: #{sprint.ideal_burndown_line[Date.current]}\n" \
             "실제 포인트: #{sprint.burndown_remaining_points[Date.current]}\n" \
             "예상 완료율: #{sprint.projected_velocity}",
      short: false
    }]
  end
end