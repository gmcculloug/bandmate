class AddLyricsToSongs < ActiveRecord::Migration[8.0]
  def change
    add_column :songs, :lyrics, :text
    add_column :global_songs, :lyrics, :text
  end
end
