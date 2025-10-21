class Venue < ActiveRecord::Base
  belongs_to :band, optional: true
  has_many :gigs

  validates :name, presence: true
  validates :location, presence: true
  validates :contact_name, presence: true
  validates :phone_number, presence: true

  # Scopes for filtering venues
  scope :active, -> { where(archived: false) }
  scope :archived, -> { where(archived: true) }

  # Instance methods for archiving
  def archive!
    update!(archived: true)
  end

  def unarchive!
    update!(archived: false)
  end

  def archived?
    archived
  end

  def active?
    !archived
  end
end