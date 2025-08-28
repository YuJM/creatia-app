# EndBreakJob - 휴식 종료 알림 작업
#
# 포모도로 휴식 시간이 끝났을 때 알림을 전송합니다.
#
class EndBreakJob < ApplicationJob
  queue_as :pomodoro
  
  discard_on ActiveRecord::RecordNotFound
  
  def perform(user_id:, session_id: nil)
    user = User.find(user_id)
    
    # 마지막 완료된 세션 찾기
    session = if session_id
                PomodoroSession.find(session_id)
              else
                user.pomodoro_sessions.completed.last
              end
    
    return unless session
    
    # 휴식 종료 알림 전송
    PomodoroNotifier.with(
      session: session,
      event_type: :break_end
    ).deliver(user)
    
    # ActionCable을 통해 실시간 알림
    ActionCable.server.broadcast(
      "pomodoro_#{user.id}",
      {
        type: "break_ended",
        message: "휴식이 끝났습니다. 다음 포모도로를 시작할 준비가 되셨나요?",
        next_action: "start_pomodoro",
        session_count_today: user.pomodoro_sessions.today.completed.count
      }
    )
    
    # 사용자의 포모도로 통계 업데이트
    update_user_statistics(user)
  end
  
  private
  
  def update_user_statistics(user)
    stats = {
      daily_completed: user.pomodoro_sessions.today.completed.count,
      weekly_completed: user.pomodoro_sessions.this_week.completed.count,
      total_focus_time: calculate_total_focus_time(user),
      productivity_score: calculate_productivity_score(user)
    }
    
    # 통계를 캐시에 저장
    Rails.cache.write(
      "user_pomodoro_stats:#{user.id}",
      stats,
      expires_in: 1.hour
    )
    
    # ActionCable을 통해 통계 업데이트 전송
    ActionCable.server.broadcast(
      "pomodoro_#{user.id}",
      {
        type: "stats_update",
        stats: stats
      }
    )
  end
  
  def calculate_total_focus_time(user)
    user.pomodoro_sessions.today.completed.count * 25
  end
  
  def calculate_productivity_score(user)
    # 완료율 기반 생산성 점수 계산
    total_started = user.pomodoro_sessions.today.count
    total_completed = user.pomodoro_sessions.today.completed.count
    
    return 0 if total_started.zero?
    
    ((total_completed.to_f / total_started) * 100).round
  end
end