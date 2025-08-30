class AddLeadIdToTeams < ActiveRecord::Migration[8.0]
  def change
    add_column :teams, :lead_id, :uuid
    add_index :teams, :lead_id
  end
end
