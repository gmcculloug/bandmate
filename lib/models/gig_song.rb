class GigSong < ActiveRecord::Base
  belongs_to :gig
  belongs_to :song

  validates :position, presence: true, numericality: { greater_than: 0 }
  validates :position, uniqueness: { scope: [:gig_id, :set_number] }
  validates :set_number, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 3 }
  validates :gig, presence: true
  validates :song, presence: true
end