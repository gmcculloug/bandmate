class RenameGlobalSongsToSongCatalogs < ActiveRecord::Migration[8.0]
  def change
    rename_table :global_songs, :song_catalogs
    rename_column :songs, :global_song_id, :song_catalog_id
  end
end
