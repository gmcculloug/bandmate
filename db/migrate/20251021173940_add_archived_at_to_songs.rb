class AddArchivedAtToSongs < ActiveRecord::Migration[8.0]
  def change
    add_column :songs, :archived_at, :timestamp
    add_index :songs, :archived_at
  end
end
