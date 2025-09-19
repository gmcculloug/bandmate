class UserBand < ActiveRecord::Base
  belongs_to :user
  belongs_to :band
  
  validates :user_id, uniqueness: { scope: :band_id }
  validates :user, presence: true
  validates :band, presence: true
end