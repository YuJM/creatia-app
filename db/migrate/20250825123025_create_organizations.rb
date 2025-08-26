class CreateOrganizations < ActiveRecord::Migration[8.0]
  def change
    create_table :organizations, id: :uuid do |t|
      t.string :name
      t.string :subdomain
      t.text :description
      t.string :plan
      t.boolean :active, default: true, null: false

      t.timestamps
    end
    add_index :organizations, :subdomain, unique: true
  end
end
