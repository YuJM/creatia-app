# frozen_string_literal: true

namespace :mongodb do
  namespace :benchmark do
    desc "Run MongoDB performance benchmarks"
    task run: :environment do
      puts "\n🚀 Starting MongoDB Performance Benchmarks"
      puts "=" * 60
      
      benchmark = MongodbBenchmark.new
      benchmark.run_all
      benchmark.print_results
    end

    desc "Benchmark write operations"
    task writes: :environment do
      benchmark = MongodbBenchmark.new
      benchmark.benchmark_writes
      benchmark.print_results(:writes)
    end

    desc "Benchmark read operations"
    task reads: :environment do
      benchmark = MongodbBenchmark.new
      benchmark.benchmark_reads
      benchmark.print_results(:reads)
    end

    desc "Benchmark aggregation operations"
    task aggregations: :environment do
      benchmark = MongodbBenchmark.new
      benchmark.benchmark_aggregations
      benchmark.print_results(:aggregations)
    end

    desc "Compare PostgreSQL vs MongoDB performance"
    task compare: :environment do
      puts "\n📊 PostgreSQL vs MongoDB Performance Comparison"
      puts "=" * 60
      
      comparison = DatabaseComparison.new
      comparison.run_comparison
      comparison.print_comparison
    end

    desc "Stress test MongoDB"
    task stress: :environment do
      puts "\n💪 Starting MongoDB Stress Test"
      puts "=" * 60
      
      stress_test = MongodbStressTest.new
      stress_test.run(
        duration: ENV['DURATION']&.to_i || 60,
        threads: ENV['THREADS']&.to_i || 10
      )
      stress_test.print_results
    end
  end
end

