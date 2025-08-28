class AddTimeFieldsToSprints < ActiveRecord::Migration[8.0]
  def change
    add_column :sprints, :start_time, :time, default: "09:00:00"
    add_column :sprints, :end_time, :time, default: "18:00:00"
    add_column :sprints, :flexible_hours, :boolean, default: false
    add_column :sprints, :weekend_work, :boolean, default: false
    add_column :sprints, :daily_standup_time, :time
    add_column :sprints, :review_meeting_time, :datetime
    add_column :sprints, :retrospective_time, :datetime
  end
end
