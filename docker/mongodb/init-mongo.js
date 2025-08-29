// MongoDB 초기화 스크립트
// 이 스크립트는 MongoDB 컨테이너가 처음 시작될 때 실행됩니다.

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
    }
  ]
});

// 컬렉션 생성 및 인덱스 설정
db.createCollection('activity_logs');
db.createCollection('error_logs');
db.createCollection('api_request_logs');

// Activity Logs 인덱스
db.activity_logs.createIndex({ created_at: -1 });
db.activity_logs.createIndex({ user_id: 1, created_at: -1 });
db.activity_logs.createIndex({ organization_id: 1, created_at: -1 });
db.activity_logs.createIndex({ action: 1, created_at: -1 });
db.activity_logs.createIndex({ status: 1 });
// TTL 인덱스 - 90일 후 자동 삭제
db.activity_logs.createIndex({ created_at: 1 }, { expireAfterSeconds: 7776000 });

// Error Logs 인덱스
db.error_logs.createIndex({ created_at: -1 });
db.error_logs.createIndex({ error_class: 1, created_at: -1 });
db.error_logs.createIndex({ severity: 1, resolved: 1 });
db.error_logs.createIndex({ organization_id: 1, created_at: -1 });
db.error_logs.createIndex({ user_id: 1 });
db.error_logs.createIndex({ resolved: 1, severity: 1 });
// TTL 인덱스 - 180일 후 자동 삭제
db.error_logs.createIndex({ created_at: 1 }, { expireAfterSeconds: 15552000 });

// API Request Logs 인덱스
db.api_request_logs.createIndex({ created_at: -1 });
db.api_request_logs.createIndex({ endpoint: 1, created_at: -1 });
db.api_request_logs.createIndex({ status_code: 1 });
db.api_request_logs.createIndex({ user_id: 1, created_at: -1 });
db.api_request_logs.createIndex({ organization_id: 1, created_at: -1 });
db.api_request_logs.createIndex({ response_time: 1 });
// TTL 인덱스 - 30일 후 자동 삭제
db.api_request_logs.createIndex({ created_at: 1 }, { expireAfterSeconds: 2592000 });

print('MongoDB initialization completed successfully!');
print('Database: creatia_logs');
print('User: creatia_user');
print('Collections: activity_logs, error_logs, api_request_logs');
print('Indexes created for all collections');