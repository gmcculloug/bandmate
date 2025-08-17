class PopulateGlobalSongsFromExisting < ActiveRecord::Migration[8.0]
  def up
    # Create global songs from existing unique song combinations
    # Group existing songs by title and artist to avoid duplicates
    song_groups = execute("
      SELECT title, artist, key, original_key, tempo, genre, url, notes, duration, year, album, 
             MIN(created_at) as created_at, MIN(updated_at) as updated_at
      FROM songs 
      GROUP BY LOWER(title), LOWER(artist)
    ")
    
    song_groups.each do |song_data|
      # Create global song
      global_song_id = execute("
        INSERT INTO global_songs (title, artist, key, original_key, tempo, genre, url, notes, duration, year, album, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ", [song_data['title'], song_data['artist'], song_data['key'], song_data['original_key'], 
          song_data['tempo'], song_data['genre'], song_data['url'], song_data['notes'], 
          song_data['duration'], song_data['year'], song_data['album'], 
          song_data['created_at'], song_data['updated_at']])
      
      # Update all existing songs with matching title/artist to reference this global song
      execute("
        UPDATE songs 
        SET global_song_id = (
          SELECT id FROM global_songs 
          WHERE LOWER(global_songs.title) = LOWER(songs.title) 
          AND LOWER(global_songs.artist) = LOWER(songs.artist)
          LIMIT 1
        )
        WHERE LOWER(title) = LOWER(?) AND LOWER(artist) = LOWER(?)
      ", [song_data['title'], song_data['artist']])
    end
  end
  
  def down
    # Remove global_song_id references and delete global songs
    execute("UPDATE songs SET global_song_id = NULL")
    execute("DELETE FROM global_songs")
  end
end
