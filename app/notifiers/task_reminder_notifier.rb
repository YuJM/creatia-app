# TaskReminderNotifier - 작업 마감일 알림 시스템
#
# 사용 예시:
# TaskReminderNotifier.with(task: task, reminder_type: :one_hour).deliver(task.assignee)

class TaskReminderNotifier < ApplicationNotifier
  # ActionCable을 통한 실시간 알림
  deliver_by :action_cable do |config|
    config.channel = NotificationsChannel
    config.stream = ->(recipient) { "user_#{recipient.id}" }
    config.message = -> { 
      {
        id: record.id,
        type: "task_reminder",
        reminder_type: params[:reminder_type],
        title: notification_title,
        body: notification_body,
        task: {
          id: params[:task].id,
          title: params[:task].title,
          deadline: params[:task].deadline,
          urgency_level: params[:task].urgency_level
        },
        created_at: Time.current
      }
    }
  end
  
  # 이메일 알림 (선택적)
  deliver_by :email do |config|
    config.mailer = "TaskMailer"
    config.method = :deadline_reminder
    config.delay = 5.seconds # 약간의 지연을 두고 발송
    config.if = -> { recipient.email_notifications_enabled? }
  end
  
  # 데이터베이스에 알림 저장
  deliver_by :database do |config|
    config.association_name = :notifications
    config.attributes = -> {
      {
        type: "TaskReminder",
        task_id: params[:task].id,
        reminder_type: params[:reminder_type],
        read: false
      }
    }
  end
  
  # Slack 알림 (선택적)
  # deliver_by :slack do |config|
  #   config.url = -> { recipient.slack_webhook_url }
  #   config.json = -> {
  #     {
  #       text: "📋 작업 알림",
  #       blocks: [
  #         {
  #           type: "section",
  #           text: {
  #             type: "mrkdwn",
  #             text: "*#{notification_title}*\n#{notification_body}"
  #           }
  #         },
  #         {
  #           type: "section",
  #           fields: [
  #             {
  #               type: "mrkdwn",
  #               text: "*작업:*\n#{params[:task].title}"
  #             },
  #             {
  #               type: "mrkdwn",
  #               text: "*마감일:*\n#{params[:task].deadline.strftime('%Y-%m-%d %H:%M')}"
  #             }
  #           ]
  #         },
  #         {
  #           type: "actions",
  #           elements: [
  #             {
  #               type: "button",
  #               text: { type: "plain_text", text: "작업 보기" },
  #               url: Rails.application.routes.url_helpers.task_url(params[:task], host: ENV['APP_HOST'])
  #             }
  #           ]
  #         }
  #       ]
  #     }
  #   }
  #   config.if = -> { recipient.slack_notifications_enabled? }
  # end
  
  # 필수 파라미터
  required_param :task
  required_param :reminder_type # :one_hour, :today, :overdue, :upcoming
  
  # 알림 제목
  def notification_title
    case params[:reminder_type]
    when :one_hour
      "⏰ 작업 마감 1시간 전"
    when :today
      "📅 오늘 마감 작업"
    when :overdue
      "🚨 마감 기한 초과"
    when :upcoming
      "📌 다가오는 마감일"
    else
      "📋 작업 알림"
    end
  end
  
  # 알림 내용
  def notification_body
    task = params[:task]
    
    case params[:reminder_type]
    when :one_hour
      "「#{task.title}」 작업이 1시간 후 마감됩니다."
    when :today
      "「#{task.title}」 작업이 오늘 #{task.deadline.strftime('%H:%M')}에 마감됩니다."
    when :overdue
      "「#{task.title}」 작업이 #{time_ago_in_words(task.deadline)} 전에 마감되었습니다."
    when :upcoming
      "「#{task.title}」 작업이 #{task.time_until_deadline}에 마감됩니다."
    else
      "「#{task.title}」 작업을 확인해주세요."
    end
  end
  
  private
  
  def time_ago_in_words(time)
    distance_in_minutes = ((Time.current - time) / 60.0).round
    
    case distance_in_minutes
    when 0..1
      "방금"
    when 2..59
      "#{distance_in_minutes}분"
    when 60..1439
      "#{(distance_in_minutes / 60).round}시간"
    else
      "#{(distance_in_minutes / 1440).round}일"
    end
  end
end