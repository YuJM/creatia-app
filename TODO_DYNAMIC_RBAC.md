# Multi-Tenant Dynamic RBAC 구현 TODO

## 📋 개요
Pundit 대신 CanCanCan + 직접 구현 하이브리드 방식으로 Multi-Tenant Dynamic RBAC 시스템 구축

## ✅ Phase 1: 데이터베이스 구조 [완료]
- [x] roles, permissions, role_permissions 테이블 생성
- [x] Role, Permission, RolePermission 모델 생성
- [x] 관련 모델들 생성 (ResourcePermission, PermissionDelegation, PermissionAuditLog)
- [x] 기존 하드코딩된 역할을 새 시스템으로 마이그레이션
- [x] 54개 시스템 권한 생성
- [x] 4개 권한 템플릿 생성
- [x] 7개 조직, 16개 멤버십 마이그레이션 완료

## ✅ Phase 2: CanCanCan 기반 권한 시스템 [완료]

### 2.1 CanCanCan 설치 및 설정
- [x] Gemfile에 cancancan gem 추가
- [x] bundle install 실행
- [x] CanCanCan 초기 설정

### 2.2 Ability 클래스 구현
- [x] app/models/ability.rb 생성
- [x] 데이터베이스에서 동적 권한 로딩 구현
- [x] Multi-tenant 지원 (조직별 권한)
- [x] 역할 상속 로직 구현
- [x] 권한 위임(delegation) 처리

### 2.3 ApplicationController 통합
- [x] current_ability 메서드 구현
- [x] rescue_from CanCan::AccessDenied 추가
- [x] check_authorization 설정
- [x] 감사 로그 자동 기록

### 2.4 기존 Pundit 마이그레이션
- [x] ApplicationPolicy 제거 또는 비활성화
- [x] 각 Policy 파일을 Ability로 변환
  - [x] UserPolicy → Ability
  - [x] OrganizationPolicy → Ability
  - [x] OrganizationMembershipPolicy → Ability
  - [x] TaskPolicy → Ability
- [x] authorize 호출을 authorize!로 변경
- [x] policy_scope를 accessible_by로 변경

### 2.5 PermissionService 헬퍼 구현
- [x] app/services/permission_service.rb 생성
- [x] 간단한 권한 체크 메서드 구현
  - [x] can_view_task?
  - [x] can_edit_service?
  - [x] can_manage_organization?
- [x] 컨트롤러/뷰에서 사용할 헬퍼 메서드

### 2.6 권한 캐싱 시스템
- [x] Rails.cache 기반 캐싱 구현
- [x] 권한 변경 시 캐시 무효화
- [x] 조직별 캐시 키 전략
- [x] 성능 모니터링 추가

## 🧪 Phase 3: 테스트 작성

### 3.1 RSpec 테스트
- [ ] spec/models/ability_spec.rb
  - [ ] 동적 권한 로딩 테스트
  - [ ] 역할별 권한 테스트
  - [ ] 권한 상속 테스트
  - [ ] 권한 위임 테스트
- [ ] spec/services/permission_service_spec.rb
- [ ] spec/models/role_spec.rb
- [ ] spec/models/permission_spec.rb
- [ ] 컨트롤러 권한 테스트

### 3.2 E2E 테스트 (Playwright)
- [ ] 로그인 및 권한 체크
- [ ] 역할별 UI 표시/숨김
- [ ] 권한 없는 액션 시도
- [ ] 권한 변경 후 즉시 반영 확인

## 🎨 Phase 4: 권한 관리 UI

### 4.1 역할 관리 페이지
- [ ] 역할 목록 페이지
- [ ] 역할 생성/수정 폼
- [ ] 권한 할당 인터페이스 (체크박스)
- [ ] 역할 삭제 (사용 중 체크)

### 4.2 권한 할당 인터페이스
- [ ] 사용자별 역할 할당
- [ ] 권한 템플릿 적용
- [ ] 특수 권한 부여/회수
- [ ] 권한 위임 관리

### 4.3 감사 로그 뷰어
- [ ] 로그 목록 (필터링, 검색)
- [ ] 상세 로그 보기
- [ ] 통계 대시보드
- [ ] CSV 내보내기

## 📊 성공 지표
- [ ] 모든 컨트롤러에서 권한 체크 활성화
- [ ] 권한 체크 응답 시간 < 50ms
- [ ] 캐시 히트율 > 90%
- [ ] 테스트 커버리지 > 90%
- [ ] 권한 변경 시 즉시 반영 (< 1초)

## 🔧 기술 스택
- **Authorization**: CanCanCan 3.5+
- **Multi-tenancy**: ActsAsTenant
- **Caching**: Rails.cache (Redis 권장)
- **Testing**: RSpec + Playwright
- **UI**: ViewComponent + Stimulus + Turbo

## 📝 참고사항
- 기존 Pundit 코드는 단계적으로 제거
- 성능이 중요한 부분은 직접 구현
- 모든 권한 변경은 감사 로그에 기록
- 프로덕션 배포 전 성능 테스트 필수