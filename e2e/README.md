# E2E 테스트 가이드

## 테스트 환경 설정

### 1. 필수 요구사항
- Node.js 18+ 
- Playwright 설치
- Rails 서버 실행 중
- Caddy 서버 실행 중 (로컬 도메인 지원)
- PostgreSQL 데이터베이스

### 2. 로컬 도메인 설정
테스트는 `*.creatia.local` 도메인을 사용합니다. `/etc/hosts` 파일에 다음 항목들이 추가되어야 합니다:

```bash
127.0.0.1 creatia.local
127.0.0.1 demo.creatia.local
127.0.0.1 auth.creatia.local
127.0.0.1 api.creatia.local
```

### 3. 테스트 데이터 준비
```bash
# 테스트 데이터베이스 설정
bin/rails db:test:prepare

# Seed 데이터 로드 (테스트 환경)
RAILS_ENV=test bin/rails db:seed
```

## 테스트 실행

### 전체 테스트 실행
```bash
npx playwright test
```

### 특정 테스트 파일 실행
```bash
npx playwright test e2e/rbac-permissions.spec.ts
```

### 디버그 모드로 실행
```bash
npx playwright test --debug
```

### UI 모드로 실행
```bash
npx playwright test --ui
```

## 테스트 구조

### 파일 구성
```
e2e/
├── README.md                    # 이 파일
├── fixtures/                    # 테스트 데이터 및 헬퍼
│   └── auth-helper.ts          # 인증 관련 헬퍼 함수
├── rbac-permissions.spec.ts    # 권한 시스템 테스트
└── playwright.config.ts        # Playwright 설정
```

### 테스트 시나리오

#### 1. 권한 시스템 (RBAC) 테스트
- **Owner 권한**: 모든 기능 접근 가능
- **Admin 권한**: 조직 관리 기능 (삭제 제외)
- **Member 권한**: 기본 읽기/쓰기 권한
- **Guest 권한**: 읽기 전용

#### 2. 멀티테넌트 테스트
- 조직별 데이터 격리
- 서브도메인 기반 라우팅
- 크로스 도메인 인증

## 테스트 작성 가이드

### 1. 인증 처리
```typescript
import { login } from './fixtures/auth-helper';

test('authenticated test', async ({ page, context }) => {
  const cookies = await login(page, 'user@example.com', 'password');
  await context.addCookies(cookies);
  // 이제 인증된 상태로 테스트 진행
});
```

### 2. 권한 테스트
```typescript
test('permission test', async ({ page }) => {
  // 특정 권한을 가진 사용자로 로그인
  await login(page, 'admin@example.com', 'password');
  
  // 권한에 따른 UI 요소 확인
  await expect(page.locator('[data-permission="admin"]')).toBeVisible();
});
```

### 3. API 응답 대기
```typescript
test('wait for API', async ({ page }) => {
  // API 응답 대기
  await page.waitForResponse(
    response => response.url().includes('/api/') && response.status() === 200
  );
});
```

## 트러블슈팅

### 1. 로그인 실패
- 쿠키가 올바르게 설정되었는지 확인
- CSRF 토큰이 포함되었는지 확인
- 서브도메인이 올바른지 확인

### 2. 권한 오류
- Seed 데이터가 올바르게 로드되었는지 확인
- 사용자의 role이 올바르게 설정되었는지 확인
- ActsAsTenant 설정 확인

### 3. 네트워크 오류
- Rails 서버가 실행 중인지 확인
- Caddy 서버가 실행 중인지 확인
- 로컬 도메인 설정 확인

## 지속적 통합 (CI)

GitHub Actions에서 테스트를 실행하려면:

```yaml
- name: Run E2E tests
  run: |
    npx playwright install
    npx playwright test
```

## 베스트 프랙티스

1. **Page Object Model 사용**: 반복되는 UI 요소는 별도 클래스로 관리
2. **데이터 격리**: 각 테스트는 독립적으로 실행 가능해야 함
3. **명확한 네이밍**: 테스트 이름은 테스트하는 내용을 명확히 설명
4. **적절한 대기**: `waitForSelector` 대신 `expect().toBeVisible()` 사용
5. **스크린샷 활용**: 실패 시 자동으로 스크린샷 저장

## 참고 자료

- [Playwright 문서](https://playwright.dev)
- [Rails 테스팅 가이드](https://guides.rubyonrails.org/testing.html)
- [Creatia 권한 시스템 문서](../docs/rbac.md)