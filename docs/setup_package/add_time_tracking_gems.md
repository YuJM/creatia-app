# Task: 시간 추적, 포모도로 & 알림 기능을 위한 Gem 추가

## 📋 개요
Creatia 프로젝트에 시간 추적, 포모도로 타이머, 알림 기능 및 스케줄링을 위한 Ruby Gem들을 추가합니다.

## 🎯 목표
- 자연어 시간 파싱 및 날짜 처리 기능 추가
- 업무 시간 계산 및 팀별 근무 시간 관리
- 반복 일정 및 스프린트 주기 관리
- 다양한 채널을 통한 알림 시스템 구현
- 시간대 변환 및 차트/통계 기능

## 📦 추가할 Gem 정보

### 🔥 필수 추천 Gems

#### 1. Business Time ⭐⭐⭐⭐⭐ - 업무 시간 계산
- **Repository**: https://github.com/bokmann/business_time
- **최신 버전**: 0.13.0
- **용도**: 주말과 공휴일을 제외한 실제 업무 시간/일수 계산
- **활용 예시**:
```ruby
task.created_at = Time.now
task.deadline = 3.business_days.from_now
task.actual_work_hours = start_time.business_time_until(end_time)
```

#### 2. Working Hours ⭐⭐⭐⭐⭐ - 팀별 근무 시간 관리
- **Repository**: https://github.com/Intrepidd/working_hours
- **최신 버전**: 1.4.1
- **용도**: 팀별/조직별 다른 근무 시간 설정, 글로벌 팀 지원
- **활용 예시**:
```ruby
# 팀별 근무시간 설정
WorkingHours::Config.working_hours = {
  mon: {'09:00' => '18:00'},
  tue: {'09:00' => '18:00'},
  wed: {'09:00' => '18:00'},
  thu: {'09:00' => '18:00'},
  fri: {'09:00' => '17:00'}
}
WorkingHours::Config.time_zone = "Asia/Seoul"
WorkingHours::Config.holidays = [Date.new(2025, 1, 1)]

# 업무 시간 계산
2.working.hours.from_now
task_duration = WorkingHours.working_time_between(start_time, end_time)
```

#### 3. Ice Cube ⭐⭐⭐⭐ - 반복 일정 관리
- **Repository**: https://github.com/ice-cube-ruby/ice_cube
- **최신 버전**: 0.16.4
- **용도**: 스프린트 주기, 정기 회의, 반복 작업 관리
- **활용 예시**:
```ruby
# 2주 스프린트 설정
sprint_schedule = IceCube::Schedule.new(Date.today)
sprint_schedule.add_recurrence_rule(
  IceCube::Rule.weekly(2).day(:monday)
)

# 매일 스탠드업 미팅
standup = IceCube::Schedule.new(Time.now)
standup.add_recurrence_rule(
  IceCube::Rule.daily.hour_of_day(10).minute_of_hour(0)
)
```

### 💡 강력 추천 Gems

#### 4. Local Time ⭐⭐⭐⭐ - 클라이언트 시간대 변환
- **Repository**: https://github.com/basecamp/local_time
- **최신 버전**: 3.0.2
- **용도**: 사용자 브라우저 시간대로 자동 변환
- **활용 예시**:
```erb
<%= local_time(task.deadline) %>
<!-- "내일 오후 3시" 같은 친근한 표현 -->
<%= local_time_ago(task.created_at) %>
<!-- "3시간 전" -->
```

#### 5. Chronic ⭐⭐⭐ - 자연어 시간 파싱
- **Repository**: https://github.com/mojombo/chronic
- **최신 버전**: 0.10.2
- **용도**: 자연어 날짜 입력 처리
- **활용 예시**:
```ruby
task.deadline = Chronic.parse("next monday at 3pm")
reminder = Chronic.parse("in 3 hours")
meeting = Chronic.parse("tomorrow at 2:30")
```

#### 6. Groupdate ⭐⭐⭐ - 시계열 데이터 그룹화
- **Repository**: https://github.com/ankane/groupdate
- **최신 버전**: 6.4.0
- **용도**: 대시보드 차트, 통계 생성
- **활용 예시**:
```ruby
# 일별 완료 작업 수
Task.group_by_day(:completed_at).count
# => {2024-01-01 => 23, 2024-01-02 => 31, ...}

# 주별 팀 벨로시티
Task.group_by_week(:completed_at).sum(:story_points)

# 시간대별 작업 생성 패턴
Task.group_by_hour_of_day(:created_at).count
```

