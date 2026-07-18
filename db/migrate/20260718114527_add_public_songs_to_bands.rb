class AddPublicSongsToBands < ActiveRecord::Migration[7.0]
  def change
    add_column :bands, :public_songs_enabled, :boolean, default: false
    add_index :bands, :public_songs_enabled, name: 'index_bands_on_public_songs_enabled'
  end
end
