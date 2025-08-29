require 'rails_helper'

RSpec.describe ActivityLog, type: :model do
  # 테스트 후 데이터 정리
  after(:each) do
    ActivityLog.delete_all
  end

  describe 'MongoDB database' do
    it 'uses MongoDB test database' do
      expect(ActivityLog.collection.database.name).to eq('creatia_app_test')
    end

    it 'creates document in MongoDB' do
      log = ActivityLog.create!(
        user_id: 1,
        action: 'test_action',
        controller: 'TestController',
        path: '/test'
      )
      
      expect(log).to be_persisted
      expect(log.id).to be_a(BSON::ObjectId)
    end
  end

  describe 'fields and defaults' do
    let(:log) do
      ActivityLog.create!(
        user_id: 1,
        action: 'create',
        controller: 'TasksController',
        method: 'POST',
        path: '/tasks',
        ip_address: '127.0.0.1',
        user_agent: 'Mozilla/5.0',
        status: 200,
        duration: 150
      )
    end

    it 'stores all required fields' do
      expect(log.user_id).to eq(1)
      expect(log.action).to eq('create')
      expect(log.controller).to eq('TasksController')
      expect(log.method).to eq('POST')
      expect(log.path).to eq('/tasks')
      expect(log.ip_address).to eq('127.0.0.1')
      expect(log.status).to eq(200)
      expect(log.duration).to eq(150)
    end

    it 'stores optional fields' do
      log_with_metadata = ActivityLog.create!(
        user_id: 1,
        action: 'update',
        controller: 'TasksController',
        path: '/tasks/1',
        organization_id: 10,
        organization_subdomain: 'demo',
        user_email: 'user@example.com',
        params: { id: 1, status: 'completed' },
        metadata: { browser: 'Chrome', version: '120' },
        data_changes: { status: ['pending', 'completed'] }
      )

      expect(log_with_metadata.organization_id).to eq(10)
      expect(log_with_metadata.organization_subdomain).to eq('demo')
      expect(log_with_metadata.user_email).to eq('user@example.com')
      expect(log_with_metadata.params).to eq({ 'id' => 1, 'status' => 'completed' })
      expect(log_with_metadata.metadata).to include('browser' => 'Chrome')
      expect(log_with_metadata.data_changes).to include('status' => ['pending', 'completed'])
    end
  end

  describe 'scopes' do
    before do
      @user1_log = ActivityLog.create!(
        user_id: 1,
        action: 'create',
        controller: 'TasksController',
        path: '/tasks',
        created_at: 1.hour.ago
      )
      
      @user2_log = ActivityLog.create!(
        user_id: 2,
        action: 'update',
        controller: 'UsersController',
        path: '/users/2',
        created_at: 2.hours.ago
      )
      
      @org_log = ActivityLog.create!(
        user_id: 1,
        organization_id: 5,
        action: 'delete',
        controller: 'ProjectsController',
        path: '/projects/1',
        created_at: 3.hours.ago
      )
    end

    it 'filters by user' do
      user1_logs = ActivityLog.by_user(1)
      expect(user1_logs.count).to eq(2)
      expect(user1_logs).to include(@user1_log, @org_log)
      expect(user1_logs).not_to include(@user2_log)
    end

    it 'filters by organization' do
      org_logs = ActivityLog.by_organization(5)
      expect(org_logs.count).to eq(1)
      expect(org_logs).to include(@org_log)
    end

    it 'filters by action' do
      create_logs = ActivityLog.by_action('create')
      expect(create_logs.count).to eq(1)
      expect(create_logs).to include(@user1_log)
    end

    it 'orders by recent' do
      recent_logs = ActivityLog.recent
      expect(recent_logs.first).to eq(@user1_log)
      expect(recent_logs.last).to eq(@org_log)
    end
  end

  describe 'indexes' do
    it 'has proper indexes defined' do
      indexes = ActivityLog.collection.indexes.to_a
      index_keys = indexes.map { |i| i['key'] }
      
      expect(index_keys).to include({ 'created_at' => -1 })
      expect(index_keys).to include({ 'user_id' => 1, 'created_at' => -1 })
      expect(index_keys).to include({ 'organization_id' => 1, 'created_at' => -1 })
      expect(index_keys).to include({ 'action' => 1, 'created_at' => -1 })
    end

    it 'has TTL index for automatic cleanup' do
      indexes = ActivityLog.collection.indexes.to_a
      ttl_index = indexes.find { |i| i['name'] == 'activity_ttl' }
      
      expect(ttl_index).not_to be_nil
      expect(ttl_index['expireAfterSeconds']).to eq(7776000) # 90 days
    end
  end

  describe 'aggregation' do
    before do
      # 다양한 액션 로그 생성
      3.times { ActivityLog.create!(user_id: 1, action: 'create', controller: 'TasksController', path: '/tasks') }
      2.times { ActivityLog.create!(user_id: 1, action: 'update', controller: 'TasksController', path: '/tasks') }
      1.times { ActivityLog.create!(user_id: 2, action: 'delete', controller: 'TasksController', path: '/tasks') }
    end

    it 'aggregates actions by type' do
      result = ActivityLog.collection.aggregate([
        { '$group' => { '_id' => '$action', 'count' => { '$sum' => 1 } } },
        { '$sort' => { 'count' => -1 } }
      ]).to_a

      expect(result).to include({ '_id' => 'create', 'count' => 3 })
      expect(result).to include({ '_id' => 'update', 'count' => 2 })
      expect(result).to include({ '_id' => 'delete', 'count' => 1 })
    end

    it 'aggregates by user' do
      result = ActivityLog.collection.aggregate([
        { '$group' => { '_id' => '$user_id', 'count' => { '$sum' => 1 } } }
      ]).to_a

      expect(result).to include({ '_id' => 1, 'count' => 5 })
      expect(result).to include({ '_id' => 2, 'count' => 1 })
    end
  end

  describe 'performance' do
    it 'handles large metadata' do
      large_metadata = {
        request_headers: { 'User-Agent' => 'Mozilla/5.0' * 100 },
        response_data: Array.new(100) { |i| { "key_#{i}" => "value_#{i}" } },
        nested_data: {
          level1: {
            level2: {
              level3: 'deep nested value'
            }
          }
        }
      }

      log = ActivityLog.create!(
        user_id: 1,
        action: 'create',
        controller: 'TasksController',
        path: '/tasks',
        metadata: large_metadata
      )

      expect(log).to be_persisted
      expect(log.metadata['nested_data']['level1']['level2']['level3']).to eq('deep nested value')
    end

    it 'efficiently queries with indexes' do
      # 많은 데이터 생성
      100.times do |i|
        ActivityLog.create!(
          user_id: (i % 10) + 1,
          action: ['create', 'update', 'delete'].sample,
          controller: 'TasksController',
          path: "/tasks/#{i}"
        )
      end

      # 인덱스를 사용한 쿼리
      start_time = Time.current
      result = ActivityLog.by_user(1).recent.limit(10).to_a
      query_time = Time.current - start_time

      expect(result.size).to eq(10)
      expect(query_time).to be < 0.1 # 100ms 이내
    end
  end
end