puts "Seeding database with sample data..."

# Create users with password "test123"
users_data = [
  { username: "alice", email: "alice@bandmate.com" },
  { username: "bob", email: "bob@bandmate.com" },
  { username: "charlie", email: "charlie@bandmate.com" },
  { username: "diana", email: "diana@bandmate.com" },
  { username: "eve", email: "eve@bandmate.com" }
]

users = []
users_data.each do |user_data|
  user = User.find_or_create_by(username: user_data[:username]) do |u|
    u.email = user_data[:email]
    u.password = "test123"
    u.password_confirmation = "test123"
  end
  users << user
  puts "Created/found user: #{user.username}"
end

# Create bands for each user
band_names = [
  "The Midnight Rockers", "Electric Dreams", "Sunset Boulevard",
  "Vinyl Revival", "Neon Nights", "The Sound Factory",
  "Vintage Vibes", "Urban Legends", "The Groove Machine"
]

bands = []
users.each_with_index do |user, index|
  band_name = band_names[index] || "#{user.username.capitalize}'s Band"
  band = Band.find_or_create_by(name: band_name) do |b|
    b.owner = user
    b.notes = "Band owned by #{user.username}"
  end
  
  # Add user to their own band
  unless band.users.include?(user)
    band.users << user
  end
  
  # Set as user's last selected band
  user.update(last_selected_band: band)
  
  bands << band
  puts "Created/found band: #{band.name} (owner: #{user.username})"
end

# Add bob to alice's band (The Midnight Rockers)
alice = users.find { |u| u.username == "alice" }
bob = users.find { |u| u.username == "bob" }
alice_band = bands.find { |b| b.owner == alice }

if alice_band && bob && !alice_band.users.include?(bob)
  alice_band.users << bob
  puts "Added #{bob.username} to band #{alice_band.name}"
end

# Create 10 global songs
global_songs_data = [
  { title: "Sweet Home Alabama", artist: "Lynyrd Skynyrd", key: "G", original_key: "G", tempo: 100, genre: "Rock", year: 1974, album: "Second Helping", duration: "4:43" },
  { title: "Hotel California", artist: "Eagles", key: "Bm", original_key: "Bm", tempo: 75, genre: "Rock", year: 1976, album: "Hotel California", duration: "6:30" },
  { title: "Wonderwall", artist: "Oasis", key: "Em", original_key: "Em", tempo: 87, genre: "Alternative Rock", year: 1995, album: "What's the Story Morning Glory?", duration: "4:18" },
  { title: "Don't Stop Believin'", artist: "Journey", key: "E", original_key: "E", tempo: 119, genre: "Rock", year: 1981, album: "Escape", duration: "4:09" },
  { title: "Bohemian Rhapsody", artist: "Queen", key: "Bb", original_key: "Bb", tempo: 72, genre: "Progressive Rock", year: 1975, album: "A Night at the Opera", duration: "5:55" },
  { title: "Stairway to Heaven", artist: "Led Zeppelin", key: "Am", original_key: "Am", tempo: 82, genre: "Rock", year: 1971, album: "Led Zeppelin IV", duration: "8:02" },
  { title: "Free Bird", artist: "Lynyrd Skynyrd", key: "G", original_key: "G", tempo: 65, genre: "Southern Rock", year: 1973, album: "Pronounced Leh-nerd Skin-nerd", duration: "9:07" },
  { title: "Brown Eyed Girl", artist: "Van Morrison", key: "G", original_key: "G", tempo: 150, genre: "Folk Rock", year: 1967, album: "Blowin' Your Mind!", duration: "3:05" },
  { title: "Sweet Caroline", artist: "Neil Diamond", key: "C", original_key: "C", tempo: 125, genre: "Pop", year: 1969, album: "Brother Love's Travelling Salvation Show", duration: "3:21" },
  { title: "Livin' on a Prayer", artist: "Bon Jovi", key: "Em", original_key: "Em", tempo: 123, genre: "Rock", year: 1986, album: "Slippery When Wet", duration: "4:09" }
]

