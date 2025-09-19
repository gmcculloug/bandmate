require 'google/apis/calendar_v3'
require 'googleauth'
require 'json'

class GoogleCalendarService
  def initialize(band)
    @band = band
    @service = Google::Apis::CalendarV3::CalendarService.new
    @service.authorization = authorize
  end

  # Sync a gig to Google Calendar
  def sync_gig_to_calendar(gig)
    return false unless @band.google_calendar_enabled? && @band.google_calendar_id.present?

    begin
      # Check if gig already exists in Google Calendar
      existing_event = find_existing_event(gig)

      if existing_event
        update_event(gig, existing_event.id)
      else
        create_event(gig)
      end

      true
    rescue => e
      false
    end
  end

  # Remove a gig from Google Calendar
  def remove_gig_from_calendar(gig)
    return false unless @band.google_calendar_enabled? && @band.google_calendar_id.present?

    begin
      existing_event = find_existing_event(gig)
      if existing_event
        @service.delete_event(@band.google_calendar_id, existing_event.id)
        # Remove from our tracking table
        GoogleCalendarEvent.where(band: @band, gig: gig).destroy_all
      end
      true
    rescue => e
      false
    end
  end

  # Sync all gigs for the band to Google Calendar
  def sync_all_gigs
    return { success: false, synced_count: 0, total_count: 0, errors: ['Google Calendar not enabled'] } unless @band.google_calendar_enabled? && @band.google_calendar_id.present?

    total_count = @band.gigs.count
    synced_count = 0
    errors = []

    @band.gigs.find_each do |gig|
      if sync_gig_to_calendar(gig)
        synced_count += 1
      else
        errors << "Failed to sync gig: #{gig.name}"
      end
    end

    {
      success: synced_count == total_count,
      synced_count: synced_count,
      total_count: total_count,
      errors: errors
    }
  end

  # Test connection to Google Calendar
  def test_connection
    return { success: false, error: 'Google Calendar not enabled' } unless @band.google_calendar_enabled?
    return { success: false, error: 'No calendar ID provided' } unless @band.google_calendar_id.present?

    begin
      calendar = @service.get_calendar(@band.google_calendar_id)
      { success: true, calendar_name: calendar.summary }
    rescue => e
      { success: false, error: e.message }
    end
  end

  private

  def authorize
    # For the simple approach, we'll use a service account
    # The service account needs to be shared with the calendar
    credentials = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: StringIO.new(ENV['GOOGLE_SERVICE_ACCOUNT_JSON'] || '{}'),
      scope: Google::Apis::CalendarV3::AUTH_CALENDAR
    )
    credentials
  end

  def find_existing_event(gig)
    # Look for existing Google Calendar event for this gig
    google_event = GoogleCalendarEvent.find_by(band: @band, gig: gig)
    return nil unless google_event

    begin
      @service.get_event(@band.google_calendar_id, google_event.google_event_id)
    rescue
      # Event might have been deleted from Google Calendar
      google_event.destroy
      nil
    end
  end

  def create_event(gig)
    event = build_event_from_gig(gig)

    result = @service.insert_event(@band.google_calendar_id, event)

    # Track the event in our database
    GoogleCalendarEvent.create!(
      band: @band,
      gig: gig,
      google_event_id: result.id,
      last_synced_at: Time.current
    )

    result
  end

  def update_event(gig, google_event_id)
    event = build_event_from_gig(gig)

    result = @service.update_event(@band.google_calendar_id, google_event_id, event)

    # Update our tracking record
    google_event = GoogleCalendarEvent.find_by(band: @band, gig: gig)
    if google_event
      google_event.update!(last_synced_at: Time.current)
    else
      GoogleCalendarEvent.create!(
        band: @band,
        gig: gig,
        google_event_id: result.id,
        last_synced_at: Time.current
      )
    end

    result
  end

  def build_event_from_gig(gig)
    # Build Google Calendar event from gig data
    start_time = build_datetime(gig.performance_date, gig.start_time)
    end_time = build_datetime(gig.performance_date, gig.end_time)

    # If end_time is nil, default to 3 hours after start
    if end_time.nil?
      end_time = start_time + 3.hours
    # If end time is before start time, assume it's the next day
    elsif end_time < start_time
      end_time = build_datetime(gig.performance_date + 1.day, gig.end_time)
    end

    event = Google::Apis::CalendarV3::Event.new(
      summary: "#{gig.name} - #{@band.name}",
      description: build_event_description(gig, start_time, end_time),
      start: Google::Apis::CalendarV3::EventDateTime.new(
        date: gig.performance_date.to_s
      ),
      end: Google::Apis::CalendarV3::EventDateTime.new(
        date: (gig.performance_date + 1.day).to_s
      )
    )

    # Add venue information if available
    if gig.venue
      event.location = "#{gig.venue.name}, #{gig.venue.location}"
    end

    # Add notes if available
    if gig.notes.present?
      event.description = "#{event.description}\n\nNotes: #{gig.notes}"
    end

    event
  end

  def build_datetime(date, time)
    if time.nil? || time.to_s.strip.empty?
      return date.to_time
    end

    Time.parse("#{date} #{time}")
  rescue ArgumentError => e
    # Log the error for debugging but return a fallback
    Rails.logger.warn("Failed to parse time '#{time}' for date '#{date}': #{e.message}") if defined?(Rails)
    date.to_time
  rescue => e
    # Log unexpected errors
    Rails.logger.error("Unexpected error parsing time '#{time}' for date '#{date}': #{e.message}") if defined?(Rails)
    date.to_time
  end

  def build_event_description(gig, start_time, end_time)
    description_parts = []

    # Add start and end times
    if start_time.present?
      description_parts << "Start Time: #{format_time(start_time)}"
    end
    if end_time.present?
      description_parts << "End Time: #{format_time(end_time)}"
    end

    # Add venue information
    add_venue_info(description_parts, gig.venue) if gig.venue

    description_parts.join("\n")
  end

  def format_time(time)
    time.strftime("%-I:%M %p")
  end

  def add_venue_info(description_parts, venue)
    description_parts << "Venue: #{venue.name}"
    description_parts << "Location: #{venue.location}"
    description_parts << "Phone: #{venue.phone_number}" if venue.phone_number.present?
    description_parts << "Website: #{venue.website}" if venue.website.present?
  end
end
