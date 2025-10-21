class AddArchivedToSongs < ActiveRecord::Migration[8.0]
  def change
    add_column :songs, :archived, :boolean, default: false, null: false
    add_index :songs, :archived
  end
end
