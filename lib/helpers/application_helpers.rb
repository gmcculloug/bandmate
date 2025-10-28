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
    @breadcrumbs << { label: '', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path><polyline points="9,22 9,12 15,12 15,22"></polyline></svg>', url: '/gigs' }

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
      { label: 'Gigs', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"></path><rect x="8" y="2" width="8" height="4" rx="1" ry="1"></rect></svg>', url: '/gigs' }
    when 'songs'
      { label: 'Songs', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M9 18V5l12-2v13"></path><circle cx="6" cy="18" r="3"></circle><circle cx="18" cy="16" r="3"></circle></svg>', url: '/songs' }
    when 'venues'
      { label: 'Venues', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M3 21h18"></path><path d="M5 21V7l8-4v18"></path><path d="M19 21V11l-6-4"></path></svg>', url: '/venues' }
    when 'calendar'
      { label: 'Calendar', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect><line x1="16" y1="2" x2="16" y2="6"></line><line x1="8" y1="2" x2="8" y2="6"></line><line x1="3" y1="10" x2="21" y2="10"></line></svg>', url: '/calendar' }
    when 'practices'
      { label: 'Practice', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M3 12h18m-9-9v18"></path><circle cx="12" cy="12" r="10"></circle></svg>', url: '/practices' }
    when 'bands'
      { label: 'Bands', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M9 18V5l12-2v13"></path><circle cx="6" cy="18" r="3"></circle><circle cx="18" cy="16" r="3"></circle></svg>', url: '/bands' }
    when 'profile'
      { label: 'Profile', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><circle cx="12" cy="12" r="3"></circle><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path></svg>', url: '/profile' }
    when 'song_catalogs'
      { label: 'Song Catalog', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><circle cx="12" cy="12" r="10"></circle><line x1="2" y1="12" x2="22" y2="12"></line><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"></path></svg>', url: '/song_catalogs' }
    else
      { label: section.to_s.capitalize, icon: '', url: nil }
    end
  end
end