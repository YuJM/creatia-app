class AddFieldsToPomodoroSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :pomodoro_sessions, :ended_at, :datetime
    add_column :pomodoro_sessions, :actual_duration, :integer
    add_column :pomodoro_sessions, :paused_at, :datetime
    add_column :pomodoro_sessions, :paused_duration, :integer, default: 0
  end
end
