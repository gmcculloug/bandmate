class Band < ActiveRecord::Base
  belongs_to :owner, class_name: 'User', optional: true
  has_and_belongs_to_many :songs, join_table: 'songs_bands'
  has_many :gigs
  has_many :venues
  has_many :user_bands
  has_many :users, through: :user_bands
  has_many :google_calendar_events, dependent: :destroy
  
  validates :name, presence: true
  validates :name, uniqueness: true
  validates :google_calendar_id, presence: true, if: :google_calendar_enabled?

  def google_calendar_enabled?
    read_attribute(:google_calendar_enabled) == true
  end
  
  def owner?
    owner.present?
  end
  
  def owned_by?(user)
    owner == user
  end

  # Google Calendar integration methods
  def google_calendar_service
    @google_calendar_service ||= GoogleCalendarService.new(self)
  end

  def sync_gig_to_google_calendar(gig)
    return false unless google_calendar_enabled?
    google_calendar_service.sync_gig_to_calendar(gig)
  end

  def remove_gig_from_google_calendar(gig)
    return false unless google_calendar_enabled?
    google_calendar_service.remove_gig_from_calendar(gig)
  end

  def sync_all_gigs_to_google_calendar
    return false unless google_calendar_enabled?
    google_calendar_service.sync_all_gigs
  end

  def test_google_calendar_connection
    return { success: false, error: 'Google Calendar not enabled' } unless google_calendar_enabled?
    google_calendar_service.test_connection
  end
end