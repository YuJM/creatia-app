// MongoDB Atlas Local 초기화 스크립트
// MongoDB Atlas Local 컨테이너가 처음 시작될 때 실행됩니다.

// admin 데이터베이스에서 시작
db = db.getSiblingDB('admin');

// creatia_logs 데이터베이스로 전환
db = db.getSiblingDB('creatia_logs');

// 애플리케이션용 사용자 생성
db.createUser({
  user: 'creatia_user',
  pwd: 'creatia_pass',
  roles: [
    {
      role: 'readWrite',
      db: 'creatia_logs'
    },
    {
      role: 'dbAdmin',
      db: 'creatia_logs'
    }
  ]
});

print('✅ User created: creatia_user');

// 컬렉션 생성
db.createCollection('activity_logs');
db.createCollection('error_logs');
db.createCollection('api_request_logs');

print('✅ Collections created');

// Activity Logs 인덱스
db.activity_logs.createIndex({ created_at: -1 });
db.activity_logs.createIndex({ user_id: 1, created_at: -1 });
db.activity_logs.createIndex({ organization_id: 1, created_at: -1 });
db.activity_logs.createIndex({ action: 1, created_at: -1 });
db.activity_logs.createIndex({ status: 1 });
// TTL 인덱스 - 90일 후 자동 삭제
db.activity_logs.createIndex(
  { created_at: 1 },
  { expireAfterSeconds: 7776000, name: 'activity_ttl' }
);

print('✅ Activity logs indexes created');

// Error Logs 인덱스
db.error_logs.createIndex({ created_at: -1 });
db.error_logs.createIndex({ error_class: 1, created_at: -1 });
db.error_logs.createIndex({ severity: 1, resolved: 1 });
db.error_logs.createIndex({ organization_id: 1, created_at: -1 });
db.error_logs.createIndex({ user_id: 1 });
db.error_logs.createIndex({ resolved: 1, severity: 1 });
// TTL 인덱스 - 180일 후 자동 삭제
db.error_logs.createIndex(
  { created_at: 1 },
  { expireAfterSeconds: 15552000, name: 'error_ttl' }
);

print('✅ Error logs indexes created');

// API Request Logs 인덱스
db.api_request_logs.createIndex({ created_at: -1 });
db.api_request_logs.createIndex({ endpoint: 1, created_at: -1 });
db.api_request_logs.createIndex({ status_code: 1 });
db.api_request_logs.createIndex({ user_id: 1, created_at: -1 });
db.api_request_logs.createIndex({ organization_id: 1, created_at: -1 });
db.api_request_logs.createIndex({ response_time: 1 });
// TTL 인덱스 - 30일 후 자동 삭제
db.api_request_logs.createIndex(
  { created_at: 1 },
  { expireAfterSeconds: 2592000, name: 'api_ttl' }
);

print('✅ API request logs indexes created');

// 테스트 데이터베이스 설정
db = db.getSiblingDB('creatia_logs_test');

// 테스트용 사용자 생성
db.createUser({
  user: 'creatia_user',
  pwd: 'creatia_pass',
  roles: [
    {
      role: 'readWrite',
      db: 'creatia_logs_test'
    },
    {
      role: 'dbAdmin',
      db: 'creatia_logs_test'
    }
  ]
});

// 테스트 데이터베이스 컬렉션 생성
db.createCollection('activity_logs');
db.createCollection('error_logs');
db.createCollection('api_request_logs');

print('✅ Test database setup completed');

// 초기화 완료 메시지
print('');
print('========================================');
print('MongoDB Atlas Local initialization completed!');
print('========================================');
print('');
print('📊 Databases created:');
print('  - creatia_logs (main)');
print('  - creatia_logs_test (test)');
print('');
print('👤 User credentials:');
print('  - Username: creatia_user');
print('  - Password: creatia_pass');
print('');
print('📦 Collections created:');
print('  - activity_logs');
print('  - error_logs');
print('  - api_request_logs');
print('');
print('🔍 Indexes created with TTL:');
print('  - Activity logs: 90 days retention');
print('  - Error logs: 180 days retention');
print('  - API logs: 30 days retention');
print('');
print('🔗 Connection strings:');
print('  Development: mongodb://creatia_user:creatia_pass@localhost:27017/creatia_logs');
print('  Test: mongodb://creatia_user:creatia_pass@localhost:27017/creatia_logs_test');
print('========================================');