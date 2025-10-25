class SongCatalog < ActiveRecord::Base
  has_many :songs
  
  validates :title, presence: true
  validates :artist, presence: true
  validates :key, presence: true
  validates :duration, presence: true
  validates :tempo, numericality: { greater_than: 0 }, allow_nil: true
  
  # Scope for searching global songs
  scope :search, ->(query) {
    where('LOWER(title) LIKE ? OR LOWER(artist) LIKE ?', "%#{query.downcase}%", "%#{query.downcase}%") if query.present?
  }

  # Archive scopes
  scope :active, -> { where(archived: false) }
  scope :archived, -> { where(archived: true) }

  # Archive methods
  def archive!
    update!(archived: true, archived_at: Time.current)
  end

  def unarchive!
    update!(archived: false, archived_at: nil)
  end
end