# 🏗️ 데이터베이스 아키텍처

> **Creatia App 이중 데이터베이스 아키텍처**  
> PostgreSQL과 MongoDB의 하이브리드 구조로 확장성과 성능을 동시에 달성

## 📋 목차

- [🎯 아키텍처 개요](#-아키텍처-개요)
- [🐘 PostgreSQL (메타데이터)](#-postgresql-메타데이터)
- [🍃 MongoDB (실행데이터)](#-mongodb-실행데이터)
- [🔄 데이터 동기화](#-데이터-동기화)
- [📊 성능 최적화](#-성능-최적화)
- [🔧 운영 가이드](#-운영-가이드)

## 🎯 아키텍처 개요

### 이중 데이터베이스 전략

Creatia App은 각 데이터베이스의 강점을 활용한 하이브리드 아키텍처를 사용합니다:

| 데이터베이스   | 용도                                  | 저장 데이터                          | 특징                          |
| -------------- | ------------------------------------- | ------------------------------------ | ----------------------------- |
| **PostgreSQL** | 메타데이터, 관계형 데이터             | 사용자, 조직, 권한, 설정             | ACID, 트랜잭션, 관계형 무결성 |
| **MongoDB**    | 실행 데이터, 로그, 실시간 협업 데이터 | 태스크, 스프린트, 활동로그, 성능지표 | 유연성, 확장성, 실시간 성능   |

### 아키텍처 다이어그램

```
┌─────────────────┐    ┌─────────────────┐
│   Application   │    │   Application   │
│     Layer       │    │     Layer       │
└─────────┬───────┘    └─────────┬───────┘
          │                      │
    ┌─────▼──────┐         ┌─────▼──────┐
    │PostgreSQL  │         │  MongoDB   │
    │(ActiveRecord)│       │ (Mongoid)  │
    └────────────┘         └────────────┘
          │                      │
    ┌─────▼──────┐         ┌─────▼──────┐
    │    Users   │         │   Tasks    │
    │Organizations│        │  Sprints   │
    │   Roles    │         │   Logs     │
    │ Permissions│         │  Metrics   │
    └────────────┘         └────────────┘
```

### 데이터 분할 원칙

#### PostgreSQL 저장 기준

- **변경 빈도가 낮음**: 사용자 정보, 조직 설정
- **관계형 무결성 중요**: 권한 시스템, 멤버십
- **트랜잭션 필요**: 결제, 구독 관리
- **스키마가 고정적**: 구조화된 메타데이터

#### MongoDB 저장 기준

- **변경 빈도가 높음**: 태스크 상태, 활동 로그
- **유연한 스키마**: 다양한 형태의 데이터
- **실시간 성능**: 빠른 읽기/쓰기 필요
- **대용량 데이터**: 로그, 메트릭 데이터

## 🐘 PostgreSQL (메타데이터)

### 주요 테이블 구조

#### 사용자 관리

```sql
-- users 테이블
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) NOT NULL UNIQUE,
  encrypted_password VARCHAR(255) NOT NULL,
  name VARCHAR(255),
  role VARCHAR(50) DEFAULT 'user',
  provider VARCHAR(50),
  uid VARCHAR(255),
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,

  INDEX idx_users_email ON users(email),
  INDEX idx_users_provider_uid ON users(provider, uid)
);

-- organizations 테이블
CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  subdomain VARCHAR(63) NOT NULL UNIQUE,
  plan VARCHAR(50) DEFAULT 'free',
  active BOOLEAN DEFAULT true,
  settings JSONB,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,

  INDEX idx_organizations_subdomain ON organizations(subdomain),
  INDEX idx_organizations_active ON organizations(active)
);

-- organization_memberships 테이블 (멀티테넌트 관계)
CREATE TABLE organization_memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  role VARCHAR(50) DEFAULT 'member',
  active BOOLEAN DEFAULT true,
  joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  UNIQUE(user_id, organization_id),
  INDEX idx_org_memberships_user ON organization_memberships(user_id),
  INDEX idx_org_memberships_org ON organization_memberships(organization_id),
  INDEX idx_org_memberships_active ON organization_memberships(active)
);
```

#### 권한 시스템

```sql
-- roles 테이블 (동적 역할)
CREATE TABLE roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  key VARCHAR(100) NOT NULL,
  description TEXT,
  system_role BOOLEAN DEFAULT false,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,

  UNIQUE(organization_id, key),
  INDEX idx_roles_organization ON roles(organization_id),
  INDEX idx_roles_system ON roles(system_role)
);

-- permissions 테이블
CREATE TABLE permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL UNIQUE,
  resource VARCHAR(100) NOT NULL,
  action VARCHAR(100) NOT NULL,
  description TEXT,
  created_at TIMESTAMP NOT NULL,

  INDEX idx_permissions_resource_action ON permissions(resource, action)
);

-- role_permissions 테이블 (역할-권한 매핑)
CREATE TABLE role_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  granted BOOLEAN DEFAULT true,
  created_at TIMESTAMP NOT NULL,

  UNIQUE(role_id, permission_id),
  INDEX idx_role_permissions_role ON role_permissions(role_id),
  INDEX idx_role_permissions_permission ON role_permissions(permission_id)
);
```

### 인덱싱 전략

```sql
-- 복합 인덱스 (쿼리 패턴 기반)
CREATE INDEX idx_org_memberships_org_active
  ON organization_memberships(organization_id, active);

-- 부분 인덱스 (선택적 데이터만)
CREATE INDEX idx_users_active_admin
  ON users(id) WHERE role = 'admin' AND active = true;

-- JSONB 인덱스 (설정 데이터)
CREATE INDEX idx_organizations_settings_gin
  ON organizations USING gin(settings);

-- 전문 검색 인덱스
CREATE INDEX idx_users_name_trgm
  ON users USING gin(name gin_trgm_ops);
```

### 파티셔닝 전략

```sql
-- 시간 기반 파티셔닝 (감사 로그)
CREATE TABLE permission_audit_logs (
  id UUID NOT NULL,
  organization_id UUID NOT NULL,
  user_id UUID NOT NULL,
  action VARCHAR(100) NOT NULL,
  resource_type VARCHAR(100),
  resource_id UUID,
  changes JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMP NOT NULL
) PARTITION BY RANGE (created_at);

-- 월별 파티션 생성
CREATE TABLE permission_audit_logs_2025_09
  PARTITION OF permission_audit_logs
  FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');

CREATE TABLE permission_audit_logs_2025_10
  PARTITION OF permission_audit_logs
  FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');
```

## 🍃 MongoDB (실행데이터)

### 컬렉션 구조

#### 태스크 컬렉션

```javascript
// tasks 컬렉션
{
  _id: ObjectId("..."),

  // PostgreSQL 참조 (UUID)
  organization_id: "uuid-string",
  service_id: "uuid-string",
  sprint_id: "uuid-string",
  created_by_id: "uuid-string",

  // 태스크 식별
  task_id: "TASK-001",
  external_id: "github-123",

  // 태스크 정보
  title: "새로운 기능 개발",
  description: "사용자 대시보드 개선",
  task_type: "feature",

  // 할당 정보
  assignee_id: "uuid-string",
  reviewer_id: "uuid-string",
  team_id: "uuid-string",

  // 사용자 스냅샷 (성능 최적화)
  assignee_snapshot: {
    user_id: "uuid-string",
    name: "김개발",
    email: "dev@example.com",
    avatar_url: "https://...",
    synced_at: ISODate("2025-09-28T10:00:00Z")
  },

  // 상태 및 우선순위
  status: "in_progress",
  priority: "high",
  position: 100,

  // 시간 추적
  estimated_hours: 8.0,
  actual_hours: 3.5,
  remaining_hours: 4.5,
  time_entries: [
    {
      user_id: "uuid-string",
      hours: 2.0,
      description: "초기 설계",
      logged_at: ISODate("2025-09-28T09:00:00Z")
    }
  ],

  // 날짜
  due_date: ISODate("2025-10-01T00:00:00Z"),
  start_date: ISODate("2025-09-28T00:00:00Z"),
  completed_at: null,

  // 메타데이터
  tags: ["frontend", "ui", "dashboard"],
  labels: ["urgent", "customer-request"],

  // 감사 정보
  created_at: ISODate("2025-09-28T08:00:00Z"),
  updated_at: ISODate("2025-09-28T14:30:00Z")
}
```

#### 스프린트 컬렉션

```javascript
// sprints 컬렉션
{
  _id: ObjectId("..."),

  // PostgreSQL 참조
  organization_id: "uuid-string",
  milestone_id: "uuid-string",

  // 스프린트 정보
  name: "Sprint 2025-10",
  goal: "사용자 경험 개선",
  status: "active",

  // 기간
  start_date: ISODate("2025-09-23T00:00:00Z"),
  end_date: ISODate("2025-10-06T23:59:59Z"),

  // 용량 계획
  capacity: {
    total_hours: 160,
    allocated_hours: 120,
    available_hours: 40
  },

  // 메트릭 (실시간 계산)
  metrics: {
    total_tasks: 15,
    completed_tasks: 8,
    in_progress_tasks: 5,
    todo_tasks: 2,
    completion_rate: 53.3,
    burndown_data: [
      { date: "2025-09-23", remaining_hours: 120 },
      { date: "2025-09-24", remaining_hours: 110 },
      // ...
    ]
  },

  // 회고 데이터
  retrospective: {
    what_went_well: ["좋은 팀워크", "빠른 배포"],
    what_to_improve: ["코드 리뷰 시간", "테스트 커버리지"],
    action_items: ["코드 리뷰 체크리스트 도입"]
  },

  created_at: ISODate("2025-09-20T10:00:00Z"),
  updated_at: ISODate("2025-09-28T15:00:00Z")
}
```

#### 활동 로그 컬렉션

```javascript
// activity_logs 컬렉션
{
  _id: ObjectId("..."),

  // 기본 정보
  organization_id: "uuid-string",
  user_id: "uuid-string",

  // 활동 정보
  action: "task.status_changed",
  resource_type: "Task",
  resource_id: "task-uuid",

  // 변경 사항
  changes: {
    status: {
      from: "todo",
      to: "in_progress"
    }
  },

  // 메타데이터
  metadata: {
    user_agent: "Mozilla/5.0...",
    ip_address: "192.168.1.100",
    api_version: "v1",
    client_type: "web"
  },

  // 시간 정보
  timestamp: ISODate("2025-09-28T14:30:00Z"),
  created_at: ISODate("2025-09-28T14:30:00Z")
}
```

### 인덱싱 전략

```javascript
// MongoDB 인덱스 생성
db.tasks.createIndex(
  { organization_id: 1, status: 1, created_at: -1 },
  { name: "idx_tasks_org_status_created" }
);

db.tasks.createIndex(
  { assignee_id: 1, status: 1 },
  { name: "idx_tasks_assignee_status" }
);

db.tasks.createIndex({ due_date: 1 }, { name: "idx_tasks_due_date" });

// 텍스트 검색 인덱스
db.tasks.createIndex(
  {
    title: "text",
    description: "text",
    tags: "text"
  },
  {
    name: "idx_tasks_text_search",
    default_language: "korean"
  }
);

// TTL 인덱스 (로그 자동 삭제)
db.activity_logs.createIndex(
  { created_at: 1 },
  {
    name: "idx_activity_logs_ttl",
    expireAfterSeconds: 2592000 // 30일
  }
);

// 부분 인덱스 (활성 태스크만)
db.tasks.createIndex(
  { organization_id: 1, assignee_id: 1 },
  {
    name: "idx_tasks_org_assignee_active",
    partialFilterExpression: {
      status: { $in: ["todo", "in_progress", "review"] }
    }
  }
);
```

### 샤딩 전략

```javascript
// 샤드 키 설정 (조직 기반)
sh.enableSharding("creatia_logs");

// tasks 컬렉션 샤딩
sh.shardCollection("creatia_logs.tasks", { organization_id: 1, _id: 1 });

// activity_logs 컬렉션 샤딩 (시간 기반)
sh.shardCollection("creatia_logs.activity_logs", {
  organization_id: 1,
  created_at: 1
});
```

## 🔄 데이터 동기화

### 사용자 스냅샷 시스템

PostgreSQL의 사용자 정보를 MongoDB에 캐시하여 조인 쿼리 없이 빠른 읽기 성능을 제공:

```ruby
# app/models/user_snapshot.rb
class UserSnapshot
  include Mongoid::Document
  include Mongoid::Timestamps

  # 사용자 정보 스냅샷
  field :user_id, type: String
  field :name, type: String
  field :email, type: String
  field :avatar_url, type: String
  field :department, type: String
  field :position, type: String
  field :synced_at, type: DateTime

  index({ user_id: 1 }, { unique: true })

  # 신선도 확인 (5분 이내)
  def fresh?
    synced_at && synced_at > 5.minutes.ago
  end

  # User 객체로 변환
  def to_user
    OpenStruct.new(
      id: user_id,
      name: name,
      email: email,
      avatar_url: avatar_url,
      department: department,
      position: position
    )
  end

  # PostgreSQL User로부터 동기화
  def self.from_user(user)
    find_or_initialize_by(user_id: user.id.to_s).tap do |snapshot|
      snapshot.name = user.name
      snapshot.email = user.email
      snapshot.avatar_url = user.avatar_url if user.respond_to?(:avatar_url)
      snapshot.department = user.department if user.respond_to?(:department)
      snapshot.position = user.position if user.respond_to?(:position)
      snapshot.synced_at = Time.current
    end
  end
end
```

### 실시간 동기화

```ruby
# app/jobs/mongodb_snapshot_sync_job.rb
class MongodbSnapshotSyncJob < ApplicationJob
  queue_as :default

  def perform(user)
    # 사용자 스냅샷 업데이트
    snapshot = UserSnapshot.from_user(user)
    snapshot.save!

    # 연관된 태스크들의 스냅샷 업데이트
    update_task_snapshots(user)

    Rails.logger.info "User snapshot synced: #{user.id}"
  end

  private

  def update_task_snapshots(user)
    # 할당된 태스크 업데이트
    Task.where(assignee_id: user.id.to_s).each do |task|
      task.sync_assignee_snapshot!(user)
    end

    # 리뷰어로 지정된 태스크 업데이트
    Task.where(reviewer_id: user.id.to_s).each do |task|
      task.sync_reviewer_snapshot!(user)
    end
  end
end
```

### 데이터 일관성 보장

```ruby
# app/services/cross_db_sync_service.rb
class CrossDbSyncService
  def self.ensure_consistency
    check_orphaned_tasks
    check_missing_snapshots
    check_data_integrity
  end

  private

  def self.check_orphaned_tasks
    # MongoDB에 있지만 PostgreSQL 조직이 없는 태스크
    orphaned_count = Task.where(
      :organization_id.nin => Organization.pluck(:id).map(&:to_s)
    ).count

    if orphaned_count > 0
      Rails.logger.warn "Found #{orphaned_count} orphaned tasks"
      # 알림 또는 정리 작업 수행
    end
  end

  def self.check_missing_snapshots
    # 스냅샷이 없는 태스크 찾기
    tasks_without_snapshots = Task.where(
      :assignee_id.exists => true,
      :assignee_snapshot_id.exists => false
    )

    tasks_without_snapshots.each do |task|
      user = User.find_by(id: task.assignee_id)
      task.sync_assignee_snapshot!(user) if user
    end
  end

  def self.check_data_integrity
    # 정기적인 데이터 무결성 검사
    CheckDataIntegrityJob.perform_later
  end
end
```

## 📊 성능 최적화

### 쿼리 최적화

#### PostgreSQL 최적화

```ruby
# 인덱스 활용도 확인
def check_index_usage
  sql = <<~SQL
    SELECT
      schemaname,
      tablename,
      indexname,
      idx_tup_read,
      idx_tup_fetch,
      idx_scan,
      CASE
        WHEN idx_scan = 0 THEN 'Unused'
        WHEN idx_scan < 100 THEN 'Low usage'
        ELSE 'Good usage'
      END as usage_status
    FROM pg_stat_user_indexes
    ORDER BY idx_scan ASC;
  SQL

  ActiveRecord::Base.connection.execute(sql)
end

# 느린 쿼리 분석
def analyze_slow_queries
  # pg_stat_statements 확장 필요
  sql = <<~SQL
    SELECT
      query,
      calls,
      mean_time,
      total_time,
      (total_time/calls) as avg_time_ms
    FROM pg_stat_statements
    WHERE mean_time > 100  -- 100ms 이상
    ORDER BY mean_time DESC
    LIMIT 10;
  SQL

  ActiveRecord::Base.connection.execute(sql)
end
```

#### MongoDB 최적화

```javascript
// 쿼리 성능 분석
db.tasks
  .explain("executionStats")
  .find({
    organization_id: "org-uuid",
    status: "in_progress"
  })
  .sort({ created_at: -1 });

// 집계 파이프라인 최적화
db.tasks.aggregate(
  [
    {
      $match: {
        organization_id: "org-uuid",
        created_at: { $gte: ISODate("2025-09-01") }
      }
    },
    {
      $group: {
        _id: "$status",
        count: { $sum: 1 },
        avg_hours: { $avg: "$estimated_hours" }
      }
    },
    { $sort: { count: -1 } }
  ],
  { allowDiskUse: true }
);

// 인덱스 힌트 사용
db.tasks
  .find({
    assignee_id: "user-uuid"
  })
  .hint({ assignee_id: 1, status: 1 });
```

### 캐싱 전략

```ruby
# app/services/cache_service.rb
class CacheService
  # 조직별 태스크 통계 캐싱 (5분)
  def self.task_stats(organization_id)
    Rails.cache.fetch("task_stats:#{organization_id}", expires_in: 5.minutes) do
      calculate_task_stats(organization_id)
    end
  end

  # 사용자별 대시보드 데이터 캐싱 (10분)
  def self.user_dashboard(user_id, organization_id)
    cache_key = "dashboard:#{user_id}:#{organization_id}"
    Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
      build_dashboard_data(user_id, organization_id)
    end
  end

  # 캐시 무효화
  def self.invalidate_task_cache(organization_id)
    Rails.cache.delete("task_stats:#{organization_id}")
    # 관련 사용자 캐시도 무효화
    organization = Organization.find(organization_id)
    organization.users.pluck(:id).each do |user_id|
      Rails.cache.delete("dashboard:#{user_id}:#{organization_id}")
    end
  end

  private

  def self.calculate_task_stats(organization_id)
    # MongoDB 집계 쿼리로 통계 계산
    Task.collection.aggregate([
      { "$match" => { "organization_id" => organization_id } },
      { "$group" => {
        "_id" => "$status",
        "count" => { "$sum" => 1 },
        "total_hours" => { "$sum" => "$estimated_hours" }
      }}
    ]).to_a
  end
end
```

### 배치 처리 최적화

```ruby
# app/jobs/batch_sync_job.rb
class BatchSyncJob < ApplicationJob
  queue_as :low_priority

  def perform
    # 배치 크기로 나누어 처리
    User.includes(:organizations).find_in_batches(batch_size: 100) do |users|
      sync_user_snapshots(users)
    end
  end

  private

  def sync_user_snapshots(users)
    # 벌크 업데이트로 성능 최적화
    operations = users.map do |user|
      snapshot_data = {
        user_id: user.id.to_s,
        name: user.name,
        email: user.email,
        synced_at: Time.current
      }

      {
        update_one: {
          filter: { user_id: user.id.to_s },
          update: { "$set" => snapshot_data },
          upsert: true
        }
      }
    end

    UserSnapshot.collection.bulk_write(operations, ordered: false)
  end
end
```

## 🔧 운영 가이드

### 백업 전략

#### PostgreSQL 백업

```bash
# 일일 백업 스크립트
#!/bin/bash
BACKUP_DIR="/backups/postgresql"
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="creatia_production"

# 덤프 생성
pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME \
  --no-password --verbose --clean --create \
  --format=custom \
  --file="$BACKUP_DIR/creatia_${DATE}.backup"

# 암호화
gpg --cipher-algo AES256 --compress-algo 1 --symmetric \
  --output "$BACKUP_DIR/creatia_${DATE}.backup.gpg" \
  "$BACKUP_DIR/creatia_${DATE}.backup"

# 원본 삭제
rm "$BACKUP_DIR/creatia_${DATE}.backup"

# 30일 이상 된 백업 삭제
find $BACKUP_DIR -name "*.backup.gpg" -mtime +30 -delete
```

#### MongoDB 백업

```bash
# MongoDB 백업 스크립트
#!/bin/bash
BACKUP_DIR="/backups/mongodb"
DATE=$(date +%Y%m%d_%H%M%S)

# 덤프 생성
mongodump --host $MONGO_HOST --port $MONGO_PORT \
  --username $MONGO_USER --password $MONGO_PASS \
  --db creatia_logs \
  --out "$BACKUP_DIR/dump_${DATE}"

# 압축
tar -czf "$BACKUP_DIR/creatia_logs_${DATE}.tar.gz" \
  -C "$BACKUP_DIR" "dump_${DATE}"

# 임시 폴더 삭제
rm -rf "$BACKUP_DIR/dump_${DATE}"

# 암호화
gpg --cipher-algo AES256 --compress-algo 1 --symmetric \
  --output "$BACKUP_DIR/creatia_logs_${DATE}.tar.gz.gpg" \
  "$BACKUP_DIR/creatia_logs_${DATE}.tar.gz"

rm "$BACKUP_DIR/creatia_logs_${DATE}.tar.gz"
```

### 모니터링

#### PostgreSQL 모니터링

```sql
-- 연결 상태 확인
SELECT
  state,
  count(*) as connection_count
FROM pg_stat_activity
WHERE datname = 'creatia_production'
GROUP BY state;

-- 테이블 사이즈 확인
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- 인덱스 사용률 확인
SELECT
  schemaname,
  tablename,
  round((seq_scan::float / (seq_scan + idx_scan) * 100), 2) as seq_scan_ratio
FROM pg_stat_user_tables
WHERE seq_scan + idx_scan > 0
ORDER BY seq_scan_ratio DESC;
```

#### MongoDB 모니터링

```javascript
// 연결 상태 확인
db.runCommand({ connectionStatus: 1 });

// 컬렉션 통계
db.stats();
db.tasks.stats();

// 느린 작업 확인
db.setProfilingLevel(2, { slowms: 100 });
db.system.profile.find().sort({ ts: -1 }).limit(5);

// 현재 실행 중인 작업
db.currentOp();

// 인덱스 사용 통계
db.tasks.aggregate([{ $indexStats: {} }]);
```

### 장애 대응

#### 데이터베이스 연결 장애

```ruby
# config/initializers/database_fallback.rb
class DatabaseHealthChecker
  def self.check_postgresql
    ActiveRecord::Base.connection.execute("SELECT 1")
    true
  rescue => e
    Rails.logger.error "PostgreSQL health check failed: #{e.message}"
    false
  end

  def self.check_mongodb
    Mongoid.default_client.command(ping: 1)
    true
  rescue => e
    Rails.logger.error "MongoDB health check failed: #{e.message}"
    false
  end

  def self.system_status
    {
      postgresql: check_postgresql,
      mongodb: check_mongodb,
      timestamp: Time.current
    }
  end
end

# 헬스체크 엔드포인트
class HealthController < ApplicationController
  def database
    status = DatabaseHealthChecker.system_status

    if status[:postgresql] && status[:mongodb]
      render json: { status: 'ok', details: status }
    else
      render json: {
        status: 'error',
        details: status
      }, status: :service_unavailable
    end
  end
end
```

#### 자동 복구 메커니즘

```ruby
# app/jobs/database_recovery_job.rb
class DatabaseRecoveryJob < ApplicationJob
  queue_as :critical

  def perform
    unless DatabaseHealthChecker.check_mongodb
      Rails.logger.error "MongoDB connection failed - attempting recovery"

      # 연결 풀 재설정
      Mongoid::Clients.clear
      Mongoid.load_configuration

      # 재연결 시도
      if DatabaseHealthChecker.check_mongodb
        Rails.logger.info "MongoDB connection recovered"
      else
        # 알림 발송
        SystemAlertService.notify("MongoDB connection failed")
      end
    end
  end
end
```

---

## 📚 관련 문서

- [API 사용 가이드](api_usage_guide.md)
- [보안 가이드](security_guide.md)
- [개발환경 설정](development_setup_guide.md)
- [메인 README](../README.md)




