class DashboardService
  # Groupdate를 사용한 대시보드 통계
  
  def self.weekly_task_completion(team)
    return {} unless team
    
    team.tasks
        .where(completed_at: 4.weeks.ago..Time.current)
        .group_by_week(:completed_at, format: "%Y-%m-%d")
        .count
  end
  
  def self.daily_task_creation_pattern(team)
    return {} unless team
    
    # 24시간 모두에 대해 기본값 0 설정
    result = Hash.new(0)
    
    team.tasks
        .group_by_hour_of_day(:created_at, format: "%k")
        .count
        .each { |hour, count| result[hour.to_i] = count }
    
    # 0-23 시간 모두 포함
    (0..23).each { |hour| result[hour] ||= 0 }
    
    result.sort.to_h
  end
  
  def self.team_velocity_trend(team)
    return {} unless team
    
    team.sprints
        .joins(:tasks)
        .where(tasks: { status: 'completed' })
        .group_by_week('sprints.end_date')
        .sum('tasks.story_points')
  end
  
  def self.task_completion_by_member(team, period = 1.month)
    return {} unless team
    
    team.tasks
        .where(completed_at: period.ago..Time.current)
        .joins(:assignee)
        .group('users.name')
        .group_by_week(:completed_at)
        .count
  end
  
  def self.average_task_completion_time(team)
    return nil unless team
    
    completed_tasks = team.tasks.completed
    
    completion_times = completed_tasks.map do |task|
      if task.started_at && task.completed_at
        WorkingHours.working_time_between(
          task.started_at,
          task.completed_at
        ) / 1.hour.to_f
      end
    end.compact
    
    return nil if completion_times.empty?
    
    completion_times.sum / completion_times.size
  end
  
  def self.sprint_burndown_data(sprint)
    return {} unless sprint
    
    data = {}
    remaining_points = sprint.planned_points
    
    (sprint.start_date..sprint.end_date).each do |date|
      completed_on_day = sprint.tasks
                               .where(completed_at: date.beginning_of_day..date.end_of_day)
                               .sum(:story_points)
      remaining_points -= completed_on_day
      data[date] = remaining_points
    end
    
    data
  end
  
  def self.task_distribution_by_status(team)
    return {} unless team
    
    team.tasks.group(:status).count
  end
  
  def self.task_distribution_by_priority(team)
    return {} unless team
    
    team.tasks.group(:priority).count
  end
  
  def self.overdue_tasks(team)
    return [] unless team
    
    team.tasks.overdue.includes(:assignee)
  end
  
  def self.upcoming_deadlines(team, days_ahead = 7)
    return [] unless team
    
    team.tasks
        .where(deadline: Time.current..days_ahead.days.from_now)
        .where(completed_at: nil)
        .includes(:assignee)
        .order(:deadline)
  end
  
  def self.team_productivity_score(team)
    return 0 unless team
    
    completed_count = team.tasks.where(
      completed_at: 1.week.ago..Time.current
    ).count
    
    total_count = team.tasks.where(
      created_at: 1.week.ago..Time.current
    ).count
    
    return 0 if total_count == 0
    
    (completed_count.to_f / total_count * 100).round
  end
  
  def self.current_sprint_progress(team)
    return nil unless team
    
    sprint = team.sprints.current.first
    return nil unless sprint
    
    {
      name: sprint.name,
      progress: sprint.completion_percentage,
      velocity: sprint.velocity,
      days_remaining: sprint.business_days_remaining,
      burndown: sprint.burndown_chart_data
    }
  end
  
  def self.pomodoro_stats_today(user)
    return {} unless user
    
    sessions = PomodoroSession.by_user(user).today
    
    {
      total: sessions.count,
      completed: sessions.completed.count,
      interrupted: sessions.select(&:interrupted?).count,
      total_time: sessions.completed.sum { |s| s.duration || 0 } / 60.0, # in minutes
      productivity_score: calculate_pomodoro_productivity(sessions)
    }
  end
  
  def self.time_tracking_summary(team, period = 1.week)
    return {} unless team
    
    tasks = team.tasks.where(completed_at: period.ago..Time.current)
    
    {
      total_tasks: tasks.count,
      total_hours: tasks.sum { |t| t.actual_hours || 0 },
      average_hours_per_task: average_task_completion_time(team),
      on_time_completion_rate: calculate_on_time_rate(tasks),
      velocity: tasks.sum(:story_points) || 0
    }
  end
  
  private
  
  def self.calculate_pomodoro_productivity(sessions)
    return 0 if sessions.empty?
    
    completed = sessions.completed.count
    total = sessions.count
    
    (completed.to_f / total * 100).round
  end
  
  def self.calculate_on_time_rate(tasks)
    with_deadline = tasks.where.not(deadline: nil)
    return 0 if with_deadline.empty?
    
    on_time = with_deadline.select { |t| t.completed_at && t.completed_at <= t.deadline }
    
    (on_time.count.to_f / with_deadline.count * 100).round
  end
end