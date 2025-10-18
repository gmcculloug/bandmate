require_relative 'song_data'

puts "Seeding song catalog with sample data..."

song_catalogs = []
SongData::GLOBAL_SONGS.each do |song_data|
  song_catalog = SongCatalog.find_or_create_by(
    title: song_data[:title],
    artist: song_data[:artist]
  ) do |gs|
    gs.key = song_data[:key]
    gs.original_key = song_data[:original_key]
    gs.tempo = song_data[:tempo]
    gs.genre = song_data[:genre]
    gs.year = song_data[:year]
    gs.album = song_data[:album]
    gs.duration = song_data[:duration]
  end
  song_catalogs << song_catalog
  puts "Created/found song catalog entry: #{song_catalog.title} by #{song_catalog.artist}"
end

puts "Song catalog seeded with #{song_catalogs.count} songs!"