### 🎯 프로젝트 필수 Gems

#### 7. Noticed - 다양한 알림 채널
- **Repository**: https://github.com/excid3/noticed
- **최신 버전**: 2.x
- **용도**: 다채널 알림 시스템 (이메일, 웹소켓, Slack, SMS 등)
- **주요 기능**:
  - 다중 전송 채널 지원
  - 알림 읽음/안읽음 상태 관리
  - 조건부 알림 전송
  - 대량 알림 처리

### 🔍 선택적 고려 Gems

#### 8. Holidays - 공휴일 관리 (선택사항)
- **Repository**: https://github.com/holidays/holidays
- **용도**: 국가별 공휴일 고려한 마감일 계산
```ruby
Holidays.on(Date.today, :kr) # 한국 공휴일 확인
```

#### 9. Validates Timeliness - 날짜 유효성 검증 (선택사항)
- **Repository**: https://github.com/adzap/validates_timeliness
- **용도**: 날짜/시간 유효성 검증
```ruby
validates :start_date, timeliness: { before: :end_date }
```

## 📝 작업 내용

### 1. Gemfile 수정
```ruby
# 🔥 필수 추천 - 시간 관리 핵심 기능
gem 'business_time', '~> 0.13.0'   # 업무 시간 계산 ⭐⭐⭐⭐⭐
gem 'working_hours', '~> 1.4'      # 팀별 근무 시간 관리 ⭐⭐⭐⭐⭐
gem 'ice_cube', '~> 0.16'          # 반복 일정 관리 ⭐⭐⭐⭐

# 💡 강력 추천 - 사용자 경험 개선
gem 'local_time', '~> 3.0'         # 클라이언트 시간대 변환 ⭐⭐⭐⭐
gem 'chronic', '~> 0.10.2'         # 자연어 시간 파싱 ⭐⭐⭐
gem 'groupdate', '~> 6.4'          # 시계열 데이터 그룹화 ⭐⭐⭐

# 🎯 프로젝트 필수
gem 'noticed', '~> 2.0'            # 다채널 알림 시스템

# 🔍 선택적 고려
# gem 'holidays', '~> 8.8'         # 국가별 공휴일 관리
# gem 'validates_timeliness', '~> 7.0'  # 날짜 유효성 검증
```

### 2. Bundle 설치 및 Noticed 마이그레이션
```bash
# Gem 설치
bundle install

# Noticed 테이블 마이그레이션 생성
rails noticed:install:migrations

# 데이터베이스 마이그레이션 실행
rails db:migrate
```

### 3. 시간 관리 Gem 설정 파일 생성

#### config/business_time.yml
```yaml
business_time:
  # 업무 시작/종료 시간 설정
  beginning_of_workday: 9:00 am
  end_of_workday: 6:00 pm
  
  # 공휴일 설정 (한국 공휴일)
  holidays:
    - January 1st, 2025    # 신정
    - February 8th, 2025   # 설날 연휴
    - February 9th, 2025
    - February 10th, 2025
    - March 1st, 2025      # 삼일절
    - May 5th, 2025        # 어린이날
    - May 15th, 2025       # 부처님오신날
    - June 6th, 2025       # 현충일
    - August 15th, 2025    # 광복절
    - September 16th, 2025 # 추석 연휴
    - September 17th, 2025
    - September 18th, 2025
    - October 3rd, 2025    # 개천절
    - October 9th, 2025    # 한글날
    - December 25th, 2025  # 크리스마스
```

#### config/initializers/time_management.rb
```ruby
# Business Time 초기화 설정
BusinessTime::Config.load("#{Rails.root}/config/business_time.yml")
BusinessTime::Config.time_zone = "Asia/Seoul"
BusinessTime::Config.work_week = [:mon, :tue, :wed, :thu, :fri]

# Working Hours 초기화 설정
WorkingHours::Config.working_hours = {
  mon: {'09:00' => '18:00'},
  tue: {'09:00' => '18:00'},
  wed: {'09:00' => '18:00'},
  thu: {'09:00' => '18:00'},
  fri: {'09:00' => '18:00'}
}

WorkingHours::Config.holidays = [
  Date.new(2025, 1, 1),   # 신정
  Date.new(2025, 2, 8),   # 설날
  Date.new(2025, 2, 9),
  Date.new(2025, 2, 10),
  Date.new(2025, 3, 1),   # 삼일절
  Date.new(2025, 5, 5),   # 어린이날
  Date.new(2025, 5, 15),  # 부처님오신날
  Date.new(2025, 6, 6),   # 현충일
  Date.new(2025, 8, 15),  # 광복절
  Date.new(2025, 9, 16),  # 추석
  Date.new(2025, 9, 17),
  Date.new(2025, 9, 18),
  Date.new(2025, 10, 3),  # 개천절
  Date.new(2025, 10, 9),  # 한글날
  Date.new(2025, 12, 25)  # 크리스마스
]

WorkingHours::Config.time_zone = "Asia/Seoul"

# Chronic 설정
Chronic.time_class = Time.zone if defined?(Time.zone)

# Groupdate 설정
Groupdate.time_zone = "Asia/Seoul"
Groupdate.week_start = :monday
```

