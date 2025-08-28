class ChangePomodoroSessionStatusToInteger < ActiveRecord::Migration[8.0]
  def change
    # Remove the old string column
    remove_column :pomodoro_sessions, :status, :string
    
    # Add the new integer column with default value
    add_column :pomodoro_sessions, :status, :integer, default: 0, null: false
    
    # Add index for performance
    add_index :pomodoro_sessions, :status
  end
end
