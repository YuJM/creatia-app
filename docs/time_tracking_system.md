# 시간 추적 시스템 (Time Tracking System)

## 개요
Creatia 앱의 포괄적인 시간 추적 및 생산성 관리 시스템입니다. BDD 방식으로 개발되었으며, 여러 Ruby gem을 활용하여 강력한 기능을 제공합니다.

## 주요 기능

### 1. 시간 추적 (TimeTrackable Concern)
모든 작업에 적용 가능한 시간 추적 기능을 제공합니다.

#### 기능
- 마감일 관리 및 알림
- 자연어 시간 입력 (한국어 지원)
- 업무 시간 기준 계산
- 긴급도 레벨 자동 계산

#### 사용 예시
```ruby
task = Task.new
task.set_deadline_from_natural_language("내일 오후 3시")
task.business_hours_until_deadline  # => 8.5
task.urgency_level  # => :high
```

### 2. 스프린트 관리 (Sprint Model)

#### 유연한 시간 관리
- 팀별 커스텀 근무 시간 설정
- 주말 근무 옵션
- 유연 근무제 지원
- 스크럼 이벤트 자동 스케줄링

#### 프리셋
- **Standard**: 9-18시 표준 근무
- **Startup**: 10-20시, 주말 가능
- **Remote**: 7-22시 유연 근무
- **Global**: 6-23시, 시차 고려
- **Crunch**: 8-22시, 집중 개발

#### 고급 분석 기능
```ruby
sprint.burndown_chart_data  # 번다운 차트 데이터
sprint.team_contribution_data  # 팀원별 기여도
sprint.optimal_working_hours_analysis  # 생산성 최적 시간대
```

### 3. 포모도로 세션 (PomodoroSession)

#### 기능
- 25분 작업 / 5분 휴식 사이클
- 4세션 후 15분 긴 휴식
- 일시정지/재개 기능
- 생산성 점수 계산

#### 분석 기능
```ruby
PomodoroSession.optimal_pomodoro_times(user)
# => 최적 작업 시간대 추천

PomodoroSession.business_hours_ratio
# => 업무시간 내 세션 비율
```

### 4. 알림 시스템 (Noticed Gem)

#### 알림 종류
- **TaskReminderNotifier**: 작업 마감일 알림
- **SprintNotifier**: 스프린트 이벤트 알림
- **DeadlineApproachingNotifier**: 지능형 마감일 알림
- **PomodoroNotifier**: 포모도로 세션 알림

#### 전달 채널
- ActionCable (실시간)
- Email
- Slack
- Microsoft Teams
- Web Push
- SMS (긴급)

### 5. 대시보드 서비스 (DashboardService)

일일, 주간, 월간 대시보드 데이터를 제공합니다:
- 완료/진행중 작업
- 다가오는 마감일
- 포모도로 세션 통계
- 팀 생산성 지표

## 사용된 Gem 패키지

### business_time (0.13.0)
- 업무일/시간 계산
- 한국 공휴일 설정
- SLA 마감일 계산

### working_hours (1.4)
- 팀별 근무 시간 설정
- 실제 업무 시간 계산

### ice_cube (0.17)
- 반복 스프린트 스케줄
- 스크럼 이벤트 반복

### chronic (0.10.2)
- 자연어 시간 파싱
- 한국어 지원 (ChronicKorean)

### local_time (3.0)
- 클라이언트 시간대 자동 변환
- 사용자 친화적 시간 표시

### groupdate (6.6)
- 시계열 데이터 분석
- 생산성 패턴 분석
- 번다운 차트 생성

### noticed (2.5)
- 다중 채널 알림
- 지능형 알림 규칙
- 알림 히스토리 관리

## 설치 및 설정

### 1. 마이그레이션 실행
```bash
bin/rails db:migrate
```

### 2. 초기 설정
```ruby
# config/initializers/business_time.rb
BusinessTime::Config.beginning_of_workday = "9:00 am"
BusinessTime::Config.end_of_workday = "6:00 pm"

# config/initializers/working_hours.rb
WorkingHours::Config.working_hours = {
  mon: {'09:00' => '18:00'},
  tue: {'09:00' => '18:00'},
  # ...
}
```

### 3. 백그라운드 작업 설정
```bash
bin/rails solid_queue:start
```

## 테스트

RSpec을 사용한 BDD 테스트:

```bash
# 모든 테스트 실행
bundle exec rspec

# 특정 모델 테스트
bundle exec rspec spec/models/sprint_spec.rb
```

## API 사용 예시

### 스프린트 생성 및 설정
```ruby
sprint = Sprint.create(
  name: "Sprint 23",
  start_date: Date.today,
  end_date: 2.weeks.from_now,
  service: service
)

# 유연한 시간 설정
sprint.apply_schedule_preset(:startup)

# 커스텀 스케줄
sprint.set_team_schedule(
  monday: { start: "10:00", end: "19:00" },
  friday: { start: "09:00", end: "15:00" }
)
```

### 작업 시간 추적
```ruby
task = Task.create(
  title: "새 기능 개발",
  deadline: 3.business_days.from_now
)

# 자연어로 마감일 설정
task.set_deadline_from_natural_language("다음주 월요일")

# 포모도로 세션 시작
session = task.pomodoro_sessions.create(user: current_user)
session.start!
```

### 알림 전송
```ruby
# 마감일 알림
TaskReminderNotifier.with(
  task: task,
  reminder_type: :one_hour
).deliver(task.assignee)

# 스프린트 시작 알림
SprintNotifier.with(
  sprint: sprint,
  event_type: :starting
).deliver(sprint.users)
```

## 주요 개선사항 (2025-08-28)

1. **한국어 지원 강화**
   - Chronic gem에 ChronicKorean 모듈 추가
   - "내일 오후 3시", "다음주 월요일" 등 자연어 입력

2. **유연한 스프린트 시간**
   - 팀별 다른 근무 시간 설정 가능
   - 주말 근무 옵션
   - 스크럼 이벤트 자동 스케줄링

3. **고급 데이터 분석**
   - Groupdate를 활용한 시계열 분석
   - 생산성 패턴 분석
   - 최적 작업 시간대 추천

4. **지능형 알림 시스템**
   - 긴급도 기반 알림
   - 다중 채널 지원
   - 상황별 스마트 제안

5. **Business Time 최적화**
   - 한국 공휴일 2024년 설정
   - 점심시간 제외 옵션
   - SLA 마감일 계산