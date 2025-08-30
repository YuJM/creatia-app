# TODO: After Action Items

## ✅ 완료된 작업 (2025-08-30)

### 1. Pagination 라이브러리 설치
- [x] Kaminari gem 설치 완료
- [x] PermissionAuditLogsController의 pagination 코드 복구
- [x] View의 pagination helper 복구

### 2. 누락된 HTML View 파일 생성

#### Organization 관련
- [x] `app/views/organization_memberships/index.html.erb` - 멤버 목록 페이지
- [x] `app/views/organization_memberships/show.html.erb` - 멤버 상세 페이지
- [x] `app/views/organization_memberships/edit.html.erb` - 멤버 수정 페이지

#### Task 관련
- [x] `app/views/tasks/index.html.erb` - 태스크 목록 페이지
- [x] `app/views/tasks/new.html.erb` - 태스크 생성 페이지
- [x] `app/views/tasks/show.html.erb` - 태스크 상세 페이지
- [x] `app/views/tasks/edit.html.erb` - 태스크 수정 페이지

### 3. 라우트 및 컨트롤러 확인
- [x] `/organization/delete` 라우트 확인 - RESTful 라우팅 사용 중
- [x] E2E 테스트를 Rails 컨벤션에 맞게 수정

### 4. E2E 테스트 전략 개선
- [x] E2E 테스트 README.md 파일 작성
- [x] 테스트 가이드라인 문서화
- [x] 트러블슈팅 섹션 추가

## 🔄 남은 작업

### 1. 컨트롤러 검증
- [x] OrganizationMembershipsController 동작 확인 - API 응답 정상, 권한 체크 구현됨
- [x] TasksController 동작 확인 - 멀티포맷 응답 지원 (JSON/Turbo/HTML)
- [ ] 생성된 View 파일들의 실제 렌더링 테스트

### 2. E2E 테스트 실행
- [x] 수정된 E2E 테스트 실행 및 검증 - 일부 테스트 실패 발견
- [ ] 모든 권한 시나리오 테스트 통과 확인 - 수정 필요

### 3. API 응답 개선
- [ ] API 전용 컨트롤러에 HTML 응답 추가 여부 검토
- [ ] ViewComponent 기반 UI 컴포넌트 테스트 추가

## 해결된 문제 (참고용)

### ✅ 완료된 작업
1. AuthHelper의 로그인 필드명 수정 (`auth_user_user[email]`)
2. PermissionAuditLogsController의 pagination 임시 제거
3. 권한 시스템 동작 확인 (Owner 권한 정상)

## 테스트 실행 명령어

```bash
# 전체 E2E 테스트 실행
npx playwright test e2e/rbac-permissions.spec.ts --reporter=list

# 특정 테스트만 실행
npx playwright test e2e/rbac-permissions.spec.ts --grep "Owner" --reporter=list

# JSON 리포터로 결과 확인
npx playwright test e2e/rbac-permissions.spec.ts --reporter=json > test-results.json
```

## 참고 사항

- 권한 시스템 자체는 정상 작동 (Ability 모델 확인 완료)
- 멀티테넌트 시스템에서 인증 ≠ 권한 (중요)
- Owner는 priority 100으로 모든 권한 보유
- 동적 권한 시스템(role_id)과 레거시 시스템(role string) 공존 중

## E2E 테스트 현황 (2025-08-30)

### 통과한 테스트
- Owner의 role management 접근
- Cross-organization isolation 일부
- Admin의 특정 기능 제한
- Member의 task 조회

### 실패한 테스트
- Owner의 audit log 조회 (UI 요소 찾지 못함)
- Owner의 member 관리 (UI 요소 문제)
- Admin의 task 생성 (권한 또는 UI 문제)
- Member의 권한 제한 검증 일부

### 개선 필요 사항
- View 파일들의 실제 렌더링 테스트 필요
- E2E 테스트의 selector 업데이트 필요
- 실제 UI 요소와 테스트 기대값 동기화