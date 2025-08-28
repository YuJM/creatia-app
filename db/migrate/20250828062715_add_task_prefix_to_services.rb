class AddTaskPrefixToServices < ActiveRecord::Migration[8.0]
  def change
    add_column :services, :task_prefix, :string
  end
end
