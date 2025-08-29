# frozen_string_literal: true

class DropNoticedTables < ActiveRecord::Migration[8.0]
  def up
    # Drop Noticed gem tables
    drop_table :noticed_notifications if table_exists?(:noticed_notifications)
    drop_table :noticed_events if table_exists?(:noticed_events)
    
    puts "✅ Dropped Noticed gem tables"
  end

  def down
    # Recreate tables if needed (rollback)
    # Note: This is a simplified version, actual schema might differ
    
    create_table :noticed_events do |t|
      t.string :type
      t.belongs_to :record, polymorphic: true
      t.jsonb :params
      t.integer :notifications_count
      t.timestamps
    end if !table_exists?(:noticed_events)

    create_table :noticed_notifications do |t|
      t.string :type
      t.belongs_to :event, null: false
      t.belongs_to :recipient, polymorphic: true, null: false
      t.datetime :read_at
      t.datetime :seen_at
      t.timestamps
    end if !table_exists?(:noticed_notifications)
    
    puts "⚠️  Recreated Noticed gem tables (rollback)"
  end
end
