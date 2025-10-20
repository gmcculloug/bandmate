module ApplicationHelpers
  # Authentication helpers
  def current_user
    if settings.test?
      # In test mode, try to get user from test session
      test_user_id = @test_session&.dig(:user_id) || session[:user_id]
      @current_user ||= User.find(test_user_id) if test_user_id
    else
      @current_user ||= User.find(session[:user_id]) if session[:user_id]
    end
  end

  def logged_in?
    !!current_user
  end

  def require_login
    unless logged_in?
      redirect '/login'
    end
  end

  def current_band
    if settings.test?
      # In test mode, try to get band from test session
      test_band_id = @test_session&.dig(:band_id) || session[:band_id]
      if test_band_id && logged_in?
        current_user.bands.find_by(id: test_band_id)
      end
    elsif session[:band_id] && logged_in?
      current_user.bands.find_by(id: session[:band_id])
    end
  end

  def user_bands
    logged_in? ? current_user.bands.order(:name) : Band.none
  end

  def filter_by_current_band(collection)
    return collection.none unless current_band && collection.respond_to?(:where)
    
    case collection.name
    when 'Song'
      collection.joins(:bands).where(bands: { id: current_band.id })
    when 'Gig'
      collection.where(band: current_band)
    when 'Venue'
      collection.where(band: current_band)
    else
      collection
    end
  end
  
  # Calendar helper methods
  def calendar_days_for_month(year, month)
    start_date = Date.new(year, month, 1)
    
    # Get last day of month
    next_month = month == 12 ? Date.new(year + 1, 1, 1) : Date.new(year, month + 1, 1)
    end_date = next_month - 1
    
    # Get the first day of the calendar (Sunday of the week containing the 1st)
    days_back_to_sunday = start_date.wday
    calendar_start = start_date - days_back_to_sunday
    
    # Get the last day of the calendar (Saturday of the week containing the last day)
    days_forward_to_saturday = 6 - end_date.wday
    calendar_end = end_date + days_forward_to_saturday
    
    # Generate all days in the calendar
    (calendar_start..calendar_end).to_a
  end
  
  def gigs_for_date(date, current_band_gigs: [], other_band_gigs: [], bandmate_conflicts: [], blackout_dates: [])
    gigs = {}
    
    # Current band gigs
    current_band_gigs.select { |gig| gig.performance_date == date }.each do |gig|
      gigs[:current] ||= []
      gigs[:current] << gig
    end
    
    # Other band gigs
    other_band_gigs.select { |gig| gig.performance_date == date }.each do |gig|
      gigs[:other] ||= []
      gigs[:other] << gig
    end
    
    # Bandmate conflicts
    bandmate_conflicts.select { |gig| gig.performance_date == date }.each do |gig|
      gigs[:conflicts] ||= []
      gigs[:conflicts] << gig
    end
    
    # Blackout dates
    blackout_dates.select { |blackout| blackout.blackout_date == date }.each do |blackout|
      gigs[:blackouts] ||= []
      gigs[:blackouts] << blackout
    end
    
    gigs
  end

  # Legacy method for backward compatibility
  def gigs_for_date_legacy(date)
    gigs_for_date(
      date,
      current_band_gigs: @current_band_gigs || [],
      other_band_gigs: @other_band_gigs || [],
      bandmate_conflicts: @bandmate_conflicts || [],
      blackout_dates: @blackout_dates || []
    )
  end
  
  def month_name(month)
    Date::MONTHNAMES[month]
  end
  
  def prev_month_link(year, month)
    if month == 1
      "/calendar?year=#{year - 1}&month=12"
    else
      "/calendar?year=#{year}&month=#{month - 1}"
    end
  end
  
  def next_month_link(year, month)
    if month == 12
      "/calendar?year=#{year + 1}&month=1"
    else
      "/calendar?year=#{year}&month=#{month + 1}"
    end
  end

  # Breadcrumb helper methods
  def set_breadcrumbs(*crumbs)
    @breadcrumbs = []

    # Always start with Home
    @breadcrumbs << { label: 'Home', icon: '🏠', url: '/gigs' }

    # Add provided breadcrumbs
    crumbs.each do |crumb|
      @breadcrumbs << crumb
    end
  end

  def add_breadcrumb(label, url = nil, icon = nil)
    @breadcrumbs ||= []
    @breadcrumbs << { label: label, url: url, icon: icon }
  end

  def breadcrumb_for_section(section)
    case section.to_s.downcase
    when 'gigs'
      { label: 'Gigs', icon: '📋', url: '/gigs' }
    when 'songs'
      { label: 'Songs', icon: '🎵', url: '/songs' }
    when 'venues'
      { label: 'Venues', icon: '🏢', url: '/venues' }
    when 'calendar'
      { label: 'Calendar', icon: '📅', url: '/calendar' }
    when 'bands'
      { label: 'Bands', icon: '🎸', url: '/bands' }
    when 'profile'
      { label: 'Profile', icon: '⚙️', url: '/profile' }
    when 'song_catalogs'
      { label: 'Song Catalog', icon: '🌍', url: '/song_catalogs' }
    else
      { label: section.to_s.capitalize, icon: '', url: nil }
    end
  end
end