### 4. 사용 예제 모델/서비스 생성

#### app/services/time_management_service.rb
```ruby
class TimeManagementService
  # Chronic을 사용한 자연어 파싱
  def self.parse_natural_language(text, options = {})
    default_options = {
      now: Time.current,
      ambiguous_time_range: 8,
      context: :future
    }
    
    Chronic.parse(text, default_options.merge(options))
  end
  
  # Business Time을 사용한 업무 시간 계산
  def self.calculate_business_deadline(start_time, duration_in_hours)
    start_time = start_time.to_time
    duration_in_hours.business_hours.after(start_time)
  end
  
  # Working Hours를 사용한 팀별 업무 시간 계산
  def self.calculate_team_working_hours(start_time, duration_in_hours, team = nil)
    # 팀별 다른 근무 시간 적용
    if team&.custom_working_hours?
      WorkingHours::Config.with_config(
        working_hours: team.working_hours_config,
        time_zone: team.time_zone
      ) do
        duration_in_hours.working.hours.from(start_time)
      end
    else
      duration_in_hours.working.hours.from(start_time)
    end
  end
  
  # 두 시간 사이의 실제 업무 시간 계산
  def self.working_time_between(start_time, end_time)
    WorkingHours.working_time_between(start_time, end_time) / 1.hour
  end
  
  # Ice Cube를 사용한 스프린트 일정 생성
  def self.create_sprint_schedule(start_date, sprint_duration_weeks = 2)
    schedule = IceCube::Schedule.new(start_date)
    schedule.add_recurrence_rule(
      IceCube::Rule.weekly(sprint_duration_weeks).day(:monday)
    )
    schedule
  end
  
  # 다음 스프린트 시작일 계산
  def self.next_sprint_start(schedule)
    schedule.next_occurrence(Time.current)
  end
end
```

#### app/models/concerns/time_trackable.rb
```ruby
module TimeTrackable
  extend ActiveSupport::Concern
  
  included do
    # 시간 추적 필드
    # started_at: datetime
    # completed_at: datetime
    # estimated_hours: decimal
    # actual_hours: decimal
    
    # 자연어로 마감일 설정
    def set_deadline_from_natural_language(text)
      parsed_time = TimeParserService.parse_natural_language(text)
      if parsed_time
        self.deadline = parsed_time
      else
        errors.add(:deadline, "시간을 파싱할 수 없습니다: #{text}")
      end
    end
    
    # 업무 시간 기준 마감일 계산
    def calculate_business_deadline(hours_from_now)
      self.deadline = TimeParserService.calculate_business_deadline(
        Time.current,
        hours_from_now
      )
    end
    
    # 실제 소요 시간 계산 (업무 시간 기준)
    def calculate_actual_business_hours
      return nil unless started_at && completed_at
      
      # 업무 시간만 계산
      started_at.business_time_until(completed_at) / 1.hour
    end
    
    # 남은 업무일 계산
    def business_days_remaining
      return nil unless deadline
      
      if deadline > Date.current
        Date.current.business_days_until(deadline.to_date)
      else
        0
      end
    end
  end
end
```

#### app/models/sprint.rb
```ruby
class Sprint < ApplicationRecord
  belongs_to :service
  has_many :tasks
  
  serialize :schedule, IceCube::Schedule
  
  # Ice Cube를 사용한 반복 스프린트 설정
  def initialize_schedule(duration_weeks = 2)
    self.schedule = IceCube::Schedule.new(start_date) do |s|
      s.add_recurrence_rule(
        IceCube::Rule.weekly(duration_weeks).day(:monday)
      )
    end
  end
  
  # 다음 스프린트 날짜들
  def upcoming_sprints(count = 5)
    schedule.next_occurrences(count, Time.current)
  end
  
  # 현재 스프린트인지 확인
  def current?
    start_date <= Date.current && end_date >= Date.current
  end
  
  # Working Hours를 사용한 실제 작업 가능 시간
  def available_working_hours
    WorkingHours.working_time_between(
      [start_date.to_time, Time.current].max,
      end_date.to_time
    ) / 1.hour
  end
  
  # Groupdate를 사용한 일별 번다운 차트 데이터
  def burndown_chart_data
    tasks.group_by_day(:completed_at, range: start_date..end_date)
         .count
  end
  
  # 팀 벨로시티 계산
  def velocity
    tasks.completed.sum(:story_points)
  end
end
```

