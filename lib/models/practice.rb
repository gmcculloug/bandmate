class Practice < ActiveRecord::Base
  belongs_to :band
  belongs_to :created_by_user, class_name: 'User'
  has_many :practice_availabilities, dependent: :destroy

  validates :week_start_date, presence: true
  validates :status, presence: true, inclusion: { in: %w[active finalized cancelled] }

  validate :week_start_date_must_be_sunday
  validate :unique_week_for_band
  validate :end_date_after_start_date
  validate :no_overlapping_practices

  scope :active, -> { where(status: 'active') }
  scope :for_week, ->(date) { where(week_start_date: date.beginning_of_week(:sunday)) }

  # For backward compatibility - use end_date if available, otherwise calculate
  def week_end_date
    end_date || week_start_date + 6.days
  end

  def practice_dates
    (week_start_date..week_end_date).to_a
  end

  # Return day names for the practice period
  def days_of_week_for_period
    practice_dates.map { |date| date.strftime('%A') }.uniq
  end

  def formatted_date_range
    if week_start_date.year == week_end_date.year
      if week_start_date.month == week_end_date.month
        "#{week_start_date.strftime('%b %d')} - #{week_end_date.strftime('%b %d, %Y')}"
      else
        "#{week_start_date.strftime('%b %d')} - #{week_end_date.strftime('%b %d, %Y')}"
      end
    else
      "#{week_start_date.strftime('%b %d, %Y')} - #{week_end_date.strftime('%b %d, %Y')}"
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

    # Group by day_of_week and count available responses
    day_scores = practice_availabilities
      .where(availability: 'available')
      .group(:day_of_week)
      .count

    # Add maybe responses with half weight
    maybe_scores = practice_availabilities
      .where(availability: 'maybe')
      .group(:day_of_week)
      .count

    combined_scores = {}
    practice_dates.each_with_index do |date, index|
      day_index = index
      combined_scores[day_index] = (day_scores[day_index] || 0) + (maybe_scores[day_index] || 0) * 0.5
    end

    # Return the day with highest score, or nil if no availability
    return nil if combined_scores.values.all?(&:zero?)

    best_day_index = combined_scores.max_by { |day, score| score }.first
    practice_dates[best_day_index]&.strftime('%A')
  end

  def best_practice_date
    return nil unless practice_availabilities.any?

    # Group by day_of_week and count available responses
    day_scores = practice_availabilities
      .where(availability: 'available')
      .group(:day_of_week)
      .count

    # Add maybe responses with half weight
    maybe_scores = practice_availabilities
      .where(availability: 'maybe')
      .group(:day_of_week)
      .count

    combined_scores = {}
    practice_dates.each_with_index do |date, index|
      day_index = index
      combined_scores[day_index] = (day_scores[day_index] || 0) + (maybe_scores[day_index] || 0) * 0.5
    end

    # Return the date with highest score, or nil if no availability
    return nil if combined_scores.values.all?(&:zero?)

    best_day_index = combined_scores.max_by { |day, score| score }.first
    practice_dates[best_day_index]
  end

  def availability_summary
    summary = {}
    practice_dates.each_with_index do |date, index|
      day_name = date.strftime('%A')
      availabilities = practice_availabilities.where(day_of_week: index)

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

  def suggested_times_for_day(day_index)
    practice_availabilities
      .where(day_of_week: day_index)
      .where.not(suggested_start_time: nil, suggested_end_time: nil)
      .includes(:user)
  end

  def most_popular_time_for_day(day_index)
    suggestions = suggested_times_for_day(day_index)
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

  private

  def week_start_date_must_be_sunday
    return unless week_start_date

    unless week_start_date.sunday?
      errors.add(:week_start_date, "must be a Sunday")
    end
  end

  def unique_week_for_band
    return unless week_start_date && band_id

    existing = band.practices.where(week_start_date: week_start_date)
    existing = existing.where.not(id: id) if persisted?

    if existing.exists?
      errors.add(:week_start_date, "already has a practice scheduled for this week")
    end
  end

  def end_date_after_start_date
    return unless week_start_date && end_date

    if end_date < week_start_date
      errors.add(:end_date, "must be after start date")
    end
  end

  def no_overlapping_practices
    return unless week_start_date && band_id

    current_end_date = end_date || week_start_date + 6.days
    overlapping = band.practices.where.not(id: id)
      .where(
        "(week_start_date BETWEEN ? AND ?) OR (COALESCE(end_date, week_start_date + INTERVAL '6 days') BETWEEN ? AND ?) OR (week_start_date <= ? AND COALESCE(end_date, week_start_date + INTERVAL '6 days') >= ?)",
        week_start_date, current_end_date,
        week_start_date, current_end_date,
        week_start_date, current_end_date
      )

    if overlapping.exists?
      errors.add(:base, "Practice dates overlap with an existing practice session")
    end
  end
end

