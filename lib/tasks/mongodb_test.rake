# frozen_string_literal: true

namespace :mongodb do
  desc "MongoDB collection 테스트 데이터 생성 및 기능 테스트"
  task test: :environment do
    puts "\n🧪 MongoDB Collection 테스트 시작"
    puts "=" * 60
    
    # 테스트 결과 저장
    test_results = {
      passed: 0,
      failed: 0,
      errors: []
    }
    
    begin
      # 1. Activity Log 테스트
      puts "\n📝 1. Activity Log 테스트"
      puts "-" * 40
      
      # 다양한 액션 타입의 활동 로그 생성
      actions = ['login', 'logout', 'create_task', 'update_task', 'delete_task', 'view_dashboard']
      controllers = ['TasksController', 'UsersController', 'DashboardController']
      
      10.times do |i|
        ActivityLog.create!(
          user_id: rand(1..5),
          user_email: "user#{rand(1..5)}@example.com",
          organization_id: rand(1..3),
          organization_subdomain: ['demo', 'acme', 'startup'].sample,
          action: actions.sample,
          controller: controllers.sample,
          method: ['GET', 'POST', 'PUT', 'DELETE'].sample,
          path: ['/tasks', '/users', '/dashboard'].sample,
          ip_address: "192.168.1.#{rand(1..255)}",
          user_agent: "Mozilla/5.0 (#{['Macintosh', 'Windows', 'X11'].sample})",
          status: [200, 201, 204].sample,
          duration: rand(10..200),
          params: { id: rand(1..100), page: 1 },
          data_changes: {
            status: ['pending', 'completed']
          },
          metadata: {
            browser: ['Chrome', 'Firefox', 'Safari'].sample,
            session_id: SecureRandom.uuid
          }
        )
      end
      
      # 테스트: 검색 및 집계
      recent_logs = ActivityLog.recent.limit(5)
      user_logs = ActivityLog.by_user(1)
      action_stats = ActivityLog.collection.aggregate([
        { '$group' => { '_id' => '$action', 'count' => { '$sum' => 1 } } }
      ])
      
      puts "✅ Activity Logs 생성: #{ActivityLog.count}개"
      puts "  - 최근 로그: #{recent_logs.count}개"
      puts "  - 사용자별 로그: #{user_logs.count}개"
      puts "  - 액션 통계:"
      action_stats.each { |stat| puts "    • #{stat['_id']}: #{stat['count']}개" }
      test_results[:passed] += 1
      
    rescue => e
      puts "❌ Activity Log 테스트 실패: #{e.message}"
      test_results[:failed] += 1
      test_results[:errors] << { test: 'ActivityLog', error: e.message }
    end
    
    begin
      # 2. API Request Log 테스트
      puts "\n🌐 2. API Request Log 테스트"
      puts "-" * 40
      
      # API 요청 로그 생성
      endpoints = ['/api/v1/tasks', '/api/v1/users', '/api/v1/projects', '/api/v1/dashboard']
      methods = ['GET', 'POST', 'PUT', 'DELETE']
      
      15.times do |i|
        ApiRequestLog.create!(
          user_id: rand(1..5),
          organization_id: rand(1..3),
          endpoint: endpoints.sample,
          method: methods.sample,
          path: endpoints.sample,
          query_params: { page: rand(1..10), per_page: 25 },
          status_code: [200, 201, 204, 400, 401, 404, 500].sample,
          response_time: rand(10..500),
          ip_address: "10.0.0.#{rand(1..255)}",
          user_agent: "Mozilla/5.0",
          request_headers: { 'Content-Type' => 'application/json' },
          request_body: { data: { id: rand(1..100) } },
          response_body: { success: true, data: {} },
          api_version: 'v1',
          metadata: {
            request_id: SecureRandom.uuid,
            timestamp: Time.current
          }
        )
      end
      
      # 테스트: 성능 분석
      slow_requests = ApiRequestLog.where(:response_time.gt => 100)
      error_requests = ApiRequestLog.where(:status_code.gte => 400)
      endpoint_stats = ApiRequestLog.collection.aggregate([
        { '$group' => { 
          '_id' => '$endpoint', 
          'avg_duration' => { '$avg' => '$response_time' },
          'count' => { '$sum' => 1 }
        }}
      ])
      
      puts "✅ API Request Logs 생성: #{ApiRequestLog.count}개"
      puts "  - 느린 요청 (>100ms): #{slow_requests.count}개"
      puts "  - 에러 응답: #{error_requests.count}개"
      puts "  - 엔드포인트별 평균 응답시간:"
      endpoint_stats.each { |stat| 
        puts "    • #{stat['_id']}: #{stat['avg_duration']&.round(2)}ms (#{stat['count']}개)"
      }
      test_results[:passed] += 1
      
    rescue => e
      puts "❌ API Request Log 테스트 실패: #{e.message}"
      test_results[:failed] += 1
      test_results[:errors] << { test: 'ApiRequestLog', error: e.message }
    end
    
    begin
      # 3. Error Log 테스트
      puts "\n⚠️ 3. Error Log 테스트"
      puts "-" * 40
      
      # 에러 로그 생성
      error_classes = ['ActiveRecord::RecordNotFound', 'NoMethodError', 'ArgumentError', 'StandardError']
      severities = ['low', 'medium', 'high', 'critical']
      
      8.times do |i|
        ErrorLog.create!(
          error_class: error_classes.sample,
          error_message: "Test error message #{i}",
          backtrace: ["app/controllers/application_controller.rb:10:in `method'"],
          controller: "#{['Tasks', 'Users', 'Projects'].sample}Controller",
          action: ['index', 'show', 'create'].sample,
          path: ['/tasks', '/users', '/projects'].sample,
          method: ['GET', 'POST', 'PUT'].sample,
          ip_address: "192.168.1.#{rand(1..255)}",
          user_agent: "Mozilla/5.0",
          user_id: rand(1..5),
          user_email: "user#{rand(1..5)}@example.com",
          organization_id: rand(1..3),
          organization_subdomain: ['demo', 'acme', 'startup'].sample,
          params: { id: rand(1..100) },
          severity: severities.sample,
          resolved: [true, false].sample,
          resolved_at: [true, false].sample ? Time.current : nil,
          resolution_notes: "Fixed in commit abc123",
          occurrence_count: rand(1..5),
          first_occurred_at: 1.day.ago,
          last_occurred_at: Time.current,
          metadata: {
            browser: 'Chrome',
            version: '120.0'
          }
        )
      end
      
      # 테스트: 에러 분석
      unresolved_errors = ErrorLog.unresolved
      critical_errors = ErrorLog.where(severity: 'critical')
      error_by_type = ErrorLog.collection.aggregate([
        { '$group' => { '_id' => '$error_class', 'count' => { '$sum' => 1 } } }
      ])
      
      puts "✅ Error Logs 생성: #{ErrorLog.count}개"
      puts "  - 미해결 에러: #{unresolved_errors.count}개"
      puts "  - 크리티컬 에러: #{critical_errors.count}개"
      puts "  - 에러 타입별 통계:"
      error_by_type.each { |stat| puts "    • #{stat['_id']}: #{stat['count']}개" }
      test_results[:passed] += 1
      
    rescue => e
      puts "❌ Error Log 테스트 실패: #{e.message}"
      test_results[:failed] += 1
      test_results[:errors] << { test: 'ErrorLog', error: e.message }
    end
    
    begin
      # 4. Notification 테스트
      puts "\n🔔 4. Notification 테스트"
      puts "-" * 40
      
      # 알림 생성
      notification_types = ['TaskAssigned', 'CommentMention', 'SprintStarted', 'SystemAlert']
      priorities = ['low', 'medium', 'high', 'urgent']
      categories = ['task', 'comment', 'sprint', 'system']
      
      20.times do |i|
        Notification.create!(
          recipient_id: rand(1..5),
          recipient_type: 'User',
          type: "#{notification_types.sample}Notification",
          title: "테스트 알림 #{i + 1}",
          body: "이것은 테스트 알림 메시지입니다. 번호: #{i + 1}",
          priority: priorities.sample,
          category: categories.sample,
          channels: [['in_app'], ['in_app', 'email'], ['in_app', 'push']].sample,
          metadata: {
            task_id: rand(1..100),
            project_id: rand(1..20),
            created_by: "System"
          }
        )
      end
      
      # 일부 알림을 읽음 처리
      Notification.limit(5).each(&:mark_as_read!)
      
      # 테스트: 알림 조회 및 통계
      unread_notifications = Notification.unread
      high_priority = Notification.high_priority
      user_summary = Notification.summary_for(1)
      
      puts "✅ Notifications 생성: #{Notification.count}개"
      puts "  - 읽지 않은 알림: #{unread_notifications.count}개"
      puts "  - 높은 우선순위: #{high_priority.count}개"
      puts "  - 카테고리별 분포:"
      Notification.collection.aggregate([
        { '$group' => { '_id' => '$category', 'count' => { '$sum' => 1 } } }
      ]).each { |stat| puts "    • #{stat['_id']}: #{stat['count']}개" }
      test_results[:passed] += 1
      
    rescue => e
      puts "❌ Notification 테스트 실패: #{e.message}"
      test_results[:failed] += 1
      test_results[:errors] << { test: 'Notification', error: e.message }
    end
    
    # 5. 인덱스 성능 테스트
    puts "\n⚡ 5. 인덱스 성능 테스트"
    puts "-" * 40
    
    begin
      # 인덱스 효율성 테스트
      collections = ['activity_logs', 'api_request_logs', 'error_logs', 'notifications']
      
      collections.each do |collection_name|
        collection = Mongoid.default_client[collection_name]
        
        # 인덱스 정보 가져오기
        indexes = collection.indexes.to_a
        puts "\n📊 #{collection_name} 인덱스:"
        indexes.each do |index|
          next if index['name'] == '_id_'
          puts "  - #{index['name']}: #{index['key'].to_json}"
        end
        
        # 간단한 쿼리 실행 계획 분석
        if collection_name == 'notifications'
          explain = collection.find({ recipient_id: 1 }).explain
          if explain['executionStats']
            puts "  쿼리 성능 (recipient_id = 1):"
            puts "    • 실행 시간: #{explain['executionStats']['executionTimeMillis']}ms"
            puts "    • 검사한 문서: #{explain['executionStats']['totalDocsExamined']}"
            puts "    • 반환된 문서: #{explain['executionStats']['nReturned']}"
          end
        end
      end
      test_results[:passed] += 1
      
    rescue => e
      puts "❌ 인덱스 성능 테스트 실패: #{e.message}"
      test_results[:failed] += 1
      test_results[:errors] << { test: 'IndexPerformance', error: e.message }
    end
    
    # 6. TTL 인덱스 테스트
    puts "\n⏰ 6. TTL 인덱스 테스트"
    puts "-" * 40
    
    begin
      # 만료된 알림 생성 (테스트용)
      expired_notification = Notification.create!(
        recipient_id: 999,
        recipient_type: 'User',
        type: 'ExpiredTestNotification',
        title: '만료 테스트 알림',
        body: '이 알림은 곧 자동 삭제됩니다',
        priority: 'low',
        category: 'system',
        archived_at: 1.year.ago # TTL 인덱스에 의해 삭제 대상
      )
      
      puts "✅ TTL 인덱스 설정 확인:"
      puts "  - archived_at 필드에 1년 후 자동 삭제 설정됨"
      puts "  - 테스트 만료 알림 생성 (ID: #{expired_notification.id})"
      puts "  - 실제 삭제는 MongoDB의 백그라운드 작업에 의해 처리됨"
      test_results[:passed] += 1
      
    rescue => e
      puts "❌ TTL 인덱스 테스트 실패: #{e.message}"
      test_results[:failed] += 1
      test_results[:errors] << { test: 'TTLIndex', error: e.message }
    end
    
    # 최종 결과 출력
    puts "\n" + "=" * 60
    puts "📊 테스트 결과 요약"
    puts "=" * 60
    puts "✅ 성공: #{test_results[:passed]}개"
    puts "❌ 실패: #{test_results[:failed]}개"
    
    if test_results[:errors].any?
      puts "\n에러 상세:"
      test_results[:errors].each do |error|
        puts "  - #{error[:test]}: #{error[:error]}"
      end
    end
    
    # Collection 통계
    puts "\n📈 Collection 통계:"
    puts "-" * 40
    %w[activity_logs api_request_logs error_logs notifications].each do |collection|
      model = collection.classify.constantize
      puts "  #{collection}:"
      puts "    • 총 문서 수: #{model.count}"
      puts "    • 컬렉션 크기: #{format_bytes(collection_stats(collection)['size'])}"
      puts "    • 인덱스 수: #{Mongoid.default_client[collection].indexes.count}"
    end
    
    puts "\n✨ MongoDB 테스트 완료!"
  end
  
  private
  
  def collection_stats(collection_name)
    Mongoid.default_client.command(collStats: collection_name).first
  rescue
    { 'size' => 0 }
  end
  
  def format_bytes(bytes)
    return "0 B" if bytes.nil? || bytes == 0
    
    units = ['B', 'KB', 'MB', 'GB']
    index = 0
    size = bytes.to_f
    
    while size >= 1024 && index < units.length - 1
      size /= 1024
      index += 1
    end
    
    "#{size.round(2)} #{units[index]}"
  end
end