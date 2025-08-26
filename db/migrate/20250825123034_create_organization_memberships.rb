class CreateOrganizationMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :organization_memberships, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.string :role, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end
    
    add_index :organization_memberships, [:user_id, :organization_id], unique: true, name: 'index_org_memberships_on_user_and_org'
    add_index :organization_memberships, :role
    add_index :organization_memberships, :active
  end
end
