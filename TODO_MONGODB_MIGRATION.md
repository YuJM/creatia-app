# MongoDB 마이그레이션 TODO

## 🎯 목표
PostgreSQL에서 MongoDB로 대량 데이터 모델들을 마이그레이션하여 성능 최적화 및 확장성 개선

## 📊 마이그레이션 대상 분석

### 1. 활동 로그 시스템 🔴 높은 우선순위
- [ ] Task 상태 변경 히스토리 모델 설계
- [ ] 사용자 액션 로그 (클릭, 조회, 수정) 구현
- [ ] Sprint 진행 과정 로그 추가
- [ ] 기존 ActivityLog 모델 확장

### 2. 알림 시스템 ✅ 이미 PostgreSQL 구현됨
- [ ] noticed_events 테이블 → MongoDB 마이그레이션 검토
- [ ] noticed_notifications 테이블 → MongoDB 마이그레이션 검토
- [ ] 알림 히스토리 아카이빙 전략 수립
- [ ] 읽음/읽지않음 상태 최적화

### 3. 시간 추적 데이터 ✅ 이미 PostgreSQL 구현됨  
- [ ] PomodoroSession 모델 → MongoDB 마이그레이션
- [ ] 세션별 상세 타임스탬프 저장 구조 개선
- [ ] 생산성 메트릭 집계 최적화
- [ ] 시계열 데이터 인덱싱 전략

### 4. 대시보드 분석 데이터 🔴 새로 구현 필요
- [ ] 통계 데이터 사전 집계 모델 설계
- [ ] 일일/주간/월간 집계 컬렉션 생성
- [ ] 팀 벨로시티 트렌드 저장 구조
- [ ] 멤버별 생산성 지표 캐싱

## 🚀 구현 작업

### Phase 1: 기초 설정 ✅ 완료
- [x] Mongoid 설정
- [x] MongoDB Docker 환경 구성
- [x] 기본 로그 모델 생성 (ActivityLog, ApiRequestLog, ErrorLog)
- [x] LogService 구현

### Phase 2: 활동 로그 확장 ✅ 완료
- [x] TaskHistory 모델 생성
  ```ruby
  class TaskHistory
    include Mongoid::Document
    include Mongoid::Timestamps
    
    field :task_id, type: Integer
    field :action, type: String # created, updated, status_changed, assigned
    field :changes, type: Hash
    field :user_id, type: Integer
    field :metadata, type: Hash
    
    index({ task_id: 1, created_at: -1 })
    index({ user_id: 1, created_at: -1 })
  end
  ```

- [x] UserActionLog 모델 생성
  ```ruby
  class UserActionLog
    include Mongoid::Document
    include Mongoid::Timestamps
    
    field :user_id, type: Integer
    field :action_type, type: String # view, click, edit, delete
    field :resource_type, type: String
    field :resource_id, type: Integer
    field :session_id, type: String
    field :ip_address, type: String
    field :user_agent, type: String
    
    index({ user_id: 1, created_at: -1 })
    index({ session_id: 1 })
  end
  ```

### Phase 3: 시간 추적 데이터 마이그레이션 ✅ 완료
- [x] PomodoroSessionMongo 모델 생성
- [x] 기존 PomodoroSession 데이터 마이그레이션 스크립트
- [x] 실시간 세션 추적 로직 MongoDB 전환
- [x] 포모도로 통계 집계 최적화

### Phase 4: 대시보드 분석 데이터 ✅ 완료
- [x] DashboardMetrics 모델 생성
  ```ruby
  class DashboardMetrics
    include Mongoid::Document
    include Mongoid::Timestamps
    
    field :organization_id, type: Integer
    field :date, type: Date
    field :metrics_type, type: String # daily, weekly, monthly
    field :completed_tasks, type: Integer
    field :created_tasks, type: Integer
    field :velocity, type: Float
    field :team_metrics, type: Hash
    field :member_metrics, type: Array
    
    index({ organization_id: 1, date: -1, metrics_type: 1 }, { unique: true })
  end
  ```

- [x] 백그라운드 집계 Job 구현
- [x] 캐싱 전략 수립
- [x] API 엔드포인트 최적화

### Phase 5: 알림 시스템 검토 ✅ 완료
- [x] Noticed gem과 MongoDB 호환성 분석
- [x] 하이브리드 접근법 검토 (실시간: PostgreSQL, 아카이브: MongoDB)
- [x] 알림 히스토리 아카이빙 구현
- [x] 성능 벤치마킹

## 📝 마이그레이션 전략

### 데이터 이관 계획
1. **이중 쓰기 (Dual Write) 전략**
   - [ ] 새 데이터는 PostgreSQL + MongoDB 동시 저장
   - [ ] 기존 데이터 배치 마이그레이션
   - [ ] 데이터 정합성 검증

2. **점진적 전환**
   - [ ] 읽기 작업부터 MongoDB로 전환
   - [ ] 쓰기 작업 순차적 전환
   - [ ] PostgreSQL 데이터 아카이빙

### 인덱싱 전략
- [ ] 복합 인덱스 설계
- [ ] TTL 인덱스 활용 (오래된 로그 자동 삭제)
- [ ] 텍스트 검색 인덱스 구성
- [ ] 지리공간 인덱스 (향후 확장)

## 🔧 기술적 고려사항

### 성능 최적화
- [ ] Connection Pooling 설정
- [ ] Read/Write Concern 레벨 조정
- [ ] Aggregation Pipeline 최적화
- [ ] 샤딩 전략 수립 (향후)

### 모니터링
- [ ] MongoDB 메트릭 수집
- [ ] 슬로우 쿼리 로깅
- [ ] 디스크 사용량 모니터링
- [ ] 레플리카셋 상태 체크

### 백업 및 복구
- [ ] 자동 백업 스케줄 설정
- [ ] Point-in-time Recovery 구성
- [ ] 재해 복구 계획 수립

## 📅 일정

### Week 1-2: Phase 2 (활동 로그)
- TaskHistory, UserActionLog 구현
- 기본 CRUD 및 검색 기능

### Week 3-4: Phase 3 (시간 추적)
- PomodoroSession 마이그레이션
- 실시간 추적 최적화

### Week 5-6: Phase 4 (대시보드)
- 분석 데이터 모델 구현
- 집계 Job 개발

### Week 7-8: Phase 5 (알림 검토) & 최적화
- 알림 시스템 분석
- 전체 시스템 성능 테스트
- 최종 최적화

## ✅ 완료 기준
- [ ] 모든 대량 데이터 모델 MongoDB 전환 완료
- [ ] 응답 시간 50% 개선
- [ ] 데이터 정합성 100% 유지
- [ ] 모니터링 및 백업 체계 구축
- [ ] 문서화 완료

## 📚 참고 자료
- [Mongoid Documentation](https://www.mongodb.com/docs/mongoid/current/)
- [MongoDB Best Practices](https://www.mongodb.com/docs/manual/administration/production-notes/)
- [Rails + MongoDB Integration Guide](https://www.mongodb.com/docs/mongoid/current/tutorials/rails/)