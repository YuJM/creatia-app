class AddReferencesToTasks < ActiveRecord::Migration[8.0]
  def change
    add_reference :tasks, :sprint, null: true, foreign_key: true, type: :uuid
    add_reference :tasks, :team, null: true, foreign_key: true, type: :uuid
    add_reference :tasks, :service, null: true, foreign_key: true, type: :uuid
    add_reference :tasks, :assignee, null: true, foreign_key: { to_table: :users }, type: :uuid
  end
end
