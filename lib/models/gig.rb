class Gig < ActiveRecord::Base
  belongs_to :band
  belongs_to :venue, optional: true
  has_many :gig_songs, dependent: :destroy
  has_many :songs, through: :gig_songs
  
  validates :name, presence: true
  validates :band, presence: true
  validates :performance_date, presence: true
end