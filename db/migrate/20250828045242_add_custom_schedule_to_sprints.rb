class AddCustomScheduleToSprints < ActiveRecord::Migration[8.0]
  def change
    add_column :sprints, :custom_schedule, :jsonb
  end
end
