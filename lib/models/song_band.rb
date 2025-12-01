class SongBand < ActiveRecord::Base
  self.table_name = 'songs_bands'
  self.primary_key = nil  # No single primary key, use composite keys

  belongs_to :song
  belongs_to :band

  validates :song_id, uniqueness: { scope: :band_id }
  validates :song, presence: true
  validates :band, presence: true

  # Scopes
  scope :practice, -> { where(practice_state: true) }
  scope :ready, -> { where(practice_state: false) }
  scope :for_band, ->(band) { where(band_id: band.id) }
  scope :for_song, ->(song) { where(song_id: song.id) }

  # Default practice_state to false if not set
  before_validation :set_default_practice_state, on: :create

  # Helper methods
  def practice?
    practice_state
  end

  def ready?
    !practice_state
  end

  def toggle_practice_state!
    new_state = !practice_state
    self.class.where(song_id: song_id, band_id: band_id).update_all(
      practice_state: new_state,
      practice_state_updated_at: Time.current
    )
    self.practice_state = new_state
    new_state
  end

  # Class method to find or create a song_band relationship
  def self.find_by_song_and_band(song, band)
    find_by(song_id: song.id, band_id: band.id)
  end

  def self.find_or_create_by_song_and_band(song, band)
    find_or_create_by(song_id: song.id, band_id: band.id)
  end

  private

  def set_default_practice_state
    self.practice_state = false if self.practice_state.nil?
  end
end