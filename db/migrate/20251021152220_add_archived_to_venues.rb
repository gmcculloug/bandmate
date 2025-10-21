class AddArchivedToVenues < ActiveRecord::Migration[8.0]
  def change
    add_column :venues, :archived, :boolean, default: false, null: false
    add_index :venues, :archived
  end
end
