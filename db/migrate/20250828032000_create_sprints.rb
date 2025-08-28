class CreateSprints < ActiveRecord::Migration[8.0]
  def change
    create_table :sprints, id: :uuid do |t|
      t.references :service, null: false, foreign_key: true, type: :uuid
      t.string :name
      t.date :start_date
      t.date :end_date
      t.text :goal
      t.string :status
      t.text :schedule # For IceCube schedule serialization

      t.timestamps
    end
  end
end
