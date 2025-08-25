class GigSong < ActiveRecord::Base
  belongs_to :gig
  belongs_to :song
  
  validates :position, presence: true, numericality: { greater_than: 0 }
  validates :set_number, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 3 }
end