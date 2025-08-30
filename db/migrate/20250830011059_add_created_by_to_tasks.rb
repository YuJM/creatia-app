class AddCreatedByToTasks < ActiveRecord::Migration[8.0]
  def change
    add_reference :tasks, :created_by, null: true, foreign_key: { to_table: :users }, type: :uuid
  end
end
