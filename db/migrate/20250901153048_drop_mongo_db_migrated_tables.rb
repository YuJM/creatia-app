class DropMongoDbMigratedTables < ActiveRecord::Migration[8.0]
  def up
    # MongoDB로 이전된 테이블들을 제거
    # 외래 키 제약 조건 때문에 의존성 순서대로 삭제
    
    # 1. pomodoro_sessions가 tasks를 참조하므로 먼저 삭제
    drop_table :pomodoro_sessions, if_exists: true
    
    # 2. tasks가 sprints를 참조할 수 있으므로 tasks 먼저 삭제
    drop_table :tasks, if_exists: true
    
    # 3. 마지막으로 sprints 삭제
    drop_table :sprints, if_exists: true
  end

  def down
    # 롤백 시 테이블 재생성 (MongoDB에서 복구 필요)
    raise ActiveRecord::IrreversibleMigration, "MongoDB로 이전된 테이블은 자동으로 복구할 수 없습니다. MongoDB 데이터를 수동으로 마이그레이션해야 합니다."
  end
end