#### app/services/dashboard_service.rb
```ruby
class DashboardService
  # Groupdate를 사용한 대시보드 통계
  
  def self.weekly_task_completion(team)
    team.tasks
        .where(completed_at: 4.weeks.ago..Time.current)
        .group_by_week(:completed_at)
        .count
  end
  
  def self.daily_task_creation_pattern(team)
    team.tasks
        .group_by_hour_of_day(:created_at)
        .count
  end
  
  def self.team_velocity_trend(team)
    team.sprints
        .joins(:tasks)
        .where(tasks: { status: 'completed' })
        .group_by_week('sprints.end_date')
        .sum('tasks.story_points')
  end
  
  def self.task_completion_by_member(team, period = 1.month)
    team.tasks
        .where(completed_at: period.ago..Time.current)
        .joins(:assignee)
        .group('users.name')
        .group_by_week(:completed_at)
        .count
  end
  
  def self.average_task_completion_time(team)
    completed_tasks = team.tasks.completed
    
    completion_times = completed_tasks.map do |task|
      if task.started_at && task.completed_at
        WorkingHours.working_time_between(
          task.started_at,
          task.completed_at
        ) / 1.hour
      end
    end.compact
    
    completion_times.sum / completion_times.size if completion_times.any?
  end
end
```

### 5. 포모도로 타이머 모델 예제

#### app/models/pomodoro_session.rb
```ruby
class PomodoroSession < ApplicationRecord
  belongs_to :task
  belongs_to :user
  
  # 포모도로 설정
  WORK_DURATION = 25.minutes
  SHORT_BREAK = 5.minutes
  LONG_BREAK = 15.minutes
  SESSIONS_BEFORE_LONG_BREAK = 4
  
  enum status: {
    pending: 0,
    in_progress: 1,
    completed: 2,
    cancelled: 3
  }
  
  # 다음 세션 시작 시간 계산 (업무 시간 내에서만)
  def next_session_start_time
    if during_business_hours?
      Time.current + break_duration
    else
      next_business_day_start
    end
  end
  
  private
  
  def during_business_hours?
    Time.current.workday? && Time.current.during_business_hours?
  end
  
  def next_business_day_start
    1.business_day.from_now.change(
      hour: BusinessTime::Config.beginning_of_workday.hour,
      min: BusinessTime::Config.beginning_of_workday.min
    )
  end
  
  def break_duration
    session_count % SESSIONS_BEFORE_LONG_BREAK == 0 ? LONG_BREAK : SHORT_BREAK
  end
end
```

### 6. Noticed 알림 시스템 구현

#### app/notifiers/task_reminder_notifier.rb
```ruby
class TaskReminderNotifier < Noticed::Event
  # 다양한 채널로 알림 전송
  deliver_by :action_cable do |config|
    config.channel = "NotificationsChannel"
    config.stream = -> { recipient }
    config.message = -> { 
      {
        title: "작업 알림",
        body: params[:message],
        url: task_path(record)
      }
    }
  end
  
  deliver_by :email do |config|
    config.mailer = "TaskMailer"
    config.method = :reminder
    config.wait = 5.minutes  # 5분 후 이메일 전송
    config.if = -> { recipient.email_notifications? }
  end
  
  # Slack 알림 (선택사항)
  deliver_by :slack do |config|
    config.url = -> { Rails.application.credentials.slack[:webhook_url] }
    config.json = -> {
      {
        text: "📋 작업 알림: #{params[:message]}",
        blocks: [
          {
            type: "section",
            text: {
              type: "mrkdwn",
              text: "*#{record.title}*\n#{params[:message]}"
            }
          },
          {
            type: "actions",
            elements: [
              {
                type: "button",
                text: { type: "plain_text", text: "작업 보기" },
                url: task_url(record)
              }
            ]
          }
        ]
      }
    }
  end
  
  # 알림 메시지 헬퍼 메서드
  notification_methods do
    def message
      params[:message] || "작업 마감일이 다가왔습니다: #{record.title}"
    end
    
    def url
      task_url(record)
    end
  end
  
  # 필수 파라미터 정의
  required_param :message
end
```

