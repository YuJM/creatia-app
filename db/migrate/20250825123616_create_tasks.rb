class CreateTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :tasks, id: :uuid do |t|
      t.string :title
      t.text :description
      t.string :status
      t.string :priority
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.references :assigned_user, polymorphic: true, null: true, type: :uuid
      t.datetime :due_date
      t.integer :position, default: 0

      t.timestamps
    end
    
    add_index :tasks, [:organization_id, :status]
    add_index :tasks, [:organization_id, :assigned_user_id, :assigned_user_type]
    add_index :tasks, [:organization_id, :priority]
    add_index :tasks, :position
  end
end
