class PracticeAvailability < ActiveRecord::Base
  belongs_to :practice
  belongs_to :user

  validates :specific_date, presence: true
  validates :availability, presence: true, inclusion: { in: %w[available not_available maybe] }
  validates :specific_date, uniqueness: { scope: [:practice_id, :user_id],
                                        message: "already has availability set for this date" }

  scope :available, -> { where(availability: 'available') }
  scope :not_available, -> { where(availability: 'not_available') }
  scope :maybe, -> { where(availability: 'maybe') }
  scope :for_date, ->(date) { where(specific_date: date) }

  def day_name
    specific_date.strftime('%A')
  end

  def formatted_date
    specific_date.strftime('%B %d, %Y')
  end

  def availability_class
    case availability
    when 'available'
      'success'
    when 'maybe'
      'warning'
    when 'not_available'
      'danger'
    end
  end

  def availability_display
    case availability
    when 'available'
      'Available'
    when 'maybe'
      'Maybe'
    when 'not_available'
      'Not Available'
    end
  end

  def availability_icon
    case availability
    when 'available'
      '✓'
    when 'maybe'
      '?'
    when 'not_available'
      '✗'
    end
  end

  def has_suggested_times?
    suggested_start_time.present? && suggested_end_time.present?
  end

  def suggested_time_range
    return nil unless has_suggested_times?
    "#{suggested_start_time.strftime('%I:%M %p')} - #{suggested_end_time.strftime('%I:%M %p')}"
  end

  def suggested_duration_hours
    return nil unless has_suggested_times?
    # Convert times to seconds since midnight for calculation
    start_seconds = suggested_start_time.seconds_since_midnight
    end_seconds = suggested_end_time.seconds_since_midnight

    # Handle case where end time is next day (past midnight)
    if end_seconds < start_seconds
      end_seconds += 24.hours
    end

    (end_seconds - start_seconds) / 1.hour
  end
end