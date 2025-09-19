class GoogleCalendarEvent < ActiveRecord::Base
  belongs_to :band
  belongs_to :gig

  validates :google_event_id, presence: true, uniqueness: { scope: :band_id }
  validates :band, presence: true
  validates :gig, presence: true
  validates :last_synced_at, presence: true

  scope :recently_synced, -> { where('last_synced_at > ?', 1.hour.ago) }
  scope :needs_sync, -> { where('last_synced_at < ?', 1.hour.ago) }
  scope :for_band, ->(band) { where(band: band) }
  scope :for_gig, ->(gig) { where(gig: gig) }
end

