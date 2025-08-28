class PomodoroChannel < ApplicationCable::Channel
  def subscribed
    if current_user
      stream_from "pomodoro_#{current_user.id}"
      
      # 현재 진행 중인 포모도로 세션 확인
      active_session = current_user.pomodoro_sessions.in_progress.first
      
      if active_session
        transmit(
          type: "active_session",
          session: serialize_session(active_session)
        )
      end
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end
  
  # 포모도로 세션 시작
  def start_session(data)
    task = current_user.tasks.find(data['task_id'])
    
    # 진행 중인 세션이 있으면 취소
    current_user.pomodoro_sessions.in_progress.update_all(status: :cancelled)
    
    session = current_user.pomodoro_sessions.create!(
      task: task,
      started_at: Time.current,
      status: :in_progress,
      session_count: current_user.pomodoro_sessions.today.completed.count + 1
    )
    
    # 알림 전송
    PomodoroNotifier.with(session: session, event_type: :start).deliver(current_user)
    
    transmit(
      type: "session_started",
      session: serialize_session(session)
    )
    
    # 25분 후 완료 알림 예약 (Job으로 처리)
    CompletePomodoroSessionJob.set(wait: 25.minutes).perform_later(session.id)
    
  rescue ActiveRecord::RecordNotFound
    transmit(
      type: "error",
      message: "작업을 찾을 수 없습니다."
    )
  end
  
  # 포모도로 세션 일시정지
  def pause_session(data)
    session = current_user.pomodoro_sessions.find(data['session_id'])
    
    if session.in_progress?
      # 일시정지 로직 구현
      transmit(
        type: "session_paused",
        session_id: session.id
      )
    end
  rescue ActiveRecord::RecordNotFound
    transmit(
      type: "error",
      message: "세션을 찾을 수 없습니다."
    )
  end
  
  # 포모도로 세션 완료
  def complete_session(data)
    session = current_user.pomodoro_sessions.find(data['session_id'])
    
    if session.complete!
      PomodoroNotifier.with(session: session, event_type: :complete).deliver(current_user)
      
      transmit(
        type: "session_completed",
        session: serialize_session(session),
        next_action: session.long_break_next? ? "long_break" : "short_break"
      )
    end
  rescue ActiveRecord::RecordNotFound
    transmit(
      type: "error",
      message: "세션을 찾을 수 없습니다."
    )
  end
  
  # 포모도로 세션 취소
  def cancel_session(data)
    session = current_user.pomodoro_sessions.find(data['session_id'])
    
    if session.cancel!
      PomodoroNotifier.with(session: session, event_type: :cancelled).deliver(current_user)
      
      transmit(
        type: "session_cancelled",
        session_id: session.id
      )
    end
  rescue ActiveRecord::RecordNotFound
    transmit(
      type: "error",
      message: "세션을 찾을 수 없습니다."
    )
  end
  
  # 휴식 시작
  def start_break(data)
    session = current_user.pomodoro_sessions.completed.last
    
    if session
      break_duration = session.long_break_next? ? 15.minutes : 5.minutes
      
      PomodoroNotifier.with(session: session, event_type: :break_start).deliver(current_user)
      
      transmit(
        type: "break_started",
        duration: break_duration.to_i,
        break_type: session.long_break_next? ? "long" : "short"
      )
      
      # 휴식 종료 알림 예약
      EndBreakJob.set(wait: break_duration).perform_later(current_user.id)
    end
  end
  
  # 오늘의 포모도로 통계
  def today_stats
    stats = DashboardService.pomodoro_stats_today(current_user)
    
    transmit(
      type: "today_stats",
      stats: stats
    )
  end
  
  private
  
  def serialize_session(session)
    {
      id: session.id,
      task_id: session.task_id,
      task_title: session.task.title,
      started_at: session.started_at,
      status: session.status,
      session_count: session.session_count,
      time_remaining: session.time_remaining,
      progress_percentage: session.progress_percentage
    }
  end
end
