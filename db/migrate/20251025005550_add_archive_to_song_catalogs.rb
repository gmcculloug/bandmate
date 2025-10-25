class AddArchiveToSongCatalogs < ActiveRecord::Migration[8.0]
  def change
    add_column :song_catalogs, :archived, :boolean, default: false, null: false
    add_column :song_catalogs, :archived_at, :datetime

    add_index :song_catalogs, :archived
    add_index :song_catalogs, :archived_at
  end
end
