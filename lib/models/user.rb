class User < ActiveRecord::Base
  has_secure_password
  has_many :user_bands
  has_many :bands, through: :user_bands
  has_many :blackout_dates, dependent: :destroy
  belongs_to :last_selected_band, class_name: 'Band', optional: true
  
  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 6 }, if: :password_digest_changed?
  validates :email, uniqueness: { case_sensitive: false }, allow_blank: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
end