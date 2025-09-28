# 🚀 API 사용 가이드

> **Creatia App API 완전 가이드**  
> RESTful API를 통한 태스크 관리, 조직 관리, 인증 시스템 활용법

## 📋 목차

- [🔑 인증 방법](#-인증-방법)
- [📋 태스크 API](#-태스크-api)
- [🏢 조직 API](#-조직-api)
- [📈 대시보드 API](#-대시보드-api)
- [👨‍💻 개발자 도구](#-개발자-도구)
- [🔧 API 테스트](#-api-테스트)

## 🔑 인증 방법

### 1. HTTP Basic Auth (개발/테스트용)

```bash
# 기본 인증으로 API 호출
curl -u "user@example.com:password123" \
  http://api.creatia.local:3000/api/v1/tasks
```

### 2. JWT 토큰 인증 (프로덕션용)

```bash
# 1. 로그인으로 토큰 발급
curl -X POST http://api.creatia.local:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123",
    "organization_subdomain": "demo"
  }'

# 응답 예시:
# {
#   "token": "eyJhbGciOiJIUzI1NiIs...",
#   "user": { "id": "123", "email": "user@example.com" },
#   "organization": { "id": "456", "name": "Demo Org" }
# }

# 2. 토큰을 사용해 API 호출
curl -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIs..." \
  http://api.creatia.local:3000/api/v1/tasks
```

## 📋 태스크 API

### 태스크 목록 조회

```bash
GET /api/v1/tasks

# 쿼리 파라미터
# - page: 페이지 번호 (기본값: 1)
# - per_page: 페이지당 항목 수 (기본값: 10)
# - status: 태스크 상태 필터 (todo, in_progress, review, done)
# - priority: 우선순위 필터 (low, medium, high, urgent)
# - assignee_id: 담당자 ID 필터

curl -H "Authorization: Bearer YOUR_TOKEN" \
  "http://api.creatia.local:3000/api/v1/tasks?status=in_progress&page=1"
```

**응답 예시:**
```json
{
  "tasks": [
    {
      "id": "task_001",
      "title": "새로운 기능 개발",
      "description": "사용자 대시보드 개선",
      "status": "in_progress",
      "priority": "high",
      "assignee": {
        "id": "user_123",
        "name": "김개발",
        "email": "dev@example.com"
      },
      "estimated_hours": 8.0,
      "actual_hours": 3.5,
      "due_date": "2025-10-01",
      "created_at": "2025-09-28T10:00:00Z",
      "updated_at": "2025-09-28T14:30:00Z"
    }
  ],
  "meta": {
    "total": 25,
    "page": 1,
    "per_page": 10,
    "total_pages": 3
  }
}
```

### 새 태스크 생성

```bash
POST /api/v1/tasks
Content-Type: application/json

{
  "task": {
    "title": "새로운 태스크",
    "description": "태스크 설명",
    "priority": "medium",
    "assignee_id": "user_123",
    "due_date": "2025-10-15",
    "estimated_hours": 4.0,
    "tags": ["frontend", "ui"]
  }
}
```

### 태스크 상태 변경

```bash
PATCH /api/v1/tasks/:id/status
Content-Type: application/json

{
  "status": "completed"
}
```

### 태스크 할당

```bash
PATCH /api/v1/tasks/:id/assign
Content-Type: application/json

{
  "assignee_id": "user_456"
}
```

### 태스크 메트릭 조회

```bash
GET /api/v1/tasks/:id/metrics

# 응답:
{
  "metrics": {
    "completion_rate": 75.0,
    "time_spent": 6.5,
    "estimated_vs_actual": {
      "estimated": 8.0,
      "actual": 6.5,
      "variance": -1.5
    },
    "comments_count": 3,
    "status_changes": [
      {"status": "todo", "timestamp": "2025-09-28T09:00:00Z"},
      {"status": "in_progress", "timestamp": "2025-09-28T10:00:00Z"}
    ]
  }
}
```

## 🏢 조직 API

### 조직 정보 조회

```bash
GET /api/v1/organizations/current

# 응답:
{
  "organization": {
    "id": "org_123",
    "name": "Demo 조직",
    "subdomain": "demo",
    "plan": "team",
    "active": true,
    "member_count": 15,
    "task_count": 142,
    "created_at": "2025-01-15T09:00:00Z",
    "settings": {
      "timezone": "Asia/Seoul",
      "working_hours": "09:00-18:00",
      "working_days": ["monday", "tuesday", "wednesday", "thursday", "friday"]
    }
  }
}
```

### 조직 멤버 목록

```bash
GET /api/v1/members

# 쿼리 파라미터
# - role: 역할 필터 (owner, admin, member)
# - active: 활성 상태 필터 (true, false)
# - search: 이름/이메일 검색

curl -H "Authorization: Bearer YOUR_TOKEN" \
  "http://api.creatia.local:3000/api/v1/members?role=admin&active=true"
```

**응답:**
```json
{
  "members": [
    {
      "id": "member_001",
      "user": {
        "id": "user_123",
        "name": "김개발",
        "email": "dev@example.com",
        "avatar_url": "https://example.com/avatar.jpg"
      },
      "role": "admin",
      "active": true,
      "joined_at": "2025-01-20T10:00:00Z",
      "last_activity": "2025-09-28T15:30:00Z",
      "task_count": 12,
      "permissions": ["task.create", "task.assign", "member.invite"]
    }
  ],
  "meta": {
    "total": 15,
    "by_role": {
      "owner": 1,
      "admin": 3,
      "member": 11
    }
  }
}
```

### 멤버 초대

```bash
POST /api/v1/members/invite
Content-Type: application/json

{
  "email": "newuser@example.com",
  "role": "member",
  "message": "조직에 오신 것을 환영합니다!",
  "permissions": ["task.read", "task.create"]
}
```

## 📈 대시보드 API

### 태스크 통계

```bash
GET /api/v1/tasks/stats

# 쿼리 파라미터
# - period: 기간 (week, month, quarter, year)
# - team_id: 팀 ID 필터
# - assignee_id: 담당자 ID 필터

curl -H "Authorization: Bearer YOUR_TOKEN" \
  "http://api.creatia.local:3000/api/v1/tasks/stats?period=month"
```

**응답:**
```json
{
  "stats": {
    "total": 142,
    "by_status": {
      "todo": 45,
      "in_progress": 23,
      "review": 8,
      "done": 66
    },
    "by_priority": {
      "low": 32,
      "medium": 78,
      "high": 25,
      "urgent": 7
    },
    "completion_rate": 46.5,
    "avg_completion_time": 3.2,
    "trending": {
      "completed_this_week": 12,
      "completed_last_week": 8,
      "trend": "up"
    }
  }
}
```

### 알림 관리

```bash
# 읽지 않은 알림 조회
GET /api/v1/notifications?unread_only=true

# 알림 읽음 처리
POST /api/v1/notifications/:id/read

# 모든 알림 읽음 처리
POST /api/v1/notifications/mark_all_read
```

**알림 응답:**
```json
{
  "notifications": [
    {
      "id": "notif_001",
      "type": "task_assigned",
      "title": "새 태스크가 할당되었습니다",
      "message": "'새로운 기능 개발' 태스크가 할당되었습니다.",
      "read": false,
      "priority": "medium",
      "action_url": "/tasks/task_001",
      "created_at": "2025-09-28T15:30:00Z"
    }
  ],
  "unread_count": 3,
  "total": 25
}
```

## 👨‍💻 개발자 도구

### Rails 콘솔에서 API 테스트

```bash
# API 테스트 도구
bin/rails console

# 토큰 생성 테스트
> user = User.first
> org = Organization.first
> token = JwtService.encode(user_id: user.id, organization_id: org.id)
> puts token

# API 엔드포인트 테스트
> response = HTTP.auth("Bearer #{token}")
>               .get("http://api.creatia.local:3000/api/v1/tasks")
> puts response.body

# JSON 파싱
> data = JSON.parse(response.body)
> puts data['tasks'].first['title']
```

### Curl을 이용한 빠른 테스트

```bash
# 환경변수 설정
export API_TOKEN="your_jwt_token_here"
export API_BASE="http://api.creatia.local:3000/api/v1"

# 태스크 목록 조회
curl -H "Authorization: Bearer $API_TOKEN" "$API_BASE/tasks" | jq

# 새 태스크 생성
curl -X POST -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"task": {"title": "테스트 태스크", "priority": "medium"}}' \
  "$API_BASE/tasks" | jq

# 조직 정보 조회
curl -H "Authorization: Bearer $API_TOKEN" "$API_BASE/organizations/current" | jq
```

## 🔧 API 테스트

### Postman Collection

API 테스트를 위한 Postman Collection을 제공합니다:

```json
{
  "info": {
    "name": "Creatia API",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "variable": [
    {
      "key": "base_url",
      "value": "http://api.creatia.local:3000/api/v1"
    },
    {
      "key": "token",
      "value": "your_jwt_token"
    }
  ]
}
```

### API 상태 확인

```bash
# 헬스체크
curl http://api.creatia.local:3000/api/v1/health/status

# 응답:
{
  "status": "ok",
  "timestamp": "2025-09-28T15:30:00Z",
  "version": "1.0.0",
  "environment": "development",
  "services": {
    "postgresql": "connected",
    "mongodb": "connected",
    "redis": "connected"
  }
}

# 상세 헬스체크
curl http://api.creatia.local:3000/api/v1/health/detailed
```

### 에러 처리

API는 표준 HTTP 상태 코드를 사용합니다:

```json
// 400 Bad Request
{
  "error": "validation_failed",
  "message": "제목은 필수입니다",
  "details": {
    "title": ["can't be blank"]
  }
}

// 401 Unauthorized
{
  "error": "unauthorized",
  "message": "유효하지 않은 토큰입니다"
}

// 403 Forbidden
{
  "error": "forbidden",
  "message": "이 작업을 수행할 권한이 없습니다"
}

// 404 Not Found
{
  "error": "not_found",
  "message": "태스크를 찾을 수 없습니다"
}

// 422 Unprocessable Entity
{
  "error": "unprocessable_entity",
  "message": "잘못된 데이터입니다",
  "details": {
    "due_date": ["must be in the future"]
  }
}
```

### Rate Limiting

API는 사용량 제한이 있습니다:

```bash
# 응답 헤더에서 확인
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1632825600

# 제한 초과 시 응답 (429 Too Many Requests)
{
  "error": "rate_limit_exceeded",
  "message": "API 호출 한도를 초과했습니다",
  "retry_after": 3600
}
```

---

## 📚 관련 문서

- [보안 가이드](security_guide.md)
- [개발환경 설정](development_setup_guide.md)
- [데이터베이스 아키텍처](database_architecture.md)
- [메인 README](../README.md)
