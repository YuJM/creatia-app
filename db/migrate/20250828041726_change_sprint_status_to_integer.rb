class ChangeSprintStatusToInteger < ActiveRecord::Migration[8.0]
  def change
    # Remove the old string column
    remove_column :sprints, :status, :string
    
    # Add the new integer column with default value
    add_column :sprints, :status, :integer, default: 0, null: false
    
    # Add index for performance
    add_index :sprints, :status
  end
end
