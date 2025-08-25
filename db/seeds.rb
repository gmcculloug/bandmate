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

# Create 100+ global songs for variety
global_songs_data = [
  # Classic Rock
  { title: "Sweet Home Alabama", artist: "Lynyrd Skynyrd", key: "G", original_key: "G", tempo: 100, genre: "Rock", year: 1974, album: "Second Helping", duration: "4:43" },
  { title: "Hotel California", artist: "Eagles", key: "Bm", original_key: "Bm", tempo: 75, genre: "Rock", year: 1976, album: "Hotel California", duration: "6:30" },
  { title: "Stairway to Heaven", artist: "Led Zeppelin", key: "Am", original_key: "Am", tempo: 82, genre: "Rock", year: 1971, album: "Led Zeppelin IV", duration: "8:02" },
  { title: "Free Bird", artist: "Lynyrd Skynyrd", key: "G", original_key: "G", tempo: 65, genre: "Southern Rock", year: 1973, album: "Pronounced Leh-nerd Skin-nerd", duration: "9:07" },
  { title: "Bohemian Rhapsody", artist: "Queen", key: "Bb", original_key: "Bb", tempo: 72, genre: "Progressive Rock", year: 1975, album: "A Night at the Opera", duration: "5:55" },
  { title: "Don't Stop Believin'", artist: "Journey", key: "E", original_key: "E", tempo: 119, genre: "Rock", year: 1981, album: "Escape", duration: "4:09" },
  { title: "Livin' on a Prayer", artist: "Bon Jovi", key: "Em", original_key: "Em", tempo: 123, genre: "Rock", year: 1986, album: "Slippery When Wet", duration: "4:09" },
  { title: "We Will Rock You", artist: "Queen", key: "C", original_key: "C", tempo: 114, genre: "Rock", year: 1977, album: "News of the World", duration: "2:02" },
  { title: "Another Brick in the Wall", artist: "Pink Floyd", key: "Dm", original_key: "Dm", tempo: 104, genre: "Progressive Rock", year: 1979, album: "The Wall", duration: "3:59" },
  { title: "Born to Run", artist: "Bruce Springsteen", key: "E", original_key: "E", tempo: 147, genre: "Rock", year: 1975, album: "Born to Run", duration: "4:30" },
  { title: "Smoke on the Water", artist: "Deep Purple", key: "G", original_key: "G", tempo: 112, genre: "Hard Rock", year: 1972, album: "Machine Head", duration: "5:40" },
  { title: "More Than a Feeling", artist: "Boston", key: "G", original_key: "G", tempo: 115, genre: "Rock", year: 1976, album: "Boston", duration: "4:45" },
  { title: "Tom Sawyer", artist: "Rush", key: "E", original_key: "E", tempo: 176, genre: "Progressive Rock", year: 1981, album: "Moving Pictures", duration: "4:33" },
  { title: "Back in Black", artist: "AC/DC", key: "E", original_key: "E", tempo: 94, genre: "Hard Rock", year: 1980, album: "Back in Black", duration: "4:15" },
  { title: "Highway to Hell", artist: "AC/DC", key: "A", original_key: "A", tempo: 115, genre: "Hard Rock", year: 1979, album: "Highway to Hell", duration: "3:28" },
  
  # Folk Rock & Singer-Songwriter
  { title: "Brown Eyed Girl", artist: "Van Morrison", key: "G", original_key: "G", tempo: 150, genre: "Folk Rock", year: 1967, album: "Blowin' Your Mind!", duration: "3:05" },
  { title: "Sweet Caroline", artist: "Neil Diamond", key: "C", original_key: "C", tempo: 125, genre: "Pop", year: 1969, album: "Brother Love's Travelling Salvation Show", duration: "3:21" },
  { title: "Fire and Rain", artist: "James Taylor", key: "A", original_key: "A", tempo: 76, genre: "Folk Rock", year: 1970, album: "Sweet Baby James", duration: "3:20" },
  { title: "American Pie", artist: "Don McLean", key: "G", original_key: "G", tempo: 76, genre: "Folk Rock", year: 1971, album: "American Pie", duration: "8:37" },
  { title: "The Sound of Silence", artist: "Simon & Garfunkel", key: "Am", original_key: "Am", tempo: 90, genre: "Folk Rock", year: 1964, album: "Wednesday Morning, 3 A.M.", duration: "3:05" },
  { title: "Mrs. Robinson", artist: "Simon & Garfunkel", key: "E", original_key: "E", tempo: 120, genre: "Folk Rock", year: 1968, album: "Bookends", duration: "4:04" },
  { title: "Blackbird", artist: "The Beatles", key: "G", original_key: "G", tempo: 96, genre: "Folk Rock", year: 1968, album: "The Beatles (White Album)", duration: "2:18" },
  { title: "Here Comes the Sun", artist: "The Beatles", key: "A", original_key: "A", tempo: 129, genre: "Folk Rock", year: 1969, album: "Abbey Road", duration: "3:05" },
  
  # 80s Rock & New Wave
  { title: "Eye of the Tiger", artist: "Survivor", key: "Cm", original_key: "Cm", tempo: 109, genre: "Rock", year: 1982, album: "Eye of the Tiger", duration: "4:04" },
  { title: "Don't Stop Me Now", artist: "Queen", key: "F", original_key: "F", tempo: 156, genre: "Rock", year: 1978, album: "Jazz", duration: "3:29" },
  { title: "Billie Jean", artist: "Michael Jackson", key: "F#m", original_key: "F#m", tempo: 117, genre: "Pop", year: 1982, album: "Thriller", duration: "4:54" },
  { title: "Beat It", artist: "Michael Jackson", key: "Em", original_key: "Em", tempo: 139, genre: "Pop Rock", year: 1982, album: "Thriller", duration: "4:18" },
  { title: "Sweet Child O' Mine", artist: "Guns N' Roses", key: "Db", original_key: "Db", tempo: 125, genre: "Hard Rock", year: 1987, album: "Appetite for Destruction", duration: "5:03" },
  { title: "Pour Some Sugar on Me", artist: "Def Leppard", key: "E", original_key: "E", tempo: 96, genre: "Hard Rock", year: 1987, album: "Hysteria", duration: "4:25" },
  { title: "Jump", artist: "Van Halen", key: "C", original_key: "C", tempo: 131, genre: "Hard Rock", year: 1983, album: "1984", duration: "4:04" },
  { title: "Runnin' with the Devil", artist: "Van Halen", key: "E", original_key: "E", tempo: 100, genre: "Hard Rock", year: 1978, album: "Van Halen", duration: "3:35" },
  { title: "Walk This Way", artist: "Aerosmith", key: "C", original_key: "C", tempo: 120, genre: "Hard Rock", year: 1975, album: "Toys in the Attic", duration: "3:40" },
  
  # Alternative & Grunge
  { title: "Wonderwall", artist: "Oasis", key: "Em", original_key: "Em", tempo: 87, genre: "Alternative Rock", year: 1995, album: "What's the Story Morning Glory?", duration: "4:18" },
  { title: "Smells Like Teen Spirit", artist: "Nirvana", key: "F", original_key: "F", tempo: 117, genre: "Grunge", year: 1991, album: "Nevermind", duration: "5:01" },
  { title: "Black", artist: "Pearl Jam", key: "E", original_key: "E", tempo: 69, genre: "Grunge", year: 1991, album: "Ten", duration: "5:43" },
  { title: "Alive", artist: "Pearl Jam", key: "A", original_key: "A", tempo: 76, genre: "Grunge", year: 1991, album: "Ten", duration: "5:41" },
  { title: "Come As You Are", artist: "Nirvana", key: "Em", original_key: "Em", tempo: 122, genre: "Grunge", year: 1991, album: "Nevermind", duration: "3:39" },
  { title: "Basket Case", artist: "Green Day", key: "Eb", original_key: "Eb", tempo: 168, genre: "Punk Rock", year: 1994, album: "Dookie", duration: "3:01" },
  { title: "Longview", artist: "Green Day", key: "Eb", original_key: "Eb", tempo: 148, genre: "Punk Rock", year: 1994, album: "Dookie", duration: "3:56" },
  { title: "Mr. Brightside", artist: "The Killers", key: "D", original_key: "D", tempo: 148, genre: "Alternative Rock", year: 2003, album: "Hot Fuss", duration: "3:42" },
  
  # Country & Folk
  { title: "Friends in Low Places", artist: "Garth Brooks", key: "A", original_key: "A", tempo: 128, genre: "Country", year: 1990, album: "No Fences", duration: "4:28" },
  { title: "Wagon Wheel", artist: "Old Crow Medicine Show", key: "G", original_key: "G", tempo: 150, genre: "Country Folk", year: 2004, album: "Old Crow Medicine Show", duration: "3:12" },
  { title: "Copperhead Road", artist: "Steve Earle", key: "Dm", original_key: "Dm", tempo: 126, genre: "Country Rock", year: 1988, album: "Copperhead Road", duration: "4:29" },
  { title: "Take Me Home, Country Roads", artist: "John Denver", key: "A", original_key: "A", tempo: 80, genre: "Country Folk", year: 1971, album: "Poems, Prayers & Promises", duration: "3:13" },
  { title: "Mammas Don't Let Your Babies Grow Up to Be Cowboys", artist: "Willie Nelson & Waylon Jennings", key: "D", original_key: "D", tempo: 120, genre: "Country", year: 1978, album: "Waylon & Willie", duration: "2:47" },
  { title: "Ring of Fire", artist: "Johnny Cash", key: "G", original_key: "G", tempo: 152, genre: "Country", year: 1963, album: "Ring of Fire: The Best of Johnny Cash", duration: "2:36" },
  { title: "Folsom Prison Blues", artist: "Johnny Cash", key: "E", original_key: "E", tempo: 123, genre: "Country", year: 1955, album: "With His Hot and Blue Guitar", duration: "2:49" },
  
  # Blues & R&B
  { title: "Pride and Joy", artist: "Stevie Ray Vaughan", key: "E", original_key: "E", tempo: 134, genre: "Blues", year: 1983, album: "Texas Flood", duration: "3:39" },
  { title: "The Thrill Is Gone", artist: "B.B. King", key: "Bm", original_key: "Bm", tempo: 64, genre: "Blues", year: 1969, album: "Completely Well", duration: "5:26" },
  { title: "Cross Road Blues", artist: "Robert Johnson", key: "A", original_key: "A", tempo: 120, genre: "Blues", year: 1936, album: "King of the Delta Blues Singers", duration: "2:41" },
  { title: "Mustang Sally", artist: "Wilson Pickett", key: "C", original_key: "C", tempo: 108, genre: "R&B", year: 1966, album: "The Wicked Pickett", duration: "4:04" },
  { title: "I Feel Good", artist: "James Brown", key: "D", original_key: "D", tempo: 144, genre: "Soul", year: 1965, album: "Papa's Got a Brand New Bag", duration: "2:51" },
  
  # Reggae & Ska
  { title: "No Woman No Cry", artist: "Bob Marley", key: "C", original_key: "C", tempo: 76, genre: "Reggae", year: 1974, album: "Natty Dread", duration: "7:08" },
  { title: "Three Little Birds", artist: "Bob Marley", key: "A", original_key: "A", tempo: 76, genre: "Reggae", year: 1977, album: "Exodus", duration: "3:00" },
  { title: "Red Red Wine", artist: "UB40", key: "Bb", original_key: "Bb", tempo: 78, genre: "Reggae", year: 1983, album: "Labour of Love", duration: "3:06" },
  { title: "The Impression That I Get", artist: "The Mighty Mighty Bosstones", key: "F", original_key: "F", tempo: 180, genre: "Ska", year: 1997, album: "Let's Face It", duration: "3:13" },
  
  # Indie & Modern Rock
  { title: "Float On", artist: "Modest Mouse", key: "F", original_key: "F", tempo: 180, genre: "Indie Rock", year: 2004, album: "Good News for People Who Love Bad News", duration: "3:28" },
  { title: "Seven Nation Army", artist: "The White Stripes", key: "Em", original_key: "Em", tempo: 124, genre: "Alternative Rock", year: 2003, album: "Elephant", duration: "3:51" },
  { title: "I Will Follow", artist: "U2", key: "A", original_key: "A", tempo: 150, genre: "Rock", year: 1980, album: "Boy", duration: "3:36" },
  { title: "Where the Streets Have No Name", artist: "U2", key: "D", original_key: "D", tempo: 131, genre: "Rock", year: 1987, album: "The Joshua Tree", duration: "5:36" },
  { title: "Clocks", artist: "Coldplay", key: "Eb", original_key: "Eb", tempo: 131, genre: "Alternative Rock", year: 2002, album: "A Rush of Blood to the Head", duration: "5:07" },
  { title: "Yellow", artist: "Coldplay", key: "B", original_key: "B", tempo: 87, genre: "Alternative Rock", year: 2000, album: "Parachutes", duration: "4:29" },
  { title: "Use Somebody", artist: "Kings of Leon", key: "C", original_key: "C", tempo: 136, genre: "Alternative Rock", year: 2008, album: "Only by the Night", duration: "3:51" },
  { title: "Sex on Fire", artist: "Kings of Leon", key: "E", original_key: "E", tempo: 150, genre: "Alternative Rock", year: 2008, album: "Only by the Night", duration: "3:23" },
  { title: "Somebody Told Me", artist: "The Killers", key: "Bb", original_key: "Bb", tempo: 133, genre: "Alternative Rock", year: 2004, album: "Hot Fuss", duration: "3:17" },
  
  # Classic Pop & Motown
  { title: "Dancing Queen", artist: "ABBA", key: "A", original_key: "A", tempo: 100, genre: "Pop", year: 1976, album: "Arrival", duration: "3:52" },
  { title: "Mamma Mia", artist: "ABBA", key: "D", original_key: "D", tempo: 138, genre: "Pop", year: 1975, album: "ABBA", duration: "3:32" },
  { title: "My Girl", artist: "The Temptations", key: "C", original_key: "C", tempo: 86, genre: "Motown", year: 1964, album: "The Temptations Sing Smokey", duration: "2:52" },
  { title: "I Heard It Through the Grapevine", artist: "Marvin Gaye", key: "Bb", original_key: "Bb", tempo: 87, genre: "Motown", year: 1968, album: "In the Groove", duration: "3:16" },
  { title: "Superstition", artist: "Stevie Wonder", key: "Eb", original_key: "Eb", tempo: 100, genre: "Funk", year: 1972, album: "Talking Book", duration: "4:26" },
  { title: "I Want You Back", artist: "The Jackson 5", key: "Ab", original_key: "Ab", tempo: 100, genre: "Motown", year: 1969, album: "Diana Ross Presents The Jackson 5", duration: "2:59" },
  
  # Punk & New Wave
  { title: "Blitzkrieg Bop", artist: "Ramones", key: "A", original_key: "A", tempo: 180, genre: "Punk Rock", year: 1976, album: "Ramones", duration: "2:12" },
  { title: "I Wanna Be Sedated", artist: "Ramones", key: "E", original_key: "E", tempo: 166, genre: "Punk Rock", year: 1978, album: "Road to Ruin", duration: "2:30" },
  { title: "London Calling", artist: "The Clash", key: "Em", original_key: "Em", tempo: 133, genre: "Punk Rock", year: 1979, album: "London Calling", duration: "3:19" },
  { title: "Should I Stay or Should I Go", artist: "The Clash", key: "G", original_key: "G", tempo: 115, genre: "Punk Rock", year: 1982, album: "Combat Rock", duration: "3:06" },
  { title: "Once in a Lifetime", artist: "Talking Heads", key: "C", original_key: "C", tempo: 102, genre: "New Wave", year: 1980, album: "Remain in Light", duration: "4:20" },
  { title: "Burning Down the House", artist: "Talking Heads", key: "Bb", original_key: "Bb", tempo: 126, genre: "New Wave", year: 1983, album: "Speaking in Tongues", duration: "4:00" },
  
  # Metal & Hard Rock
  { title: "Enter Sandman", artist: "Metallica", key: "Em", original_key: "Em", tempo: 123, genre: "Metal", year: 1991, album: "Metallica (Black Album)", duration: "5:31" },
  { title: "Master of Puppets", artist: "Metallica", key: "Em", original_key: "Em", tempo: 212, genre: "Metal", year: 1986, album: "Master of Puppets", duration: "8:35" },
  { title: "Breaking the Law", artist: "Judas Priest", key: "F#", original_key: "F#", tempo: 150, genre: "Metal", year: 1980, album: "British Steel", duration: "2:35" },
  { title: "Ace of Spades", artist: "Motörhead", key: "E", original_key: "E", tempo: 134, genre: "Metal", year: 1980, album: "Ace of Spades", duration: "2:49" },
  { title: "Crazy Train", artist: "Ozzy Osbourne", key: "F#", original_key: "F#", tempo: 138, genre: "Metal", year: 1980, album: "Blizzard of Ozz", duration: "4:53" },
  { title: "Iron Man", artist: "Black Sabbath", key: "B", original_key: "B", tempo: 71, genre: "Metal", year: 1970, album: "Paranoid", duration: "5:56" },
  { title: "Paranoid", artist: "Black Sabbath", key: "E", original_key: "E", tempo: 164, genre: "Metal", year: 1970, album: "Paranoid", duration: "2:48" },
  
  # 90s Alternative & Pop
  { title: "Torn", artist: "Natalie Imbruglia", key: "F", original_key: "F", tempo: 104, genre: "Alternative Pop", year: 1997, album: "Left of the Middle", duration: "4:04" },
  { title: "Creep", artist: "Radiohead", key: "G", original_key: "G", tempo: 92, genre: "Alternative Rock", year: 1992, album: "Pablo Honey", duration: "3:58" },
  { title: "1979", artist: "The Smashing Pumpkins", key: "Eb", original_key: "Eb", tempo: 120, genre: "Alternative Rock", year: 1995, album: "Mellon Collie and the Infinite Sadness", duration: "4:25" },
  { title: "Today", artist: "The Smashing Pumpkins", key: "Eb", original_key: "Eb", tempo: 132, genre: "Alternative Rock", year: 1993, album: "Siamese Dream", duration: "3:20" },
  { title: "What's Up?", artist: "4 Non Blondes", key: "G", original_key: "G", tempo: 78, genre: "Alternative Rock", year: 1992, album: "Bigger, Better, Faster, More!", duration: "4:55" },
  { title: "Zombie", artist: "The Cranberries", key: "Em", original_key: "Em", tempo: 84, genre: "Alternative Rock", year: 1994, album: "No Need to Argue", duration: "5:06" },
  { title: "I'm Gonna Be (500 Miles)", artist: "The Proclaimers", key: "E", original_key: "E", tempo: 131, genre: "Folk Rock", year: 1988, album: "Sunshine on Leith", duration: "3:36" },
  
  # Classic Jazz Standards (Easy versions)
  { title: "Fly Me to the Moon", artist: "Frank Sinatra", key: "C", original_key: "C", tempo: 120, genre: "Jazz", year: 1964, album: "It Might as Well Be Swing", duration: "2:29" },
  { title: "Blue Moon", artist: "Various Artists", key: "Bb", original_key: "Bb", tempo: 80, genre: "Jazz Standard", year: 1934, album: "", duration: "3:00" },
  { title: "Autumn Leaves", artist: "Various Artists", key: "Gm", original_key: "Gm", tempo: 120, genre: "Jazz Standard", year: 1945, album: "", duration: "3:30" },
  
  # Easy Crowd Pleasers
  { title: "Brown Sugar", artist: "The Rolling Stones", key: "C", original_key: "C", tempo: 125, genre: "Rock", year: 1971, album: "Sticky Fingers", duration: "3:49" },
  { title: "Start Me Up", artist: "The Rolling Stones", key: "C", original_key: "C", tempo: 126, genre: "Rock", year: 1981, album: "Tattoo You", duration: "3:33" },
  { title: "Paint It Black", artist: "The Rolling Stones", key: "Em", original_key: "Em", tempo: 126, genre: "Rock", year: 1966, album: "Aftermath", duration: "3:22" },
  { title: "Satisfaction", artist: "The Rolling Stones", key: "E", original_key: "E", tempo: 134, genre: "Rock", year: 1965, album: "Out of Our Heads", duration: "3:43" },
  { title: "Wild Thing", artist: "The Troggs", key: "A", original_key: "A", tempo: 120, genre: "Rock", year: 1966, album: "From Nowhere", duration: "2:35" },
  { title: "La Bamba", artist: "Ritchie Valens", key: "C", original_key: "C", tempo: 144, genre: "Rock & Roll", year: 1958, album: "Ritchie Valens", duration: "2:06" },
  { title: "Twist and Shout", artist: "The Beatles", key: "D", original_key: "D", tempo: 124, genre: "Rock & Roll", year: 1963, album: "Please Please Me", duration: "2:33" },
  { title: "Good Lovin'", artist: "The Young Rascals", key: "A", original_key: "A", tempo: 132, genre: "Rock", year: 1966, album: "The Young Rascals", duration: "2:53" },
  { title: "Hang on Sloopy", artist: "The McCoys", key: "C", original_key: "C", tempo: 150, genre: "Rock", year: 1965, album: "Hang On Sloopy", duration: "3:12" }
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
  # Each band gets 30-50 random global songs
  selected_global_songs = global_songs.sample(rand(30..50))
  
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
  
  # Create 3-4 past gigs
  rand(3..4).times do |i|
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
    
    # Add 3-6 songs to each past gig (all in set 1)
    gig_songs = band.songs.sample(rand(3..6))
    gig_songs.each_with_index do |song, position|
      GigSong.find_or_create_by(
        gig: gig,
        song: song,
        position: position + 1,
        set_number: 1
      )
    end
    puts "Created past gig: #{gig.name} on #{gig.performance_date}"
  end
  
  # Create 6-8 future gigs  
  rand(6..8).times do |i|
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
    
    # Add songs to future gigs with multiple sets
    total_songs = rand(6..12)
    available_songs = band.songs.to_a.shuffle
    
    # Determine number of sets (70% chance of 2 sets, 20% chance of 1 set, 10% chance of 3 sets)
    rand_num = rand(100)
    num_sets = if rand_num < 20
                 1
               elsif rand_num < 90
                 2
               else
                 3
               end
    
    # Distribute songs across sets
    songs_per_set = (total_songs / num_sets.to_f).ceil
    current_song_index = 0
    
    (1..num_sets).each do |set_number|
      # Determine songs for this set (slightly random distribution)
      songs_in_set = if set_number == num_sets
                       # Last set gets remaining songs
                       total_songs - current_song_index
                     else
                       # Other sets get 3-6 songs
                       [rand(3..6), total_songs - current_song_index].min
                     end
      
      next if songs_in_set <= 0 || current_song_index >= available_songs.length
      
      set_songs = available_songs[current_song_index, songs_in_set] || []
      set_songs.each_with_index do |song, position|
        GigSong.find_or_create_by(
          gig: gig,
          song: song,
          position: position + 1,
          set_number: set_number
        )
      end
      
      current_song_index += songs_in_set
    end
    puts "Created future gig: #{gig.name} on #{gig.performance_date} (#{num_sets} sets, #{total_songs} total songs)"
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