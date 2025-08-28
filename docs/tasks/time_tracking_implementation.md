# Task: Time Tracking & Notification System Implementation

## 🎯 Epic: Time Management System

### 목표
Creatia 프로젝트 관리 시스템에 시간 추적, 포모도로 타이머, 알림 시스템을 구현합니다.

### 관련 구조
- **Service**: CORE (핵심 기능)
- **Milestone**: MVP Release
- **Epic Label**: 🕰️ Time Tracking System
- **Sprint**: Time Management Sprint

---

## 📋 Tasks (BDD Approach)

### CORE-001: Time Trackable Concern 구현
**Priority**: High
**Assignee**: Backend
**Status**: Pending
**Story Points**: 3

#### User Story
```
As a team member
I want to track time spent on tasks
So that I can measure my productivity and report accurate work hours
```

#### Acceptance Criteria
- [ ] Task에 시작/종료 시간 기록 가능
- [ ] 자연어로 마감일 설정 가능 ("내일 오후 3시", "3일 후")
- [ ] 업무 시간 기준 소요 시간 계산
- [ ] 남은 업무일 계산

#### Technical Tasks
1. Create TimeTrackable concern
2. Add time tracking fields to Task model migration
3. Implement natural language parsing with Chronic
4. Add business time calculations

#### Test Scenarios (RSpec)
```ruby
# spec/models/concerns/time_trackable_spec.rb
RSpec.describe TimeTrackable do
  describe '#set_deadline_from_natural_language' do
    it 'parses "tomorrow at 3pm" correctly'
    it 'handles Korean natural language input'
    it 'returns error for unparseable text'
  end

  describe '#calculate_actual_business_hours' do
    it 'excludes weekends from calculation'
    it 'excludes holidays from calculation'
    it 'returns nil when not completed'
  end
end
```

---

### CORE-002: Sprint Model 구현
**Priority**: High
**Assignee**: Backend
**Status**: Pending
**Story Points**: 5

#### User Story
```
As a project manager
I want to manage sprints with recurring schedules
So that I can plan and track team velocity
```

#### Acceptance Criteria
- [ ] 2주 단위 Sprint 자동 생성
- [ ] Sprint 벨로시티 계산
- [ ] 번다운 차트 데이터 제공
- [ ] Ice Cube를 사용한 반복 일정 관리

#### Technical Tasks
1. Generate Sprint model and migration
2. Implement IceCube schedule integration
3. Add velocity calculation methods
4. Create burndown chart data methods

#### Test Scenarios (RSpec)
```ruby
# spec/models/sprint_spec.rb
RSpec.describe Sprint do
  describe '#initialize_schedule' do
    it 'creates recurring 2-week sprints'
    it 'starts on Monday'
  end

  describe '#velocity' do
    it 'calculates sum of completed story points'
    it 'excludes incomplete tasks'
  end

  describe '#burndown_chart_data' do
    it 'returns daily completion data'
    it 'groups by day within sprint range'
  end
end
```

---

### CORE-003: Pomodoro Session Model 구현
**Priority**: Medium
**Assignee**: Backend
**Status**: Pending
**Story Points**: 3

#### User Story
```
As a developer
I want to use Pomodoro technique for focused work
So that I can maintain productivity with regular breaks
```

#### Acceptance Criteria
- [ ] 25분 작업 / 5분 휴식 사이클
- [ ] 4세션 후 15분 긴 휴식
- [ ] 업무 시간 내에서만 세션 진행
- [ ] 세션 상태 관리 (pending, in_progress, completed, cancelled)

#### Technical Tasks
1. Generate PomodoroSession model
2. Implement session state machine
3. Add business hours validation
4. Create break duration logic

#### Test Scenarios (RSpec)
```ruby
# spec/models/pomodoro_session_spec.rb
RSpec.describe PomodoroSession do
  describe '#next_session_start_time' do
    context 'during business hours' do
      it 'returns current time plus break duration'
    end
    
    context 'after business hours' do
      it 'returns next business day start time'
    end
  end

  describe '#break_duration' do
    it 'returns 5 minutes for regular breaks'
    it 'returns 15 minutes after 4 sessions'
  end
end
```

---

### CORE-004: Task Reminder Notifier 구현
**Priority**: High
**Assignee**: Backend
**Status**: Pending
**Story Points**: 5

#### User Story
```
As a team member
I want to receive notifications about task deadlines
So that I never miss important deliverables
```

#### Acceptance Criteria
- [ ] 마감 1시간 전 알림
- [ ] 마감일 당일 오전 9시 알림
- [ ] ActionCable 실시간 알림
- [ ] 이메일 알림 (선택적)
- [ ] Slack 알림 (선택적)

#### Technical Tasks
1. Create TaskReminderNotifier with Noticed
2. Implement ActionCable delivery method
3. Add email delivery with conditions
4. Setup Slack webhook integration (optional)

#### Test Scenarios (RSpec)
```ruby
# spec/notifiers/task_reminder_notifier_spec.rb
RSpec.describe TaskReminderNotifier do
  describe '#deliver' do
    it 'creates notification event'
    it 'broadcasts to ActionCable'
    it 'sends email if user preferences allow'
    it 'respects user notification settings'
  end
end
```

---

### CORE-005: Dashboard Service 구현
**Priority**: Medium
**Assignee**: Backend
**Status**: Pending
**Story Points**: 3

#### User Story
```
As a team lead
I want to see time tracking dashboards
So that I can monitor team productivity and project progress
```

