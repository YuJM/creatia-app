# TODO: After Action Items

## E2E 테스트 관련 남은 작업

### 1. Pagination 라이브러리 설치
- [ ] Kaminari gem 설치 또는 다른 pagination 라이브러리 선택
- [ ] PermissionAuditLogsController의 pagination 코드 복구
- [ ] View의 pagination helper 복구

### 2. 누락된 HTML View 파일 생성

#### Organization 관련
- [ ] `app/views/organization_memberships/index.html.erb` - 멤버 목록 페이지
- [ ] `app/views/organization_memberships/show.html.erb` - 멤버 상세 페이지
- [ ] `app/views/organization_memberships/edit.html.erb` - 멤버 수정 페이지

#### Task 관련
- [ ] `app/views/tasks/index.html.erb` - 태스크 목록 페이지
- [ ] `app/views/tasks/new.html.erb` - 태스크 생성 페이지
- [ ] `app/views/tasks/show.html.erb` - 태스크 상세 페이지
- [ ] `app/views/tasks/edit.html.erb` - 태스크 수정 페이지

### 3. 라우트 및 컨트롤러 확인
- [ ] `/organization/delete` 라우트 구현 또는 테스트 수정
- [ ] API 전용 컨트롤러에 HTML 응답 추가

### 4. E2E 테스트 전략 개선
- [ ] API 엔드포인트 테스트와 UI 테스트 분리 고려
- [ ] ViewComponent 기반 UI가 있는 경우 해당 컴포넌트 테스트 추가
- [ ] 실제 존재하는 페이지 기준으로 테스트 시나리오 재작성

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