#### app/notifiers/pomodoro_notifier.rb
```ruby
class PomodoroNotifier < Noticed::Event
  # 포모도로 세션 알림
  deliver_by :action_cable do |config|
    config.channel = "PomodoroChannel"
    config.stream = -> { recipient }
    config.message = -> { 
      {
        type: params[:type], # start, break, complete
        session_id: record.id,
        next_action: params[:next_action],
        timestamp: Time.current
      }
    }
  end
  
  # 브라우저 푸시 알림 (선택사항)
  deliver_by :web_push do |config|
    config.if = -> { recipient.web_push_enabled? }
    config.json = -> {
      {
        title: notification_title,
        body: notification_body,
        icon: "/icons/pomodoro.png",
        badge: "/icons/badge.png",
        vibrate: [200, 100, 200],
        data: {
          session_id: record.id,
          type: params[:type]
        }
      }
    }
  end
  
  notification_methods do
    def notification_title
      case params[:type]
      when "start"
        "🍅 포모도로 시작!"
      when "break"
        "☕ 휴식 시간입니다"
      when "complete"
        "✅ 포모도로 완료!"
      else
        "포모도로 타이머"
      end
    end
    
    def notification_body
      case params[:type]
      when "start"
        "25분간 집중하세요!"
      when "break"
        params[:break_type] == "long" ? "15분간 휴식하세요" : "5분간 휴식하세요"
      when "complete"
        "#{record.task.title} 작업을 완료했습니다"
      else
        "포모도로 세션 업데이트"
      end
    end
  end
end
```

#### app/models/user.rb (알림 관련 추가)
```ruby
class User < ApplicationRecord
  # Noticed 알림 연관관계
  has_many :notifications, as: :recipient, dependent: :destroy, class_name: "Noticed::Notification"
  
  # 알림 토큰 (모바일/웹 푸시용)
  has_many :notification_tokens, dependent: :destroy
  
  # 알림 설정
  def email_notifications?
    notification_preferences&.dig("email") != false
  end
  
  def web_push_enabled?
    notification_tokens.where(platform: "web_push").exists?
  end
  
  # 읽지 않은 알림 수
  def unread_notifications_count
    notifications.unread.count
  end
end
```

#### app/services/notification_service.rb
```ruby
class NotificationService
  # 작업 마감일 알림 전송
  def self.send_task_deadline_reminder(task)
    return unless task.deadline.present?
    
    # 마감 1시간 전 알림
    if task.deadline.between?(1.hour.from_now, 1.hour.from_now + 5.minutes)
      TaskReminderNotifier.with(
        record: task,
        message: "⏰ 마감 1시간 전입니다!"
      ).deliver(task.assignee)
    end
    
    # 마감일 당일 오전 9시 알림
    if task.deadline.to_date == Date.current && Time.current.hour == 9
      TaskReminderNotifier.with(
        record: task,
        message: "📅 오늘이 마감일입니다!"
      ).deliver(task.assignee)
    end
  end
  
  # 포모도로 세션 알림
  def self.send_pomodoro_notification(session, type)
    PomodoroNotifier.with(
      record: session,
      type: type,
      next_action: determine_next_action(session, type),
      break_type: determine_break_type(session)
    ).deliver(session.user)
  end
  
  private
  
  def self.determine_next_action(session, type)
    case type
    when "start"
      "25분 동안 집중하세요"
    when "break"
      session.session_count % 4 == 0 ? "15분 휴식" : "5분 휴식"
    when "complete"
      "다음 세션을 시작하거나 작업을 마무리하세요"
    end
  end
  
  def self.determine_break_type(session)
    session.session_count % 4 == 0 ? "long" : "short"
  end
end
```

#### app/controllers/notifications_controller.rb
```ruby
class NotificationsController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @notifications = current_user.notifications
                                  .includes(:event)
                                  .newest_first
                                  .page(params[:page])
  end
  
  def mark_as_read
    @notification = current_user.notifications.find(params[:id])
    @notification.mark_as_read!
    
    respond_to do |format|
      format.turbo_stream
      format.json { render json: { read: true } }
    end
  end
  
  def mark_all_as_read
    current_user.notifications.unread.mark_as_read
    
    respond_to do |format|
      format.turbo_stream
      format.json { render json: { marked_count: current_user.notifications.unread.count } }
    end
  end
end
```

