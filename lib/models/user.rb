class User < ActiveRecord::Base
  has_secure_password
  has_many :user_bands
  has_many :bands, through: :user_bands
  has_many :blackout_dates, dependent: :destroy
  belongs_to :last_selected_band, class_name: 'Band', optional: true
  has_many :created_practices, class_name: 'Practice', foreign_key: 'created_by_user_id', dependent: :destroy
  has_many :practice_availabilities, dependent: :destroy
  
  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 6 }, if: :password_digest_changed?
  validates :email, uniqueness: { case_sensitive: false }, allow_blank: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  
  # Helper methods for checking ownership and membership
  def owner_of?(band)
    return false unless band
    user_bands.exists?(band_id: band.id, role: 'owner')
  end
  
  def member_of?(band)
    return false unless band
    user_bands.exists?(band_id: band.id)
  end
end