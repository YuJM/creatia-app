# DailyTaskReminderJob - 일일 작업 알림
#
# 매일 오전 9시에 실행되어 오늘 마감인 작업들을 알림
#
class DailyTaskReminderJob < ApplicationJob
  queue_as :notifications
  
  def perform
    User.active.find_each do |user|
      tasks_due_today = user.tasks
        .not_completed
        .where(deadline: Time.current.beginning_of_day..Time.current.end_of_day)
        .order(:deadline)
      
      next if tasks_due_today.empty?
      
      # 각 사용자에게 오늘의 작업 목록 알림
      tasks_due_today.each do |task|
        TaskReminderNotifier.with(
          task: task,
          reminder_type: :today
        ).deliver(user)
      end
      
      # 요약 메시지 전송
      send_daily_summary(user, tasks_due_today)
    end
  end
  
  private
  
  def send_daily_summary(user, tasks)
    ActionCable.server.broadcast(
      "user_#{user.id}",
      {
        type: "daily_summary",
        date: Date.current.to_s,
        total_tasks: tasks.count,
        high_priority: tasks.where(priority: :high).count,
        tasks: tasks.map { |t| serialize_task(t) },
        message: daily_message(tasks.count)
      }
    )
  end
  
  def serialize_task(task)
    {
      id: task.id,
      title: task.title,
      deadline: task.deadline,
      priority: task.priority,
      estimated_hours: task.estimated_hours,
      urgency_level: task.urgency_level
    }
  end
  
  def daily_message(count)
    case count
    when 1
      "오늘 완료해야 할 작업이 1개 있습니다. 화이팅! 💪"
    when 2..3
      "오늘 #{count}개의 작업이 있습니다. 하나씩 차근차근 해결해보세요! 🎯"
    when 4..5
      "오늘 #{count}개의 작업이 예정되어 있습니다. 우선순위를 정해서 진행하세요. 📋"
    else
      "오늘 #{count}개의 작업이 있습니다. 포모도로 타이머를 활용해보세요! 🍅"
    end
  end
end