#### app/views/notifications/_notification.html.erb
```erb
<div class="notification <%= 'unread' unless notification.read? %>" 
     data-notification-id="<%= notification.id %>">
  <div class="notification-icon">
    <%= heroicon notification_icon(notification), options: { class: "w-6 h-6" } %>
  </div>
  
  <div class="notification-content">
    <div class="notification-message">
      <%= notification.message %>
    </div>
    <div class="notification-time">
      <%= time_ago_in_words(notification.created_at) %> 전
    </div>
  </div>
  
  <% unless notification.read? %>
    <%= button_to "읽음", 
                  mark_as_read_notification_path(notification),
                  method: :patch,
                  data: { turbo_method: :patch },
                  class: "btn-sm" %>
  <% end %>
</div>
```

### 7. View Helper 추가

#### app/helpers/time_helper.rb
```ruby
module TimeHelper
  # Local Time을 사용한 사용자 친화적 시간 표시
  def user_friendly_time(time)
    return if time.blank?
    
    content_tag :time, 
                local_time_ago(time),
                data: { 
                  local: "time-ago",
                  format: "%B %e, %Y %l:%M%P"
                },
                title: local_time(time)
  end
  
  # 마감일까지 남은 시간 표시
  def time_until_deadline(deadline)
    return if deadline.blank?
    
    if deadline.past?
      content_tag :span, "기한 초과", class: "text-red-500"
    elsif deadline.today?
      content_tag :span, "오늘 마감", class: "text-orange-500"
    elsif deadline.tomorrow?
      content_tag :span, "내일 마감", class: "text-yellow-500"
    else
      working_hours = WorkingHours.working_time_between(
        Time.current,
        deadline
      ) / 1.hour
      
      content_tag :span, 
                  "#{working_hours.round}시간 (업무시간 기준)",
                  class: "text-gray-600"
    end
  end
  
  # 업무 시간 표시
  def format_working_hours(hours)
    return "0시간" if hours.nil? || hours.zero?
    
    days = (hours / 8).floor
    remaining_hours = (hours % 8).round(1)
    
    parts = []
    parts << "#{days}일" if days > 0
    parts << "#{remaining_hours}시간" if remaining_hours > 0
    
    parts.join(" ")
  end
  
  # 스프린트 진행 상태 표시
  def sprint_progress(sprint)
    return if sprint.blank?
    
    total_days = (sprint.end_date - sprint.start_date).to_i
    elapsed_days = (Date.current - sprint.start_date).to_i
    progress = (elapsed_days.to_f / total_days * 100).round
    
    content_tag :div, class: "w-full" do
      concat content_tag(:div, "#{progress}%", class: "text-sm text-gray-600")
      concat(
        content_tag :div, class: "w-full bg-gray-200 rounded-full h-2" do
          content_tag :div, "", 
                      class: "bg-blue-600 h-2 rounded-full",
                      style: "width: #{progress}%"
        end
      )
    end
  end
end
```

#### app/views/tasks/_form.html.erb (예제)
```erb
<%= form_with model: task do |form| %>
  <!-- 자연어 마감일 입력 -->
  <div class="field">
    <%= form.label :deadline_text, "마감일" %>
    <%= form.text_field :deadline_text, 
                        placeholder: "예: 다음 주 월요일, 3일 후, tomorrow at 3pm",
                        class: "form-input" %>
    <small class="text-gray-500">
      자연어로 입력하실 수 있습니다
    </small>
  </div>
  
  <!-- 예상 소요 시간 -->
  <div class="field">
    <%= form.label :estimated_hours, "예상 소요 시간" %>
    <%= form.number_field :estimated_hours, 
                          step: 0.5,
                          placeholder: "업무 시간 기준",
                          class: "form-input" %>
    <small class="text-gray-500">
      실제 업무 가능 시간: 
      <%= format_working_hours(8) %> / 일
    </small>
  </div>
<% end %>
```

#### app/views/dashboards/show.html.erb (차트 예제)
```erb
<div class="dashboard">
  <!-- 주간 작업 완료 차트 -->
  <div class="chart-container">
    <h3>주간 작업 완료 현황</h3>
    <%= line_chart DashboardService.weekly_task_completion(current_team),
                   height: "300px",
                   library: {
                     scales: {
                       x: { 
                         type: 'time',
                         time: { 
                           unit: 'week',
                           displayFormats: { week: 'MMM DD' }
                         }
                       }
                     }
                   } %>
  </div>
  
  <!-- 시간대별 작업 생성 패턴 -->
  <div class="chart-container">
    <h3>시간대별 작업 생성 패턴</h3>
    <%= column_chart DashboardService.daily_task_creation_pattern(current_team),
                     height: "300px",
                     xtitle: "시간",
                     ytitle: "작업 수" %>
  </div>
  
  <!-- 팀 벨로시티 트렌드 -->
  <div class="chart-container">
    <h3>스프린트별 팀 벨로시티</h3>
    <%= area_chart DashboardService.team_velocity_trend(current_team),
                   height: "300px",
                   colors: ["#4F46E5"] %>
  </div>
</div>
```

