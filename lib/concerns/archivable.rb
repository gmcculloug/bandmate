# Concern for adding archive/unarchive functionality to models
module Archivable
  extend ActiveSupport::Concern

  included do
    # Scopes for filtering archived/active records
    scope :active, -> { where(archived: false) }
    scope :archived, -> { where(archived: true) }
  end

  # Instance methods for archiving
  def archive!
    update!(archived: true, archived_at: Time.current)
  end

  def unarchive!
    update!(archived: false, archived_at: nil)
  end

  def archived?
    archived
  end

  def active?
    !archived
  end
end