# Benchmark implementation
class MongodbBenchmark
  require 'benchmark'
  
  attr_reader :results

  def initialize
    @results = {}
    @test_size = ENV['TEST_SIZE']&.to_i || 1000
  end

  def run_all
    puts "Running all benchmarks with #{@test_size} records..."
    benchmark_writes
    benchmark_reads
    benchmark_aggregations
    benchmark_indexes
    benchmark_bulk_operations
  end

  def benchmark_writes
    puts "\n📝 Benchmarking Write Operations..."
    
    @results[:writes] = {}
    
    # Single document insert
    @results[:writes][:single_insert] = Benchmark.measure do
      @test_size.times do |i|
        Notification.create!(
          recipient_id: rand(1..100),
          type: 'BenchmarkNotification',
          title: "Benchmark #{i}",
          body: "Test notification body #{i}",
          category: %w[task comment sprint team].sample,
          priority: %w[low normal high urgent].sample
        )
      end
    end

    # Bulk insert
    notifications = @test_size.times.map do |i|
      {
        recipient_id: rand(1..100),
        type: 'BulkBenchmarkNotification',
        title: "Bulk #{i}",
        body: "Bulk test #{i}",
        category: %w[task comment sprint team].sample,
        priority: %w[low normal high urgent].sample,
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    @results[:writes][:bulk_insert] = Benchmark.measure do
      Notification.collection.insert_many(notifications)
    end

    # Update operations
    @results[:writes][:updates] = Benchmark.measure do
      Notification.where(type: 'BenchmarkNotification')
                 .limit(@test_size / 10)
                 .update_all(status: 'read', read_at: Time.current)
    end
  end

  def benchmark_reads
    puts "\n📖 Benchmarking Read Operations..."
    
    @results[:reads] = {}

    # Simple queries
    @results[:reads][:find_by_id] = Benchmark.measure do
      ids = Notification.limit(100).pluck(:id)
      ids.each { |id| Notification.find(id) }
    end

    @results[:reads][:find_by_recipient] = Benchmark.measure do
      100.times do
        Notification.for_recipient(rand(1..100)).limit(20).to_a
      end
    end

    # Complex queries
    @results[:reads][:complex_filter] = Benchmark.measure do
      100.times do
        Notification.for_recipient(rand(1..100))
                   .unread
                   .high_priority
                   .by_category('task')
                   .recent
                   .limit(20)
                   .to_a
      end
    end

    # Count operations
    @results[:reads][:count_operations] = Benchmark.measure do
      100.times do
        Notification.for_recipient(rand(1..100)).unread.count
      end
    end
  end

  def benchmark_aggregations
    puts "\n📊 Benchmarking Aggregation Operations..."
    
    @results[:aggregations] = {}

    # Group by category
    @results[:aggregations][:group_by_category] = Benchmark.measure do
      10.times do
        Notification.collection.aggregate([
          { '$match' => { recipient_id: rand(1..100) } },
          { '$group' => {
            '_id' => '$category',
            'count' => { '$sum' => 1 },
            'unread' => { '$sum' => { '$cond' => [{ '$eq' => ['$read_at', nil] }, 1, 0] } }
          }}
        ]).to_a
      end
    end

    # Daily statistics
    @results[:aggregations][:daily_stats] = Benchmark.measure do
      10.times do
        Notification.collection.aggregate([
          { '$match' => {
            'created_at' => { '$gte' => 7.days.ago }
          }},
          { '$group' => {
            '_id' => {
              'date' => { '$dateToString' => { 'format' => '%Y-%m-%d', 'date' => '$created_at' } },
              'category' => '$category'
            },
            'count' => { '$sum' => 1 }
          }},
          { '$sort' => { '_id.date' => -1 } }
        ]).to_a
      end
    end

    # User activity metrics
    @results[:aggregations][:user_metrics] = Benchmark.measure do
      10.times do
        UserActionLog.collection.aggregate([
          { '$match' => {
            'created_at' => { '$gte' => 24.hours.ago }
          }},
          { '$group' => {
            '_id' => '$user_id',
            'actions' => { '$sum' => 1 },
            'action_types' => { '$addToSet' => '$action_type' }
          }},
          { '$sort' => { 'actions' => -1 } },
          { '$limit' => 10 }
        ]).to_a
      end
    end
  end

  def benchmark_indexes
    puts "\n🔍 Benchmarking Index Performance..."
    
    @results[:indexes] = {}

    # Query with index
    @results[:indexes][:with_index] = Benchmark.measure do
      1000.times do
        Notification.where(
          recipient_id: rand(1..100),
          created_at: { '$gte' => 7.days.ago }
        ).limit(10).to_a
      end
    end

    # Query without index (using non-indexed field)
    @results[:indexes][:without_index] = Benchmark.measure do
      100.times do
        Notification.where(
          body: /test/i
        ).limit(10).to_a
      end
    end
  end

  def benchmark_bulk_operations
    puts "\n📦 Benchmarking Bulk Operations..."
    
    @results[:bulk] = {}

    # Bulk updates
    @results[:bulk][:bulk_update] = Benchmark.measure do
      bulk = Notification.collection.bulk_write([
        {
          update_many: {
            filter: { status: 'pending' },
            update: { '$set' => { status: 'sent', sent_at: Time.current } }
          }
        },
        {
          update_many: {
            filter: { priority: 'low', created_at: { '$lt' => 30.days.ago } },
            update: { '$set' => { archived_at: Time.current } }
          }
        }
      ])
    end

    # Bulk delete
    @results[:bulk][:bulk_delete] = Benchmark.measure do
      Notification.where(
        type: 'BenchmarkNotification',
        created_at: { '$lt' => 1.hour.ago }
      ).destroy_all
    end
  end

  def print_results(category = nil)
    puts "\n📈 Benchmark Results"
    puts "=" * 60

    categories = category ? [category] : @results.keys

    categories.each do |cat|
      next unless @results[cat]
      
      puts "\n#{cat.to_s.upcase}:"
      puts "-" * 40
      
      @results[cat].each do |operation, timing|
        puts sprintf("%-30s: %10.4f seconds", operation, timing.real)
      end
    end

    print_summary if category.nil?
  end

  private

  def print_summary
    puts "\n📊 Summary"
    puts "=" * 60
    
    total_time = @results.values.flat_map(&:values).sum(&:real)
    puts "Total benchmark time: #{total_time.round(2)} seconds"
    
    # Find slowest operations
    all_operations = @results.flat_map do |category, operations|
      operations.map { |op, timing| ["#{category}:#{op}", timing.real] }
    end
    
    slowest = all_operations.sort_by(&:last).last(3)
    
    puts "\n⚠️  Slowest Operations:"
    slowest.reverse.each_with_index do |(op, time), i|
      puts "  #{i + 1}. #{op}: #{time.round(4)}s"
    end

    # Calculate throughput
    total_operations = @test_size * 5 # Approximate
    throughput = total_operations / total_time
    puts "\n⚡ Throughput: ~#{throughput.round(0)} ops/second"
  end
end

# Database comparison
class DatabaseComparison
  def initialize
    @results = { postgresql: {}, mongodb: {} }
    @test_size = 1000
  end

  def run_comparison
    puts "Comparing databases with #{@test_size} records..."
    
    # Only run if PostgreSQL models exist
    if defined?(Task)
      benchmark_postgresql
    end
    
    benchmark_mongodb
  end

  def benchmark_postgresql
    puts "\n🐘 Benchmarking PostgreSQL..."
    
    # Write performance
    @results[:postgresql][:write] = Benchmark.measure do
      @test_size.times do |i|
        Task.create!(
          title: "PG Task #{i}",
          description: "PostgreSQL benchmark task",
          status: 'pending',
          priority: rand(1..5)
        )
      end
    end

    # Read performance
    @results[:postgresql][:read] = Benchmark.measure do
      100.times do
        Task.where(status: 'pending')
            .order(created_at: :desc)
            .limit(20)
            .to_a
      end
    end

    # Aggregation
    @results[:postgresql][:aggregation] = Benchmark.measure do
      10.times do
        Task.group(:status).count
        Task.group(:priority).average(:id)
      end
    end
  rescue => e
    puts "PostgreSQL benchmark skipped: #{e.message}"
  end

  def benchmark_mongodb
    puts "\n🍃 Benchmarking MongoDB..."
    
    # Write performance
    @results[:mongodb][:write] = Benchmark.measure do
      @test_size.times do |i|
        TaskHistory.create!(
          task_id: i,
          action: 'created',
          field_changes: { title: "Mongo Task #{i}" },
          user_id: rand(1..10)
        )
      end
    end

    # Read performance
    @results[:mongodb][:read] = Benchmark.measure do
      100.times do
        TaskHistory.where(action: 'created')
                  .order_by(created_at: -1)
                  .limit(20)
                  .to_a
      end
    end

    # Aggregation
    @results[:mongodb][:aggregation] = Benchmark.measure do
      10.times do
        TaskHistory.collection.aggregate([
          { '$group' => {
            '_id' => '$action',
            'count' => { '$sum' => 1 }
          }}
        ]).to_a
      end
    end
  end

  def print_comparison
    puts "\n📊 Performance Comparison Results"
    puts "=" * 60

    operations = [:write, :read, :aggregation]
    
    operations.each do |op|
      pg_time = @results[:postgresql][op]&.real || 0
      mongo_time = @results[:mongodb][op]&.real || 0
      
      next if pg_time == 0 && mongo_time == 0
      
      puts "\n#{op.to_s.upcase}:"
      puts sprintf("  PostgreSQL : %10.4f seconds", pg_time) if pg_time > 0
      puts sprintf("  MongoDB    : %10.4f seconds", mongo_time)
      
      if pg_time > 0
        improvement = ((pg_time - mongo_time) / pg_time * 100).round(1)
        if improvement > 0
          puts "  ✅ MongoDB is #{improvement}% faster"
        else
          puts "  ⚠️  PostgreSQL is #{improvement.abs}% faster"
        end
      end
    end
  end
end

# Stress test
class MongodbStressTest
  def initialize
    @results = {
      operations: 0,
      errors: 0,
      response_times: [],
      start_time: nil,
      end_time: nil
    }
  end

  def run(duration:, threads:)
    puts "Running stress test for #{duration} seconds with #{threads} threads..."
    
    @results[:start_time] = Time.current
    end_time = @results[:start_time] + duration.seconds
    
    thread_pool = []
    
    threads.times do |i|
      thread_pool << Thread.new do
        while Time.current < end_time
          perform_random_operation
        end
      end
    end
    
    # Progress indicator
    while Time.current < end_time
      progress = ((Time.current - @results[:start_time]) / duration * 100).round
      print "\rProgress: [#{'=' * (progress / 2)}#{' ' * (50 - progress / 2)}] #{progress}%"
      sleep 1
    end
    
    thread_pool.each(&:join)
    @results[:end_time] = Time.current
    
    puts "\n✅ Stress test completed!"
  end

  def perform_random_operation
    operation_start = Time.current
    
    begin
      case rand(10)
      when 0..3 # 40% reads
        Notification.for_recipient(rand(1..100)).limit(10).to_a
      when 4..6 # 30% writes
        Notification.create!(
          recipient_id: rand(1..100),
          type: 'StressTestNotification',
          title: "Stress #{SecureRandom.hex(4)}",
          body: "Stress test notification",
          category: %w[task comment].sample,
          priority: %w[low normal high].sample
        )
      when 7..8 # 20% updates
        Notification.where(type: 'StressTestNotification')
                   .limit(5)
                   .update_all(status: 'read')
      when 9 # 10% aggregations
        Notification.collection.aggregate([
          { '$match' => { recipient_id: rand(1..100) } },
          { '$group' => { '_id' => '$category', 'count' => { '$sum' => 1 } } }
        ]).to_a
      end
      
      @results[:operations] += 1
      @results[:response_times] << (Time.current - operation_start).to_f
    rescue => e
      @results[:errors] += 1
    end
  end

  def print_results
    puts "\n💪 Stress Test Results"
    puts "=" * 60
    
    duration = (@results[:end_time] - @results[:start_time]).to_f
    ops_per_second = @results[:operations] / duration
    
    puts "Duration: #{duration.round(2)} seconds"
    puts "Total operations: #{@results[:operations]}"
    puts "Errors: #{@results[:errors]}"
    puts "Success rate: #{(100 - (@results[:errors].to_f / @results[:operations] * 100)).round(2)}%"
    puts "Operations/second: #{ops_per_second.round(0)}"
    
    if @results[:response_times].any?
      avg_response = @results[:response_times].sum / @results[:response_times].size * 1000
      p95_response = @results[:response_times].sort[(0.95 * @results[:response_times].size).to_i] * 1000
      p99_response = @results[:response_times].sort[(0.99 * @results[:response_times].size).to_i] * 1000
      
      puts "\n📊 Response Times:"
      puts "  Average: #{avg_response.round(2)}ms"
      puts "  P95: #{p95_response.round(2)}ms"
      puts "  P99: #{p99_response.round(2)}ms"
    end
    
    # Cleanup stress test data
    cleanup_count = Notification.where(type: 'StressTestNotification').delete_all
    puts "\n🧹 Cleaned up #{cleanup_count} test records"
  end
end