### 8. 테스트 코드 작성

#### test/services/time_parser_service_test.rb
```ruby
require 'test_helper'

class TimeParserServiceTest < ActiveSupport::TestCase
  test "자연어 시간 파싱" do
    # "내일"을 파싱
    result = TimeParserService.parse_natural_language("tomorrow at 3pm")
    assert_not_nil result
    assert_equal 15, result.hour
    
    # "3일 후"를 파싱
    result = TimeParserService.parse_natural_language("in 3 days")
    assert_not_nil result
    assert_equal 3.days.from_now.to_date, result.to_date
  end
  
  test "업무 시간 계산" do
    # 금요일 오후 5시에서 2 업무 시간 후는 월요일 오전 10시
    friday_5pm = Time.parse("2025-01-24 17:00:00")
    result = TimeParserService.calculate_business_deadline(friday_5pm, 2)
    
    # 월요일 오전 10시가 되어야 함
    assert_equal 1, result.wday # Monday
    assert_equal 10, result.hour
  end
  
  test "업무일 계산" do
    # 금요일부터 다음 월요일까지는 1 업무일
    friday = Date.parse("2025-01-24")
    monday = Date.parse("2025-01-27")
    
    days = TimeParserService.business_days_between(friday, monday)
    assert_equal 1, days
  end
end
```

#### test/notifiers/task_reminder_notifier_test.rb
```ruby
require 'test_helper'

class TaskReminderNotifierTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @task = tasks(:one)
  end
  
  test "작업 알림 생성" do
    assert_difference 'Noticed::Event.count' do
      TaskReminderNotifier.with(
        record: @task,
        message: "테스트 알림"
      ).deliver(@user)
    end
  end
  
  test "조건부 이메일 전송" do
    @user.update(notification_preferences: { email: true })
    
    notifier = TaskReminderNotifier.with(
      record: @task,
      message: "이메일 알림"
    )
    
    assert notifier.deliver(@user)
  end
end
```

### 8. Background Job 설정 (Solid Queue - Rails 8 기본)

#### app/jobs/notification_scheduler_job.rb
```ruby
class NotificationSchedulerJob < ApplicationJob
  queue_as :default
  
  def perform
    # 마감일이 다가오는 작업들 확인
    check_upcoming_deadlines
    
    # 진행 중인 포모도로 세션 확인
    check_pomodoro_sessions
  end
  
  private
  
  def check_upcoming_deadlines
    # 1시간 이내 마감 작업
    Task.where(deadline: 1.hour.from_now..1.hour.from_now + 10.minutes)
        .find_each do |task|
      NotificationService.send_task_deadline_reminder(task)
    end
    
    # 오늘 마감 작업 (오전 9시에만)
    if Time.current.hour == 9
      Task.where(deadline: Date.current.beginning_of_day..Date.current.end_of_day)
          .find_each do |task|
        NotificationService.send_task_deadline_reminder(task)
      end
    end
  end
  
  def check_pomodoro_sessions
    # 완료 시간이 된 포모도로 세션
    PomodoroSession.in_progress
                   .where("started_at + interval '25 minutes' <= ?", Time.current)
                   .find_each do |session|
      session.complete!
      NotificationService.send_pomodoro_notification(session, "complete")
    end
  end
end
```

#### config/recurring.yml (Solid Queue)
```yaml
production:
  notification_scheduler:
    class: NotificationSchedulerJob
    schedule: every 5 minutes
    queue: default
    
development:
  notification_scheduler:
    class: NotificationSchedulerJob
    schedule: every 5 minutes
    queue: default
```

## 🚀 Background Job 실행 방법

### Rails 8 Solid Queue (기본)
```bash
# 개발 환경 - Solid Queue는 자동으로 실행됨
bin/dev  # Rails 서버와 함께 자동 시작

# 별도로 실행하려면
bin/jobs  # Solid Queue worker 실행

# Mission Control UI 확인
# 브라우저에서 http://localhost:3000/mission_control 접속
```

