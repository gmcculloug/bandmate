class GigSong < ActiveRecord::Base
  belongs_to :gig
  belongs_to :song

  validates :position, presence: true, numericality: { greater_than: 0 }
  validates :position, uniqueness: { scope: [:gig_id, :set_number] }
  validates :set_number, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 3 }
  validates :gig, presence: true
  validates :song, presence: true

  # Transition-related scopes and methods
  scope :with_transitions, -> { where(has_transition: true) }
  scope :for_set, ->(set_number) { where(set_number: set_number) }

  # Find the next song in the same set based on position
  def next_song_in_set
    self.class.where(
      gig_id: gig_id,
      set_number: set_number,
      position: position + 1
    ).first
  end

  # Check if this song can have a transition (not the last song in set)
  def can_have_transition?
    next_song_in_set.present?
  end

  # Toggle transition state
  def toggle_transition!
    if can_have_transition?
      update!(has_transition: !has_transition)
    else
      update!(has_transition: false)
    end
  end

  # Get transition data for JSON responses
  def transition_data
    {
      has_transition: has_transition,
      transition_type: transition_type,
      transition_notes: transition_notes,
      transition_timing: transition_timing
    }
  end
end