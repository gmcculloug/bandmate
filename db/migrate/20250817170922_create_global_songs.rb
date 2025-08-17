class CreateGlobalSongs < ActiveRecord::Migration[8.0]
  def change
    create_table :global_songs do |t|
      t.string :title, null: false
      t.string :artist, null: false
      t.string :key, null: false
      t.string :original_key
      t.integer :tempo
      t.string :genre
      t.string :url
      t.text :notes
      t.string :duration
      t.integer :year
      t.string :album
      t.timestamps
    end
    
    # Add global_song_id to songs table to reference the master version
    add_reference :songs, :global_song, foreign_key: true
    
    # Add indexes for better performance
    add_index :global_songs, :title
    add_index :global_songs, :artist
    add_index :global_songs, [:title, :artist]
  end
end
