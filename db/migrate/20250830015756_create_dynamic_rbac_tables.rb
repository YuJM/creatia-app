class CreateDynamicRbacTables < ActiveRecord::Migration[8.0]
  def change
    # 역할 테이블 (조직별 커스텀 역할)
    create_table :roles, id: :uuid do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.string :key, null: false # 시스템 내부 식별자 (예: custom_developer)
      t.text :description
      t.boolean :system_role, default: false # 시스템 기본 역할 여부
      t.boolean :editable, default: true # 수정 가능 여부
      t.integer :priority, default: 0 # 역할 우선순위 (높을수록 우선)
      t.jsonb :metadata, default: {} # 추가 메타데이터
      
      t.timestamps
      
      t.index [:organization_id, :key], unique: true
      t.index :system_role
      t.index :priority
    end

    # 권한 테이블 (시스템 전체 권한 정의)
    create_table :permissions, id: :uuid do |t|
      t.string :resource, null: false # 리소스 타입 (예: Task, Service, Organization)
      t.string :action, null: false # 액션 (예: read, create, update, delete, manage)
      t.string :name, null: false # 표시 이름
      t.text :description
      t.string :category # 권한 카테고리 (예: task_management, service_management)
      t.boolean :system_permission, default: true # 시스템 권한 여부
      
      t.timestamps
      
      t.index [:resource, :action], unique: true
      t.index :category
    end

    # 역할-권한 매핑 테이블
    create_table :role_permissions, id: :uuid do |t|
      t.references :role, type: :uuid, null: false, foreign_key: true
      t.references :permission, type: :uuid, null: false, foreign_key: true
      t.jsonb :conditions, default: {} # 조건부 권한 (예: own_only: true)
      t.jsonb :scope, default: {} # 권한 범위 (예: service_ids: [uuid1, uuid2])
      
      t.timestamps
      
      t.index [:role_id, :permission_id], unique: true
    end

    # 사용자-역할 매핑 업데이트를 위한 컬럼 추가
    add_reference :organization_memberships, :role, type: :uuid, foreign_key: true, null: true
    
    # 권한 템플릿 테이블 (재사용 가능한 권한 세트)
    create_table :permission_templates, id: :uuid do |t|
      t.string :name, null: false
      t.string :key, null: false, index: { unique: true }
      t.text :description
      t.jsonb :permissions, default: [] # 권한 ID 배열
      t.boolean :system_template, default: true
      
      t.timestamps
    end

    # 리소스별 권한 오버라이드 (특정 리소스에 대한 커스텀 권한)
    create_table :resource_permissions, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.string :resource_type, null: false # 다형성 리소스 타입
      t.uuid :resource_id, null: false # 리소스 ID
      t.references :permission, type: :uuid, null: false, foreign_key: true
      t.boolean :granted, default: true # 권한 부여/거부
      t.datetime :expires_at # 권한 만료 시간
      t.text :reason # 권한 부여/거부 사유
      
      t.timestamps
      
      t.index [:resource_type, :resource_id]
      t.index [:user_id, :organization_id, :resource_type, :resource_id], name: 'idx_resource_perms_on_user_org_resource'
      t.index :expires_at
    end

    # 권한 위임 테이블 (다른 사용자에게 권한 위임)
    create_table :permission_delegations, id: :uuid do |t|
      t.references :delegator, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.references :delegatee, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.references :role, type: :uuid, foreign_key: true # 위임할 역할
      t.jsonb :permissions, default: [] # 위임할 특정 권한들
      t.datetime :starts_at, null: false
      t.datetime :expires_at, null: false
      t.boolean :active, default: true
      t.text :reason
      
      t.timestamps
      
      t.index [:delegator_id, :delegatee_id, :organization_id], name: 'idx_delegations_on_users_org'
      t.index [:starts_at, :expires_at]
      t.index :active
    end

    # 감사 로그 테이블
    create_table :permission_audit_logs, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.string :action, null: false # 수행한 액션
      t.string :resource_type # 대상 리소스 타입
      t.uuid :resource_id # 대상 리소스 ID
      t.boolean :permitted # 권한 허용 여부
      t.jsonb :context, default: {} # 추가 컨텍스트 정보
      t.string :ip_address
      t.string :user_agent
      
      t.timestamps
      
      t.index [:user_id, :organization_id]
      t.index [:resource_type, :resource_id]
      t.index :permitted
      t.index :created_at
    end
  end
end