### Procfile.dev (Rails 8 기본 설정)
```yaml
web: bin/rails server -p 3000
css: bin/rails tailwindcss:watch
jobs: bin/jobs
```

## ✅ 완료 조건

- [ ] Gemfile에 시간 관리 및 알림 gem 추가 (business_time, working_hours, ice_cube, local_time, chronic, groupdate, noticed)
- [ ] Bundle install 성공
- [ ] 데이터베이스 마이그레이션 실행
- [ ] Noticed 마이그레이션 실행
- [ ] Business Time 설정 파일 생성
- [ ] Working Hours 설정 파일 생성
- [ ] TimeParserService 구현
- [ ] TimeTrackable concern 구현
- [ ] PomodoroSession 모델 구현
- [ ] Noticed Notifier 클래스 구현
- [ ] Background Job 클래스 구현
- [ ] NotificationService 구현
- [ ] NotificationsController 구현
- [ ] 알림 뷰 템플릿 생성
- [ ] Mission Control 라우트 확인
- [ ] Background Job 설정 (Solid Queue)
- [ ] 테스트 코드 작성 및 통과
- [ ] Solid Queue 실행 확인

## 🔍 참고 자료

- [Chronic GitHub](https://github.com/mojombo/chronic)
- [Business Time GitHub](https://github.com/bokmann/business_time)
- [Noticed GitHub](https://github.com/excid3/noticed)
- [Solid Queue GitHub](https://github.com/rails/solid_queue)
- [Working Hours GitHub](https://github.com/Intrepidd/working_hours)
- [Ice Cube GitHub](https://github.com/ice-cube-ruby/ice_cube)
- [Local Time GitHub](https://github.com/basecamp/local_time)
- [Groupdate GitHub](https://github.com/ankane/groupdate)
- [Chronic 사용 예제](https://www.rubyinrails.com/2018/06/03/ruby-chronic-gem-parse-datetime-in-natural-language/)
- [Business Time 문서](https://www.rubydoc.info/gems/business_time)
- [Noticed v2 GoRails 강좌](https://gorails.com/episodes/noticed-v2)
- [Rails 8 Background Jobs Guide](https://guides.rubyonrails.org/active_job_basics.html)

## 📅 예상 작업 시간
- 5-6시간 (시간 관리 gem 및 Background Job 설정 포함)

## 🔧 Rails 8 Background Job 시스템

### Solid Queue (Rails 8 기본)
Rails 8부터는 Solid Queue가 기본 백그라운드 작업 시스템으로 제공됩니다.

**특징**:
- 데이터베이스 기반 (Redis 불필요)
- Rails와 완전 통합
- Mission Control UI 제공
- 개발 환경에서 자동 실행
- 프로덕션 확장 가능

**설정**:
```ruby
# config/solid_queue.yml 에서 큐와 worker 설정
# config/database.yml 에서 queue 데이터베이스 설정
# bin/jobs 스크립트로 실행
```

### Active Job 통합
모든 Background Job은 Active Job을 통해 실행되므로, 필요시 다른 백엔드로 쉽게 전환 가능합니다.

## 🚀 다음 단계
1. Task 모델에 TimeTrackable concern 적용
2. 포모도로 타이머 UI 구현 (Stimulus)
3. 실시간 알림 UI 구현 (ActionCable)
4. 알림 설정 페이지 구현
5. 시간 추적 대시보드 구현
6. 리포트 기능 추가
7. 추가 알림 채널 구현 (SMS, Push 등)

## 💡 추가 기능 아이디어

### 고급 알림 기능
- **알림 그룹화**: 비슷한 알림들을 그룹으로 묶어서 표시
- **알림 스누즈**: 나중에 다시 알림 받기
- **알림 우선순위**: 중요도에 따른 알림 분류
- **Do Not Disturb**: 특정 시간대 알림 차단

### 포모도로 확장 기능
- **포모도로 통계**: 일/주/월별 완료한 포모도로 수
- **집중도 분석**: 가장 생산적인 시간대 분석
- **팀 포모도로**: 팀원들과 함께하는 포모도로 세션
- **포모도로 목표**: 일일 포모도로 목표 설정

### 시간 추적 고도화
- **자동 시간 추적**: 작업 시작/종료 자동 감지
- **시간 추적 리포트**: 프로젝트별, 태스크별 시간 분석
- **시간 예측**: 과거 데이터 기반 작업 시간 예측
- **오버타임 알림**: 예상 시간 초과 시 알림