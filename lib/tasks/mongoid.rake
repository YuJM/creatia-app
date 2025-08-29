namespace :mongoid do
  desc "Test MongoDB connection"
  task test_connection: :environment do
    puts "Testing MongoDB connection..."
    
    begin
      # MongoDB 연결 테스트
      client = Mongoid::Clients.default
      server_info = client.database.command(ping: 1).first
      
      if server_info["ok"] == 1
        puts "✅ Successfully connected to MongoDB!"
        puts "Database: #{client.database.name}"
        puts "Host: #{client.cluster.addresses.map(&:to_s).join(', ')}"
        
        # 컬렉션 목록
        collections = client.database.collection_names
        puts "\nCollections:"
        collections.each do |collection|
          count = client.database[collection].count_documents
          puts "  - #{collection}: #{count} documents"
        end
      else
        puts "❌ Failed to connect to MongoDB"
      end
    rescue => e
      puts "❌ Error connecting to MongoDB: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end
  
  desc "Create sample logs"
  task create_sample_logs: :environment do
    puts "Creating sample logs..."
    
    # Sample ActivityLog
    activity = ActivityLog.create!(
      action: "test#create",
      controller: "test",
      method: "POST",
      path: "/test",
      ip_address: "127.0.0.1",
      user_agent: "Mozilla/5.0",
      status: 200,
      duration: 125.5,
      user_id: 1,
      user_email: "test@example.com",
      organization_id: 1,
      organization_subdomain: "test",
      metadata: { test: true }
    )
    puts "✅ Created ActivityLog: #{activity.id}"
    
    # Sample ErrorLog
    begin
      raise StandardError, "Test error for logging"
    rescue => e
      error = ErrorLog.log_error(e, {
        controller: "test",
        action: "error",
        path: "/test/error",
        method: "GET",
        ip_address: "127.0.0.1",
        user_agent: "Mozilla/5.0",
        user_id: 1,
        user_email: "test@example.com",
        organization_id: 1,
        organization_subdomain: "test"
      })
      puts "✅ Created ErrorLog: #{error.id}" if error
    end
    
    # Sample ApiRequestLog
    api_log = ApiRequestLog.create!(
      endpoint: "/api/v1/test",
      method: "GET",
      path: "/api/v1/test?param=value",
      query_params: { param: "value" },
      request_headers: { "Content-Type" => "application/json" },
      status_code: 200,
      response_time: 45.2,
      ip_address: "127.0.0.1",
      user_agent: "Mozilla/5.0",
      api_version: "v1",
      user_id: 1,
      organization_id: 1,
      auth_method: "jwt"
    )
    puts "✅ Created ApiRequestLog: #{api_log.id}"
    
    puts "\n📊 Log Statistics:"
    puts "  ActivityLogs: #{ActivityLog.count}"
    puts "  ErrorLogs: #{ErrorLog.count}"
    puts "  ApiRequestLogs: #{ApiRequestLog.count}"
  end
  
  desc "Clear all logs"
  task clear_logs: :environment do
    puts "Clearing all logs..."
    
    ActivityLog.delete_all
    puts "✅ Deleted all ActivityLogs"
    
    ErrorLog.delete_all
    puts "✅ Deleted all ErrorLogs"
    
    ApiRequestLog.delete_all
    puts "✅ Deleted all ApiRequestLogs"
  end
  
  desc "Show log statistics"
  task stats: :environment do
    puts "📊 MongoDB Log Statistics"
    puts "=" * 50
    
    puts "\nActivityLogs:"
    puts "  Total: #{ActivityLog.count}"
    puts "  Today: #{ActivityLog.today.count}"
    puts "  This Week: #{ActivityLog.this_week.count}"
    puts "  This Month: #{ActivityLog.this_month.count}"
    
    puts "\nErrorLogs:"
    puts "  Total: #{ErrorLog.count}"
    puts "  Unresolved: #{ErrorLog.unresolved.count}"
    puts "  Critical: #{ErrorLog.critical.count}"
    puts "  Errors: #{ErrorLog.errors.count}"
    puts "  Warnings: #{ErrorLog.warnings.count}"
    
    puts "\nApiRequestLogs:"
    puts "  Total: #{ApiRequestLog.count}"
    puts "  Today: #{ApiRequestLog.today.count}"
    puts "  Successful: #{ApiRequestLog.successful.count}"
    puts "  Client Errors: #{ApiRequestLog.client_errors.count}"
    puts "  Server Errors: #{ApiRequestLog.server_errors.count}"
    puts "  Slow Requests (>1s): #{ApiRequestLog.slow_requests.count}"
    
    # Top actions
    puts "\n🔥 Top Activities (Last 7 days):"
    ActivityLog.popular_actions(nil, 5).each do |action|
      puts "  #{action['_id']}: #{action['count']} times"
    end
    
    # Top errors
    puts "\n⚠️ Top Errors (Unresolved):"
    ErrorLog.top_errors(nil, 5).each do |error|
      puts "  #{error['_id']['error_class']}: #{error['count']} occurrences"
      puts "    Last: #{error['last_occurred']}"
    end
  end
end