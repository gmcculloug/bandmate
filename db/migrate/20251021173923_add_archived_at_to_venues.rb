class AddArchivedAtToVenues < ActiveRecord::Migration[8.0]
  def change
    add_column :venues, :archived_at, :timestamp
    add_index :venues, :archived_at
  end
end
