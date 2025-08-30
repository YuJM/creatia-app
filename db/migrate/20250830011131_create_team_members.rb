class CreateTeamMembers < ActiveRecord::Migration[8.0]
  def change
    create_table :team_members, id: :uuid do |t|
      t.references :team, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :role, null: false, default: 'member'

      t.timestamps
    end
    
    add_index :team_members, [:team_id, :user_id], unique: true
  end
end
