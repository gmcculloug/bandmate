class BlackoutDate < ActiveRecord::Base
  belongs_to :user
  
  validates :blackout_date, presence: true
  validates :user, presence: true
  validates :user_id, uniqueness: { scope: :blackout_date }
  validate :blackout_date_not_in_past
  
  scope :for_date_range, ->(start_date, end_date) { where(blackout_date: start_date..end_date) }
  
  private
  
  def blackout_date_not_in_past
    return unless blackout_date.present?
    
    if blackout_date < Date.current
      errors.add(:blackout_date, "cannot be in the past")
    end
  end
end