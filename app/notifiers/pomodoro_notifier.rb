# PomodoroNotifier - 포모도로 타이머 알림 시스템
#
# 사용 예시:
# PomodoroNotifier.with(session: session, event_type: :start).deliver(session.user)

class PomodoroNotifier < ApplicationNotifier
  # ActionCable을 통한 실시간 알림
  deliver_by :action_cable do |config|
    config.channel = PomodoroChannel
    config.stream = ->(recipient) { "pomodoro_#{recipient.id}" }
    config.message = -> { 
      {
        id: record.id,
        type: "pomodoro",
        event_type: params[:event_type],
        title: notification_title,
        body: notification_body,
        session: {
          id: params[:session].id,
          task_id: params[:session].task_id,
          task_title: params[:session].task.title,
          session_count: params[:session].session_count,
          status: params[:session].status,
          next_session_type: params[:session].next_session_type,
          time_remaining: params[:session].time_remaining
        },
        sound: notification_sound,
        created_at: Time.current
      }
    }
  end
  
  # 브라우저 푸시 알림 (Web Push)
  # deliver_by :web_push do |config|
  #   config.vapid_key = Rails.application.credentials.dig(:vapid, :public_key)
  #   config.endpoint = -> { recipient.web_push_endpoint }
  #   config.p256dh = -> { recipient.web_push_p256dh }
  #   config.auth = -> { recipient.web_push_auth }
  #   config.json = -> {
  #     {
  #       title: notification_title,
  #       body: notification_body,
  #       icon: "/icons/pomodoro.png",
  #       badge: "/icons/badge.png",
  #       vibrate: vibration_pattern,
  #       data: {
  #         session_id: params[:session].id,
  #         event_type: params[:event_type]
  #       },
  #       actions: notification_actions
  #     }
  #   }
  #   config.if = -> { recipient.web_push_enabled? }
  # end
  
  # 데이터베이스에 알림 저장
  deliver_by :database do |config|
    config.association_name = :notifications
    config.attributes = -> {
      {
        type: "PomodoroNotification",
        pomodoro_session_id: params[:session].id,
        event_type: params[:event_type],
        read: false
      }
    }
  end
  
  # 필수 파라미터
  required_param :session
  required_param :event_type # :start, :complete, :break_start, :break_end, :cancelled
  
  # 알림 제목
  def notification_title
    case params[:event_type]
    when :start
      "🍅 포모도로 시작!"
    when :complete
      "✅ 포모도로 완료!"
    when :break_start
      break_type_text = params[:session].long_break_next? ? "긴 휴식" : "짧은 휴식"
      "☕ #{break_type_text} 시간"
    when :break_end
      "🎯 휴식 종료"
    when :cancelled
      "❌ 포모도로 취소됨"
    else
      "🍅 포모도로 타이머"
    end
  end
  
  # 알림 내용
  def notification_body
    session = params[:session]
    task = session.task
    
    case params[:event_type]
    when :start
      "「#{task.title}」 작업을 25분간 집중하세요!"
    when :complete
      completed_today = session.todays_completed_sessions
      "#{session.session_count}번째 세션 완료! (오늘: #{completed_today}개)"
    when :break_start
      duration = session.long_break_next? ? "15분" : "5분"
      "#{duration}간 휴식하세요. 잠시 일어나서 스트레칭하는 것을 권장합니다."
    when :break_end
      "휴식이 끝났습니다. 다음 포모도로를 시작할 준비가 되셨나요?"
    when :cancelled
      "포모도로가 취소되었습니다. 「#{task.title}」"
    else
      "「#{task.title}」 작업 진행 중"
    end
  end
  
  # 알림 소리
  def notification_sound
    case params[:event_type]
    when :start
      "pomodoro_start.mp3"
    when :complete, :break_end
      "pomodoro_complete.mp3"
    when :break_start
      "break_time.mp3"
    when :cancelled
      "cancelled.mp3"
    else
      nil
    end
  end
  
  # 진동 패턴 (밀리초 단위)
  def vibration_pattern
    case params[:event_type]
    when :start
      [200, 100, 200] # 진동-쉼-진동
    when :complete
      [100, 50, 100, 50, 100] # 짧은 진동 3회
    when :break_start
      [300] # 긴 진동 1회
    else
      [200]
    end
  end
  
  # 알림 액션 버튼
  def notification_actions
    case params[:event_type]
    when :complete
      [
        { action: "start_break", title: "휴식 시작" },
        { action: "skip_break", title: "휴식 건너뛰기" }
      ]
    when :break_end
      [
        { action: "start_pomodoro", title: "포모도로 시작" },
        { action: "extend_break", title: "5분 더" }
      ]
    else
      []
    end
  end
end