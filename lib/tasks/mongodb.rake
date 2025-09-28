# lib/tasks/mongodb.rake
namespace :mongodb do
  desc "Create MongoDB indexes for all models"
  task create_indexes: :environment do
    puts "Creating MongoDB indexes..."
    
    # Milestone indexes
    Milestone.create_indexes
    puts "✓ Milestone indexes created"
    
    # Sprint indexes
    Mongodb::MongoSprint.create_indexes
    puts "✓ Sprint indexes created"
    
    # Task indexes
    Mongodb::MongoTask.create_indexes
    puts "✓ Task indexes created"
    
    # Comment indexes
    Mongodb::MongoComment.create_indexes
    puts "✓ Comment indexes created"
    
    # Activity indexes
    Mongodb::MongoActivity.create_indexes
    puts "✓ Activity indexes created"
    
    puts "\nAll MongoDB indexes created successfully!"
  end
  
  desc "Remove all MongoDB indexes"
  task remove_indexes: :environment do
    puts "Removing MongoDB indexes..."
    
    Milestone.remove_indexes
    Mongodb::MongoSprint.remove_indexes
    Mongodb::MongoTask.remove_indexes
    Mongodb::MongoComment.remove_indexes
    Mongodb::MongoActivity.remove_indexes
    
    puts "All MongoDB indexes removed successfully!"
  end
  
  desc "Show MongoDB collection statistics"
  task stats: :environment do
    puts "\n=== MongoDB Collection Statistics ==="
    puts "Database: #{Mongoid.default_client.database.name}"
    puts "-" * 50
    
    collections = %w[milestones sprints tasks comments activities]
    
    collections.each do |collection_name|
      begin
        stats = Mongoid.default_client[collection_name].aggregate([
          { '$collStats': { storageStats: {} } }
        ]).first
        
        if stats
          puts "\n#{collection_name.capitalize}:"
          puts "  Document count: #{stats['storageStats']['count']}"
          puts "  Storage size: #{(stats['storageStats']['storageSize'] / 1024.0 / 1024.0).round(2)} MB"
          puts "  Index count: #{stats['storageStats']['nindexes']}"
        end
      rescue => e
        puts "\n#{collection_name.capitalize}: No data or collection doesn't exist"
      end
    end
    
    puts "\n" + "=" * 50
  end
  
  desc "Seed sample MongoDB data for testing"
  task seed: :environment do
    puts "Seeding MongoDB with sample data..."
    
    # Sample organization from PostgreSQL
    org = Organization.first
    service = Service.first
    users = User.limit(5).to_a
    
    unless org && service
      puts "Please ensure you have at least one Organization and Service in PostgreSQL"
      exit
    end
    
    # Create sample Milestone
    milestone = Milestone.create!(
      organization_id: org.id,
      service_id: service.id,
      created_by_id: users.first&.id,
      title: "Q1 2025 Release",
      description: "Major feature release for Q1",
      status: "active",
      milestone_type: "release",
      planned_start: Date.current,
      planned_end: 3.months.from_now,
      objectives: [
        {
          id: 'obj-1',
          title: 'Improve user engagement',
          key_results: [
            { id: 'kr-1', description: 'DAU 50% increase', target: 50000, current: 35000, unit: 'users' },
            { id: 'kr-2', description: 'Retention 30% improvement', target: 30, current: 22, unit: 'percent' }
          ]
        }
      ]
    )
    puts "✓ Created Milestone: #{milestone.title}"
    
    # Create sample Sprint
    sprint = Mongodb::MongoSprint.create!(
      organization_id: org.id,
      service_id: service.id,
      milestone_id: milestone.id.to_s,
      name: "Sprint 1 - Foundation",
      goal: "Set up basic infrastructure and core features",
      sprint_number: 1,
      status: "active",
      start_date: Date.current,
      end_date: 2.weeks.from_now,
      working_days: 10,
      team_capacity: 160.0,
      planned_velocity: 40.0
    )
    puts "✓ Created Sprint: #{sprint.name}"
    
    # Create sample Tasks
    5.times do |i|
      task = Mongodb::MongoTask.create!(
        organization_id: org.id,
        service_id: service.id,
        sprint_id: sprint.id.to_s,
        milestone_id: milestone.id.to_s,
        task_id: "TASK-#{i + 1}",
        title: "Sample Task #{i + 1}",
        description: "Description for task #{i + 1}",
        task_type: ['feature', 'bug', 'chore'].sample,
        assignee_id: users.sample&.id,
        assignee_name: users.sample&.name,
        status: ['backlog', 'todo', 'in_progress', 'review', 'done'].sample,
        priority: ['low', 'medium', 'high', 'urgent'].sample,
        story_points: [1, 2, 3, 5, 8].sample,
        original_estimate_hours: [2, 4, 8, 16].sample,
        labels: ['frontend', 'backend', 'api', 'ui/ux'].sample(2)
      )
      puts "  ✓ Created Task: #{task.task_id} - #{task.title}"
      
      # Add sample comment
      Mongodb::MongoComment.create!(
        commentable_type: 'MongoTask',
        commentable_id: task.id.to_s,
        organization_id: org.id,
        author_id: users.sample&.id,
        author_name: users.sample&.name,
        content: "Sample comment on #{task.title}",
        comment_type: 'general'
      )
      
      # Log activity
      Mongodb::MongoActivity.log_activity(
        organization_id: org.id,
        actor_id: users.sample&.id,
        actor_name: users.sample&.name,
        action: 'created',
        target_type: 'MongoTask',
        target_id: task.id.to_s,
        target_title: task.title
      )
    end
    
    puts "\n✓ Sample data seeded successfully!"
  end
  
  desc "Clean up old MongoDB data based on TTL settings"
  task cleanup: :environment do
    puts "Cleaning up old MongoDB data..."
    
    # This is handled automatically by MongoDB TTL indexes
    # But we can manually trigger cleanup for specific conditions
    
    # Archive old completed tasks
    old_tasks = Mongodb::MongoTask.where(
      status: 'done',
      :completed_at.lt => 6.months.ago
    )
    archived_count = old_tasks.update_all(status: 'archived', archived_at: Time.current)
    puts "✓ Archived #{archived_count} old completed tasks"
    
    # Remove very old activities (older than TTL)
    old_activities = Mongodb::MongoActivity.where(:created_at.lt => 6.months.ago)
    deleted_count = old_activities.delete_all
    puts "✓ Deleted #{deleted_count} old activities"
    
    puts "\nCleanup completed!"
  end
end