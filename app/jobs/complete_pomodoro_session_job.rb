# CompletePomodoroSessionJob - 포모도로 세션 자동 완료 작업
#
# 25분 타이머가 끝났을 때 자동으로 세션을 완료 처리합니다.
#
class CompletePomodoroSessionJob < ApplicationJob
  queue_as :pomodoro
  
  discard_on ActiveRecord::RecordNotFound
  
  def perform(session_id)
    session = PomodoroSession.find(session_id)
    
    # 이미 완료되었거나 취소된 경우 무시
    return unless session.in_progress?
    
    # 세션 완료 처리
    session.complete!
    
    # 완료 알림 전송
    PomodoroNotifier.with(
      session: session,
      event_type: :complete
    ).deliver(session.user)
    
    # 휴식 시작 권장 알림
    recommend_break(session)
  end
  
  private
  
  def recommend_break(session)
    break_type = session.long_break_next? ? :long : :short
    break_duration = break_type == :long ? 15.minutes : 5.minutes
    
    # ActionCable을 통해 휴식 권장 메시지 전송
    ActionCable.server.broadcast(
      "pomodoro_#{session.user.id}",
      {
        type: "break_recommendation",
        break_type: break_type,
        duration: break_duration.to_i,
        session_count: session.session_count,
        message: break_message(break_type)
      }
    )
  end
  
  def break_message(break_type)
    if break_type == :long
      "🎉 4개의 포모도로를 완료했습니다! 15분간 긴 휴식을 취하세요."
    else
      "☕ 포모도로를 완료했습니다! 5분간 짧은 휴식을 취하세요."
    end
  end
end