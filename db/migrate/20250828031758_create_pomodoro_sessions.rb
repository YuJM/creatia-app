class CreatePomodoroSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :pomodoro_sessions, id: :uuid do |t|
      t.references :task, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.datetime :started_at
      t.datetime :completed_at
      t.string :status
      t.integer :session_count
      t.integer :duration

      t.timestamps
    end
  end
end
