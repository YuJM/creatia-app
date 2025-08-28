# 유연한 스프린트 스케줄 시스템

## 개요
팀의 다양한 근무 패턴과 문화를 지원하는 유연한 스프린트 일정 관리 시스템입니다.

## FlexibleSchedule Concern

### 프리셋 (Presets)

#### 1. Standard (표준 근무)
```ruby
sprint.apply_schedule_preset(:standard)
```
- 근무 시간: 09:00 - 18:00
- 주말 근무: 불가
- 데일리 스탠드업: 10:00

#### 2. Startup (스타트업 모드)
```ruby
sprint.apply_schedule_preset(:startup)
```
- 근무 시간: 10:00 - 20:00
- 주말 근무: 가능
- 유연 근무제: 활성화
- 데일리 스탠드업: 11:00

#### 3. Remote (리모트 팀)
```ruby
sprint.apply_schedule_preset(:remote)
```
- 근무 시간: 07:00 - 22:00
- 매우 유연한 시간대
- 주말 근무: 불가
- 데일리 스탠드업: 10:00

#### 4. Global (글로벌 팀)
```ruby
sprint.apply_schedule_preset(:global)
```
- 근무 시간: 06:00 - 23:00
- 시차 고려한 확장 시간
- 비동기 스탠드업 (null)

#### 5. Crunch (집중 개발)
```ruby
sprint.apply_schedule_preset(:crunch)
```
- 근무 시간: 08:00 - 22:00
- 주말 근무: 가능
- 긴급 개발 대응

## 커스텀 스케줄 설정

### 팀별 요일 설정
```ruby
sprint.set_team_schedule(
  monday: { 
    start: "10:00", 
    end: "19:00", 
    standup: "10:30" 
  },
  tuesday: { 
    start: "09:00", 
    end: "18:00", 
    standup: "09:30" 
  },
  wednesday: { 
    start: "10:00", 
    end: "19:00", 
    standup: "10:30" 
  },
  thursday: { 
    start: "09:00", 
    end: "18:00", 
    standup: "09:30" 
  },
  friday: { 
    start: "09:00", 
    end: "15:00",  # 금요일 조기 퇴근
    standup: "09:30" 
  },
  timezone: "Asia/Seoul"
)
```

### 유연한 근무 시간 활성화
```ruby
sprint.configure_flexible_hours(
  start_time: "07:00",    # 이른 출근 가능
  end_time: "22:00",      # 늦은 퇴근 가능  
  weekend_work: false     # 주말 근무 여부
)
```

## 스크럼 이벤트 관리

### 자동 스케줄링
```ruby
sprint.schedule_scrum_events
```
자동으로 설정되는 항목:
- **스프린트 계획**: 첫날 시작 시간
- **스프린트 리뷰**: 마지막날 14:00
- **회고 미팅**: 리뷰 2시간 후

### 다음 이벤트 확인
```ruby
sprint.next_scrum_event
# => { 
#   type: :standup, 
#   time: 2025-08-29 10:00:00, 
#   duration: 15 minutes 
# }
```

### 다음 스탠드업
```ruby
sprint.next_standup_time
# => 2025-08-29 10:00:00 +0900
```

## 스프린트 일정 조정

### 시간 변경
```ruby
sprint.adjust_schedule(
  new_start_time: "10:00",
  new_end_time: "20:00"
)
```

### 날짜 변경
```ruby
sprint.adjust_schedule(
  new_start_date: Date.tomorrow,
  new_end_date: 3.weeks.from_now
)
```

## 생산성 분석

### 최적 작업 시간대 분석
```ruby
analysis = sprint.optimal_working_hours_analysis
```

결과:
```ruby
{
  peak_hours: [
    ["14:00", 45.6],  # 오후 2시 최고 생산성
    ["10:00", 42.0],
    ["15:00", 38.4]
  ],
  recommended_standup: "11:00 (생산성 방해 최소화)",
  recommended_focus_time: [
    {
      time: "14:00",
      recommendation: "창의적 작업에 적합",
      score: 45.6
    },
    {
      time: "10:00", 
      recommendation: "복잡한 문제 해결에 적합",
      score: 42.0
    }
  ]
}
```

## 작업 시간 계산

### 총 가용 시간
```ruby
sprint.total_available_hours
# => 112  # 2주, 주말 제외, 점심시간 제외
```

### 특정 날짜의 근무 시간
```ruby
sprint.working_hours_for(Date.today)
# => {
#   start: 09:00:00,
#   end: 18:00:00,
#   standup: 10:00:00
# }
```

### 근무 여부 확인
```ruby
sprint.should_work_on?(Date.today)  # => true
sprint.should_work_on?(Date.today.sunday)  # => false (주말 근무 비활성 시)
```

## 데이터베이스 스키마

### 추가된 필드
```ruby
t.time :start_time, default: "09:00:00"
t.time :end_time, default: "18:00:00"
t.boolean :flexible_hours, default: false
t.boolean :weekend_work, default: false
t.time :daily_standup_time
t.datetime :review_meeting_time
t.datetime :retrospective_time
t.jsonb :custom_schedule
```

## 사용 시나리오

### 시나리오 1: 스타트업 팀
```ruby
sprint = Sprint.create(name: "MVP Sprint")
sprint.apply_schedule_preset(:startup)
# 10-20시 근무, 주말 가능, 유연한 시간
```

### 시나리오 2: 글로벌 분산 팀
```ruby
sprint = Sprint.create(name: "Global Release")
sprint.apply_schedule_preset(:global)
# 시차 고려, 비동기 협업
```

### 시나리오 3: 커스텀 4일 근무
```ruby
sprint.set_team_schedule(
  monday: { start: "09:00", end: "19:00" },
  tuesday: { start: "09:00", end: "19:00" },
  wednesday: { start: "09:00", end: "19:00" },
  thursday: { start: "09:00", end: "19:00" },
  # 금요일 휴무
)
```

## 모범 사례

1. **팀 문화 반영**: 팀의 실제 근무 패턴에 맞는 프리셋 선택
2. **점진적 조정**: 한 번에 큰 변화보다 점진적 조정
3. **데이터 기반 결정**: 생산성 분석을 통한 최적 시간대 찾기
4. **투명한 커뮤니케이션**: 스케줄 변경 시 팀원 전체 알림

## 제한사항

- 최소 근무 시간: 4시간/일
- 최대 연속 근무: 15시간
- 점심시간: 6시간 이상 근무 시 자동 1시간 제외
- 시간대: Rails 애플리케이션 타임존 설정 따름