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
  validates :timezone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) + [nil] }, allow_nil: true

  # Helper methods for checking ownership and membership
  def owner_of?(band)
    return false unless band
    user_bands.exists?(band_id: band.id, role: 'owner')
  end

  def member_of?(band)
    return false unless band
    user_bands.exists?(band_id: band.id)
  end

  # Timezone helpers
  def user_timezone
    timezone.presence || detect_timezone || 'UTC'
  end

  def time_zone
    ActiveSupport::TimeZone.new(user_timezone)
  end

  private

  def detect_timezone
    # Try to detect a reasonable default timezone based on common US timezones
    # In a real app, you might detect this from IP geolocation or browser timezone
    case Time.now.zone
    when 'EST', 'EDT'
      'America/New_York'
    when 'CST', 'CDT'
      'America/Chicago'
    when 'MST', 'MDT'
      'America/Denver'
    when 'PST', 'PDT'
      'America/Los_Angeles'
    else
      'America/New_York' # Default to Eastern if we can't detect
    end
  end
end