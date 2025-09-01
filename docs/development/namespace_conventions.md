# 네임스페이스 규칙 및 충돌 방지 가이드

## 문제 상황

AppRoutes 모듈에 Task, Organization 등의 하위 모듈이 있고, 동시에 같은 이름의 모델 클래스가 존재하여 네임스페이스 충돌이 발생할 수 있습니다.

## 해결 방법

### 1. 모델 참조 시 루트 네임스페이스 사용 (권장)

컨트롤러에서 모델을 참조할 때는 항상 `::` 접두사를 사용하여 루트 네임스페이스를 명시합니다:

```ruby
# ❌ 잘못된 예 - AppRoutes::Task로 해석될 수 있음
@tasks = Task.accessible_by(current_ability)

# ✅ 올바른 예 - 명시적으로 루트 네임스페이스의 Task 모델 참조
@tasks = ::Task.accessible_by(current_ability)
```

### 2. AppRoutes 모듈 구조

AppRoutes 모듈의 하위 모듈은 `Routes` 접미사를 사용하여 모델과 구분됩니다:

- `AppRoutes::TaskRoutes` - 태스크 관련 경로
- `AppRoutes::OrganizationRoutes` - 조직 관련 경로
- `AppRoutes::AuthRoutes` - 인증 관련 경로

기존 코드 호환성을 위해 별칭(alias)도 제공됩니다:
- `AppRoutes::Task` → `AppRoutes::TaskRoutes`
- `AppRoutes::Organization` → `AppRoutes::OrganizationRoutes`

### 3. 헬퍼 메서드 사용

ModelNamespace 모듈이 제공하는 헬퍼 메서드를 사용할 수도 있습니다:

```ruby
# 헬퍼 메서드 사용
@tasks = task_model.accessible_by(current_ability)
@organization = organization_model.find(params[:id])
```

### 4. 주의사항

- ApplicationController에서 `include AppRoutes`를 제거했습니다
- AppRoutes 상수 접근 시 전체 경로를 사용하세요:
  ```ruby
  # 예시
  redirect_to AppRoutes::Auth.login_url
  AppRoutes::TaskRoutes::INDEX_PATH
  ```

## 영향받는 모델

네임스페이스 충돌 가능성이 있는 모델들:
- `::Task`
- `::Organization`
- `::Team`
- `::Service`
- `::Sprint`
- `::User`

## 개발 환경 경고

개발 환경에서는 네임스페이스 충돌이 감지되면 Rails 로그에 경고가 표시됩니다:
```
⚠️  네임스페이스 충돌 가능성: AppRoutes::Task와 ::Task 모델이 공존합니다.
   컨트롤러에서는 ::Task를 사용하여 모델을 참조하세요.
```

## 체크리스트

새로운 컨트롤러를 작성할 때:
- [ ] 모델 참조 시 `::` 접두사 사용
- [ ] AppRoutes 모듈을 include하지 않고 직접 참조
- [ ] Rubocop으로 코드 스타일 검증
- [ ] 테스트 실행하여 네임스페이스 문제 없는지 확인