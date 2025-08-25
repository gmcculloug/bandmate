class Venue < ActiveRecord::Base
  belongs_to :band, optional: true
  has_many :gigs
  
  validates :name, presence: true
  validates :location, presence: true
  validates :contact_name, presence: true
  validates :phone_number, presence: true
end