#### Acceptance Criteria
- [ ] 주간 작업 완료 현황 차트
- [ ] 시간대별 작업 생성 패턴
- [ ] 팀 벨로시티 트렌드
- [ ] 멤버별 작업 완료 시간

#### Technical Tasks
1. Create DashboardService
2. Implement Groupdate queries
3. Add chart data formatting methods
4. Create average completion time calculation

#### Test Scenarios (RSpec)
```ruby
# spec/services/dashboard_service_spec.rb
RSpec.describe DashboardService do
  describe '.weekly_task_completion' do
    it 'groups tasks by week'
    it 'counts completed tasks only'
    it 'respects date range'
  end

  describe '.team_velocity_trend' do
    it 'calculates sprint velocity over time'
    it 'includes only completed sprints'
  end
end
```

---

### CORE-006: Time Helper ViewComponent 구현
**Priority**: Low
**Assignee**: Frontend
**Status**: Pending
**Story Points**: 2

#### User Story
```
As a user
I want to see user-friendly time displays
So that I can quickly understand deadlines and durations
```

#### Acceptance Criteria
- [ ] "3시간 전" 같은 상대 시간 표시
- [ ] 업무 시간 기준 표시
- [ ] 마감일까지 남은 시간 색상 구분
- [ ] 스프린트 진행률 표시

#### Technical Tasks
1. Create TimeDisplayComponent
2. Implement LocalTime integration
3. Add color coding for urgency
4. Create sprint progress bar component

#### Test Scenarios (RSpec)
```ruby
# spec/components/time_display_component_spec.rb
RSpec.describe TimeDisplayComponent do
  describe '#time_until_deadline' do
    it 'shows "기한 초과" for past deadlines'
    it 'shows "오늘 마감" for today'
    it 'shows working hours for future dates'
  end

  describe '#urgency_class' do
    it 'returns text-red-500 for overdue'
    it 'returns text-orange-500 for today'
    it 'returns text-yellow-500 for tomorrow'
  end
end
```

---

### CORE-007: Notification Scheduler Job 구현
**Priority**: Medium
**Assignee**: Backend
**Status**: Pending
**Story Points**: 3

#### User Story
```
As a system
I want to automatically check and send notifications
So that users receive timely alerts
```

#### Acceptance Criteria
- [ ] 5분마다 실행되는 정기 Job
- [ ] 마감일 확인 및 알림 전송
- [ ] 포모도로 세션 완료 알림
- [ ] Solid Queue 통합

#### Technical Tasks
1. Create NotificationSchedulerJob
2. Configure recurring schedule
3. Implement deadline checking logic
4. Add pomodoro session checks

#### Test Scenarios (RSpec)
```ruby
# spec/jobs/notification_scheduler_job_spec.rb
RSpec.describe NotificationSchedulerJob do
  describe '#perform' do
    it 'checks tasks with upcoming deadlines'
    it 'sends notifications for tasks due in 1 hour'
    it 'completes expired pomodoro sessions'
    it 'handles errors gracefully'
  end
end
```

---

### CORE-008: Integration Tests (E2E with Playwright)
**Priority**: Low
**Assignee**: QA
**Status**: Pending
**Story Points**: 5

#### User Story
```
As a QA engineer
I want comprehensive E2E tests
So that I can ensure the time tracking system works end-to-end
```

#### Acceptance Criteria
- [ ] Task time tracking flow test
- [ ] Pomodoro timer interaction test
- [ ] Notification delivery test
- [ ] Dashboard visualization test

#### Test Scenarios (Playwright)
```javascript
// spec/e2e/time_tracking.spec.js
test.describe('Time Tracking System', () => {
  test('tracks task time from start to completion', async ({ page }) => {
    // Start task timer
    // Work for period
    // Complete task
    // Verify time recorded
  });

  test('shows real-time notifications', async ({ page }) => {
    // Set task deadline
    // Wait for notification time
    // Verify notification appears
  });

  test('displays dashboard charts correctly', async ({ page }) => {
    // Navigate to dashboard
    // Verify chart rendering
    // Check data accuracy
  });
});
```

---

## 🔄 Sprint Planning

### Sprint 1: Foundation (Week 1-2)
- CORE-001: TimeTrackable Concern
- CORE-002: Sprint Model
- CORE-003: Pomodoro Session Model

### Sprint 2: Notifications (Week 3-4)
- CORE-004: Task Reminder Notifier
- CORE-007: Notification Scheduler Job

### Sprint 3: Visualization (Week 5-6)
- CORE-005: Dashboard Service
- CORE-006: Time Helper ViewComponent
- CORE-008: Integration Tests

---

## 📊 Progress Tracking

| Task ID | Story Points | Status | Progress |
|---------|-------------|--------|----------|
| CORE-001 | 3 | 🔄 In Progress | 20% |
| CORE-002 | 5 | 📋 Pending | 0% |
| CORE-003 | 3 | 📋 Pending | 0% |
| CORE-004 | 5 | 📋 Pending | 0% |
| CORE-005 | 3 | 📋 Pending | 0% |
| CORE-006 | 2 | 📋 Pending | 0% |
| CORE-007 | 3 | 📋 Pending | 0% |
| CORE-008 | 5 | 📋 Pending | 0% |

**Total Story Points**: 29
**Completed**: 0
**Velocity**: TBD

---

## 🚀 Definition of Done

- [ ] 모든 acceptance criteria 충족
- [ ] Unit tests 작성 및 통과 (coverage > 80%)
- [ ] Integration tests 통과
- [ ] Code review 완료
- [ ] Documentation 업데이트
- [ ] No critical bugs
- [ ] Performance benchmarks met