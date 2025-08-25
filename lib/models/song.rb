class Song < ActiveRecord::Base
  belongs_to :global_song, optional: true
  has_and_belongs_to_many :bands, join_table: 'songs_bands'
  has_many :gig_songs
  has_many :gigs, through: :gig_songs
  
  validates :title, presence: true
  validates :artist, presence: true
  validates :key, presence: true
  validates :tempo, numericality: { greater_than: 0 }, allow_nil: true
  
  # Create a band-specific copy of a global song
  def self.create_from_global_song(global_song, band_ids = [])
    song = new(
      title: global_song.title,
      artist: global_song.artist,
      key: global_song.key,
      original_key: global_song.original_key,
      tempo: global_song.tempo,
      genre: global_song.genre,
      url: global_song.url,
      notes: global_song.notes,
      duration: global_song.duration,
      year: global_song.year,
      album: global_song.album,
      lyrics: global_song.lyrics,
      global_song: global_song
    )
    song.band_ids = band_ids
    song
  end
end