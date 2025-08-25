class Band < ActiveRecord::Base
  belongs_to :owner, class_name: 'User', optional: true
  has_and_belongs_to_many :songs, join_table: 'songs_bands'
  has_many :gigs
  has_many :venues
  has_many :user_bands
  has_many :users, through: :user_bands
  
  validates :name, presence: true
  validates :name, uniqueness: true
  
  def owner?
    owner.present?
  end
  
  def owned_by?(user)
    owner == user
  end
end