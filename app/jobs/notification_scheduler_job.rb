# NotificationSchedulerJob - 알림 스케줄링 백그라운드 작업
#
# Solid Queue의 recurring job으로 설정되어 정기적으로 실행되며,
# 마감일 임박 작업과 포모도로 세션을 확인하여 알림을 생성합니다.
#
# 실행 주기: 5분마다 (config/recurring.yml에서 설정)
#
class NotificationSchedulerJob < ApplicationJob
  queue_as :notifications
  
  # 포모도로 세션 완료 후 휴식 종료 알림
  retry_on ActiveRecord::RecordNotFound, wait: 5.seconds, attempts: 3
  
  def perform
    check_task_deadlines
    check_overdue_tasks
    check_upcoming_tasks
    process_pomodoro_sessions
  end
  
  private
  
  # 1시간 이내 마감 작업 확인
  def check_task_deadlines
    Task
      .not_completed
      .where(deadline: 55.minutes.from_now..65.minutes.from_now)
      .where.not(id: recently_notified_task_ids(:one_hour))
      .find_each do |task|
        TaskReminderNotifier.with(
          task: task,
          reminder_type: :one_hour
        ).deliver(task.assignee)
        
        mark_as_notified(task.id, :one_hour)
      end
  end
  
  # 오늘 마감 작업 확인 (오전 9시에 실행될 때)
  def check_today_tasks
    return unless Time.current.hour == 9
    
    Task
      .not_completed
      .where(deadline: Time.current.beginning_of_day..Time.current.end_of_day)
      .where.not(id: recently_notified_task_ids(:today))
      .find_each do |task|
        TaskReminderNotifier.with(
          task: task,
          reminder_type: :today
        ).deliver(task.assignee)
        
        mark_as_notified(task.id, :today)
      end
  end
  
  # 마감 기한 초과 작업 확인
  def check_overdue_tasks
    Task
      .not_completed
      .where(deadline: ...Time.current)
      .where.not(id: recently_notified_task_ids(:overdue))
      .find_each do |task|
        # 하루에 한 번만 알림
        next if notified_today?(task.id, :overdue)
        
        TaskReminderNotifier.with(
          task: task,
          reminder_type: :overdue
        ).deliver(task.assignee)
        
        mark_as_notified(task.id, :overdue)
      end
  end
  
  # 다가오는 작업 확인 (24시간 이내)
  def check_upcoming_tasks
    Task
      .not_completed
      .where(deadline: Time.current..24.hours.from_now)
      .where.not(id: recently_notified_task_ids(:upcoming))
      .find_each do |task|
        # 4시간마다 한 번씩 알림
        next if notified_within?(task.id, :upcoming, 4.hours)
        
        TaskReminderNotifier.with(
          task: task,
          reminder_type: :upcoming
        ).deliver(task.assignee)
        
        mark_as_notified(task.id, :upcoming)
      end
  end
  
  # 진행 중인 포모도로 세션 처리
  def process_pomodoro_sessions
    # 25분이 지난 진행 중인 세션 완료 처리
    PomodoroSession
      .in_progress
      .where(started_at: ...25.minutes.ago)
      .find_each do |session|
        complete_pomodoro_session(session)
      end
    
    # 휴식 시간이 끝난 세션 알림
    check_break_end_notifications
  end
  
  def complete_pomodoro_session(session)
    session.complete!
    
    PomodoroNotifier.with(
      session: session,
      event_type: :complete
    ).deliver(session.user)
    
    # 휴식 시작 알림 예약
    schedule_break_notification(session)
  end
  
  def schedule_break_notification(session)
    break_duration = session.long_break_next? ? 15.minutes : 5.minutes
    
    EndBreakJob.set(wait: break_duration).perform_later(
      user_id: session.user.id,
      session_id: session.id
    )
  end
  
  def check_break_end_notifications
    # Redis나 데이터베이스에 저장된 휴식 종료 시간 확인
    # 구현 예정: 휴식 상태 추적을 위한 별도 모델이나 캐시 사용
  end
  
  # 최근 알림 발송된 작업 ID 목록
  def recently_notified_task_ids(reminder_type)
    Rails.cache.fetch("notified_tasks:#{reminder_type}", expires_in: 1.hour) do
      []
    end
  end
  
  # 작업을 알림 발송됨으로 표시
  def mark_as_notified(task_id, reminder_type)
    key = "notified_tasks:#{reminder_type}"
    notified_ids = Rails.cache.fetch(key, expires_in: 1.hour) { [] }
    notified_ids << task_id
    Rails.cache.write(key, notified_ids.uniq, expires_in: 1.hour)
    
    # 개별 작업별 알림 시간도 기록
    Rails.cache.write(
      "notified_task:#{task_id}:#{reminder_type}",
      Time.current,
      expires_in: 24.hours
    )
  end
  
  # 오늘 알림이 발송되었는지 확인
  def notified_today?(task_id, reminder_type)
    last_notified = Rails.cache.read("notified_task:#{task_id}:#{reminder_type}")
    return false unless last_notified
    
    last_notified.to_date == Date.current
  end
  
  # 특정 시간 내에 알림이 발송되었는지 확인
  def notified_within?(task_id, reminder_type, duration)
    last_notified = Rails.cache.read("notified_task:#{task_id}:#{reminder_type}")
    return false unless last_notified
    
    last_notified > duration.ago
  end
end