global_songs = []
global_songs_data.each do |song_data|
  global_song = GlobalSong.find_or_create_by(
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
  global_songs << global_song
  puts "Created/found global song: #{global_song.title} by #{global_song.artist}"
end

# Create venues for each band
venue_types = [
  { name: "The Blue Note", location: "123 Main St, Downtown", contact_name: "Mike Johnson", phone_number: "(555) 123-4567", website: "http://bluenote.com" },
  { name: "Riverside Amphitheater", location: "456 River Rd, Westside", contact_name: "Sarah Williams", phone_number: "(555) 234-5678", website: "http://riverside-amp.com" },
  { name: "The Underground", location: "789 Basement Ave, Arts District", contact_name: "Tony Martinez", phone_number: "(555) 345-6789", website: "http://underground-venue.com" },
  { name: "Sunset Rooftop", location: "321 High St, Uptown", contact_name: "Lisa Chen", phone_number: "(555) 456-7890", website: "http://sunset-rooftop.com" },
  { name: "The Garden Stage", location: "654 Park Blvd, Midtown", contact_name: "David Brown", phone_number: "(555) 567-8901", website: "http://garden-stage.com" },
  { name: "Electric Lounge", location: "987 Neon Ave, Entertainment District", contact_name: "Jennifer Davis", phone_number: "(555) 678-9012", website: "http://electric-lounge.com" }
]

venues = []
bands.each_with_index do |band, index|
  venue_data = venue_types[index % venue_types.length]
  venue = Venue.find_or_create_by(
    name: venue_data[:name],
    band: band
  ) do |v|
    v.location = venue_data[:location]
    v.contact_name = venue_data[:contact_name]
    v.phone_number = venue_data[:phone_number]
    v.website = venue_data[:website]
    v.notes = "Venue for #{band.name}"
  end
  venues << venue
  puts "Created/found venue: #{venue.name} for band #{band.name}"
end

# Create songs for bands from global songs
bands.each do |band|
  # Each band gets 4-7 random global songs
  selected_global_songs = global_songs.sample(rand(4..7))
  
  selected_global_songs.each do |global_song|
    song = Song.find_or_create_by(
      title: global_song.title,
      artist: global_song.artist,
      global_song: global_song
    ) do |s|
      s.key = global_song.key
      s.original_key = global_song.original_key
      s.tempo = global_song.tempo
      s.genre = global_song.genre
      s.url = global_song.url
      s.notes = global_song.notes
      s.duration = global_song.duration
      s.year = global_song.year
      s.album = global_song.album
      s.lyrics = global_song.lyrics
    end
    
    # Add song to band if not already added
    unless band.songs.include?(song)
      band.songs << song
    end
  end
  puts "Added #{band.songs.count} songs to band #{band.name}"
end

# Create gigs for each band
bands.each do |band|
  band_venues = venues.select { |v| v.band == band }
  all_venues = venues # Can also play at other venues
  
  # Create 2 past gigs
  2.times do |i|
    past_date = Date.current - rand(30..365).days
    venue = all_venues.sample
    
    gig = Gig.find_or_create_by(
      name: "#{venue.name}",
      band: band,
      performance_date: past_date
    ) do |g|
      g.venue = venue
      g.start_time = Time.parse("#{rand(19..21)}:#{['00', '30'].sample}")
      g.end_time = g.start_time + rand(2..4).hours
      g.notes = "Past performance - great crowd!"
    end
    
    # Add 3-6 songs to each gig
    gig_songs = band.songs.sample(rand(3..6))
    gig_songs.each_with_index do |song, position|
      GigSong.find_or_create_by(
        gig: gig,
        song: song,
        position: position + 1
      )
    end
    puts "Created past gig: #{gig.name} on #{gig.performance_date}"
  end
  
  # Create 3-8 future gigs
  rand(3..8).times do |i|
    future_date = Date.current + rand(7..365).days
    venue = all_venues.sample
    
    gig = Gig.find_or_create_by(
      name: "#{venue.name}",
      band: band,
      performance_date: future_date
    ) do |g|
      g.venue = venue
      g.start_time = Time.parse("#{rand(19..22)}:#{['00', '30'].sample}")
      g.end_time = g.start_time + rand(2..4).hours
      g.notes = "Upcoming show - get ready!"
    end
    
    # Add 4-8 songs to each future gig
    gig_songs = band.songs.sample(rand(4..8))
    gig_songs.each_with_index do |song, position|
      GigSong.find_or_create_by(
        gig: gig,
        song: song,
        position: position + 1
      )
    end
    puts "Created future gig: #{gig.name} on #{gig.performance_date}"
  end
end

puts "\nSeeding completed successfully!"
puts "Created:"
puts "- #{User.count} users (all with password 'test123')"
puts "- #{Band.count} bands"
puts "- #{GlobalSong.count} global songs"
puts "- #{Song.count} band-specific songs"
puts "- #{Venue.count} venues"
puts "- #{Gig.count} gigs (past and future)"
puts "- #{GigSong.count} gig songs"