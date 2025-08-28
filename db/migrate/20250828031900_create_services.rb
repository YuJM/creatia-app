class CreateServices < ActiveRecord::Migration[8.0]
  def change
    create_table :services, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.string :name
      t.string :key
      t.text :description

      t.timestamps
    end
  end
end
