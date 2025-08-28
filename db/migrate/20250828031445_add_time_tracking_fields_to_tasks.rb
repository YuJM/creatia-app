class AddTimeTrackingFieldsToTasks < ActiveRecord::Migration[8.0]
  def change
    # Time tracking fields
    add_column :tasks, :started_at, :datetime
    add_column :tasks, :completed_at, :datetime
    add_column :tasks, :estimated_hours, :decimal, precision: 10, scale: 2
    add_column :tasks, :actual_hours, :decimal, precision: 10, scale: 2
    add_column :tasks, :deadline, :datetime
    add_column :tasks, :story_points, :integer
    
    # Add indexes for performance
    add_index :tasks, :started_at
    add_index :tasks, :completed_at
    add_index :tasks, :deadline
    add_index :tasks, [:deadline, :completed_at], name: 'index_tasks_on_deadline_and_completed'
    add_index :tasks, [:organization_id, :deadline], name: 'index_tasks_on_org_and_deadline'
  end
end
