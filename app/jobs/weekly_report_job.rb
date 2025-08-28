# WeeklyReportJob - 주간 생산성 리포트 생성
#
# 매주 월요일 오전 8시에 실행되어 지난 주의 생산성 리포트를 생성
#
class WeeklyReportJob < ApplicationJob
  queue_as :reports
  
  def perform
    Organization.active.find_each do |organization|
      ActsAsTenant.with_tenant(organization) do
        generate_organization_report(organization)
      end
    end
  end
  
  private
  
  def generate_organization_report(organization)
    organization.users.active.find_each do |user|
      report_data = collect_user_metrics(user)
      
      # 리포트 생성 및 저장
      report = WeeklyReport.create!(
        user: user,
        organization: organization,
        week_start: 1.week.ago.beginning_of_week,
        week_end: 1.week.ago.end_of_week,
        data: report_data
      )
      
      # 알림 발송
      send_report_notification(user, report)
    end
  end
  
  def collect_user_metrics(user)
    {
      tasks: {
        completed: user.tasks.where(completed_at: 1.week.ago.beginning_of_week..1.week.ago.end_of_week).count,
        created: user.tasks.where(created_at: 1.week.ago.beginning_of_week..1.week.ago.end_of_week).count,
        overdue: user.tasks.not_completed.where(deadline: ...1.week.ago.end_of_week).count,
        completion_rate: calculate_completion_rate(user)
      },
      pomodoro: {
        total_sessions: user.pomodoro_sessions.last_week.count,
        completed_sessions: user.pomodoro_sessions.last_week.completed.count,
        total_focus_time: user.pomodoro_sessions.last_week.completed.count * 25,
        daily_average: (user.pomodoro_sessions.last_week.completed.count / 5.0).round(1),
        best_day: find_best_pomodoro_day(user)
      },
      productivity: {
        score: calculate_productivity_score(user),
        trend: calculate_trend(user),
        peak_hours: find_peak_productivity_hours(user)
      },
      sprints: {
        velocity: calculate_velocity(user),
        tasks_per_sprint: calculate_average_tasks_per_sprint(user)
      }
    }
  end
  
  def calculate_completion_rate(user)
    total = user.tasks.where(created_at: 1.week.ago.beginning_of_week..1.week.ago.end_of_week).count
    return 0 if total.zero?
    
    completed = user.tasks.where(
      created_at: 1.week.ago.beginning_of_week..1.week.ago.end_of_week,
      completed_at: 1.week.ago.beginning_of_week..1.week.ago.end_of_week
    ).count
    
    ((completed.to_f / total) * 100).round(1)
  end
  
  def calculate_productivity_score(user)
    # 복합 생산성 점수 계산
    task_score = calculate_completion_rate(user) * 0.4
    pomodoro_score = calculate_pomodoro_effectiveness(user) * 0.3
    deadline_score = calculate_deadline_adherence(user) * 0.3
    
    (task_score + pomodoro_score + deadline_score).round(1)
  end
  
  def calculate_pomodoro_effectiveness(user)
    total = user.pomodoro_sessions.last_week.count
    return 0 if total.zero?
    
    completed = user.pomodoro_sessions.last_week.completed.count
    ((completed.to_f / total) * 100)
  end
  
  def calculate_deadline_adherence(user)
    tasks_with_deadline = user.tasks
      .where(deadline: 1.week.ago.beginning_of_week..1.week.ago.end_of_week)
    
    return 100 if tasks_with_deadline.empty?
    
    on_time = tasks_with_deadline.where('completed_at <= deadline').count
    ((on_time.to_f / tasks_with_deadline.count) * 100)
  end
  
  def calculate_trend(user)
    current_score = calculate_productivity_score(user)
    
    # 이전 주 점수 계산 (간단한 구현)
    previous_score = Rails.cache.fetch("user_productivity_score:#{user.id}:previous", expires_in: 1.week) do
      current_score
    end
    
    # 현재 점수 캐싱
    Rails.cache.write("user_productivity_score:#{user.id}:previous", current_score, expires_in: 1.week)
    
    if current_score > previous_score + 5
      :improving
    elsif current_score < previous_score - 5
      :declining
    else
      :stable
    end
  end
  
  def find_peak_productivity_hours(user)
    # 포모도로 세션 시작 시간 기준으로 가장 생산적인 시간대 찾기
    sessions_by_hour = user.pomodoro_sessions.last_week.completed
      .group_by { |s| s.started_at.hour }
      .transform_values(&:count)
    
    return [] if sessions_by_hour.empty?
    
    max_count = sessions_by_hour.values.max
    sessions_by_hour.select { |_, count| count == max_count }.keys.sort
  end
  
  def find_best_pomodoro_day(user)
    sessions_by_day = user.pomodoro_sessions.last_week.completed
      .group_by { |s| s.started_at.to_date }
      .transform_values(&:count)
    
    return nil if sessions_by_day.empty?
    
    best_date = sessions_by_day.max_by { |_, count| count }&.first
    best_date&.strftime('%A') # 요일 이름 반환
  end
  
  def calculate_velocity(user)
    # 스프린트 속도 계산
    completed_sprints = user.sprints.completed.last(3)
    return 0 if completed_sprints.empty?
    
    total_points = completed_sprints.sum { |s| s.tasks.completed.sum(&:story_points) }
    (total_points / completed_sprints.count.to_f).round(1)
  end
  
  def calculate_average_tasks_per_sprint(user)
    sprints = user.sprints.last(3)
    return 0 if sprints.empty?
    
    total_tasks = sprints.sum { |s| s.tasks.count }
    (total_tasks / sprints.count.to_f).round(1)
  end
  
  def send_report_notification(user, report)
    WeeklyReportNotifier.with(
      report: report,
      user: user
    ).deliver(user)
  end
end

# WeeklyReport 모델 (간단한 구현)
class WeeklyReport < ApplicationRecord
  belongs_to :user
  belongs_to :organization
  
  validates :week_start, :week_end, :data, presence: true
end