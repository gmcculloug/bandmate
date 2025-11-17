class Practice < ActiveRecord::Base
  belongs_to :band
  belongs_to :created_by_user, class_name: 'User'
  has_many :practice_availabilities, dependent: :destroy

  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :status, presence: true, inclusion: { in: %w[active finalized cancelled] }

  validate :end_date_after_start_date
  validate :no_overlapping_practices

  scope :active, -> { where(status: 'active') }
  scope :for_date_range, ->(start_date, end_date) { where('start_date <= ? AND end_date >= ?', end_date, start_date) }

  # For backward compatibility - now just returns end_date
  def week_end_date
    end_date
  end

  def practice_dates
    (start_date..end_date).to_a
  end

  # Return day names for the practice period
  def days_of_week_for_period
    practice_dates.map { |date| date.strftime('%A') }.uniq
  end

  def formatted_date_range
    if start_date.year == end_date.year
      if start_date.month == end_date.month
        "#{start_date.strftime('%b %d')} - #{end_date.strftime('%b %d, %Y')}"
      else
        "#{start_date.strftime('%b %d')} - #{end_date.strftime('%b %d, %Y')}"
      end
    else
      "#{start_date.strftime('%b %d, %Y')} - #{end_date.strftime('%b %d, %Y')}"
    end
  end

  # Legacy method name for backward compatibility
  alias_method :week_dates, :practice_dates
  alias_method :formatted_week_range, :formatted_date_range

  # For backward compatibility - return all days for the practice period
  def days_of_week
    practice_dates.map { |date| date.strftime('%A') }
  end

  def band_members
    band.users
  end

  def response_count
    practice_availabilities.select(:user_id).distinct.count
  end

  def total_band_members
    band.users.count
  end

  def all_members_responded?
    response_count >= total_band_members
  end

  def best_day
    return nil unless practice_availabilities.any?

    # Group by specific_date and count available responses
    date_scores = practice_availabilities
      .where(availability: 'available')
      .group(:specific_date)
      .count

    # Add maybe responses with half weight
    maybe_scores = practice_availabilities
      .where(availability: 'maybe')
      .group(:specific_date)
      .count

    combined_scores = {}
    practice_dates.each do |date|
      combined_scores[date] = (date_scores[date] || 0) + (maybe_scores[date] || 0) * 0.5
    end

    # Return the day with highest score, or nil if no availability
    return nil if combined_scores.values.all?(&:zero?)

    best_date = combined_scores.max_by { |date, score| score }.first
    best_date&.strftime('%A')
  end

  def best_practice_date
    return nil unless practice_availabilities.any?

    # Group by specific_date and count available responses
    date_scores = practice_availabilities
      .where(availability: 'available')
      .group(:specific_date)
      .count

    # Add maybe responses with half weight
    maybe_scores = practice_availabilities
      .where(availability: 'maybe')
      .group(:specific_date)
      .count

    combined_scores = {}
    practice_dates.each do |date|
      combined_scores[date] = (date_scores[date] || 0) + (maybe_scores[date] || 0) * 0.5
    end

    # Return the date with highest score, or nil if no availability
    return nil if combined_scores.values.all?(&:zero?)

    best_date = combined_scores.max_by { |date, score| score }.first
    best_date
  end

  def availability_summary
    summary = {}
    practice_dates.each do |date|
      day_name = date.strftime('%A')
      availabilities = practice_availabilities.where(specific_date: date)

      summary[day_name] = {
        available: availabilities.where(availability: 'available').count,
        maybe: availabilities.where(availability: 'maybe').count,
        not_available: availabilities.where(availability: 'not_available').count,
        no_response: total_band_members - availabilities.count,
        suggested_times: availabilities.where.not(suggested_start_time: nil, suggested_end_time: nil).order(:suggested_start_time),
        date: date
      }
    end
    summary
  end

  def suggested_times_for_date(date)
    practice_availabilities
      .where(specific_date: date)
      .where.not(suggested_start_time: nil, suggested_end_time: nil)
      .includes(:user)
  end

  def most_popular_time_for_date(date)
    suggestions = suggested_times_for_date(date)
    return nil if suggestions.empty?

    # Group by start time and count occurrences
    time_counts = suggestions.group_by { |s| [s.suggested_start_time.strftime('%H:%M'), s.suggested_end_time.strftime('%H:%M')] }
    return nil if time_counts.empty?

    # Find the most common time suggestion - sort by count descending, then by time ascending for deterministic results
    sorted_counts = time_counts.sort_by { |time, availabilities| [-availabilities.length, time[0]] }
    most_common = sorted_counts.first
    start_time_str, end_time_str = most_common[0]
    count = most_common[1].length

    {
      start_time: start_time_str,
      end_time: end_time_str,
      count: count,
      total_suggestions: suggestions.length
    }
  end

  # Legacy methods for backward compatibility
  alias_method :suggested_times_for_day, :suggested_times_for_date
  alias_method :most_popular_time_for_day, :most_popular_time_for_date

  # Get dates that have at least one available or maybe response
  def possible_dates
    return [] unless practice_availabilities.any?

    dates_with_responses = practice_availabilities
      .where(availability: ['available', 'maybe'])
      .select(:specific_date)
      .distinct
      .pluck(:specific_date)
      .sort

    dates_with_responses.map { |date| date.strftime('%A') }.uniq
  end

  # Get formatted string of possible dates for display
  def possible_dates_display
    dates = possible_dates
    return nil if dates.empty?

    case dates.length
    when 1
      dates.first
    when 2
      "#{dates.first}, #{dates.last}"
    else
      "#{dates[0..-2].join(', ')}, #{dates.last}"
    end
  end

  private

  def end_date_after_start_date
    return unless start_date && end_date

    if end_date < start_date
      errors.add(:end_date, "must be after start date")
    end
  end

  def no_overlapping_practices
    return unless start_date && end_date && band_id

    overlapping = band.practices.where.not(id: id)
      .where(
        "(start_date BETWEEN ? AND ?) OR (end_date BETWEEN ? AND ?) OR (start_date <= ? AND end_date >= ?)",
        start_date, end_date,
        start_date, end_date,
        start_date, end_date
      )

    if overlapping.exists?
      errors.add(:base, "Practice dates overlap with an existing practice session")
    end
  end
end

