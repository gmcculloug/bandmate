require 'sinatra/base'

module Routes
end

class Routes::Calendar < Sinatra::Base
  configure do
    set :views, File.join(File.dirname(__FILE__), '..', '..', 'views')
  end
  
  helpers ApplicationHelpers
  
  # ============================================================================
  # CALENDAR AND BLACKOUT DATE ROUTES
  # ============================================================================

  get '/calendar' do
    require_login
    
    # Get the requested month/year or default to current
    @year = params[:year] ? params[:year].to_i : Date.current.year
    @month = params[:month] ? params[:month].to_i : Date.current.month
    
    # Ensure month is valid
    @month = [[1, @month].max, 12].min
    
    # Get the full calendar range including padding days from previous/next month
    start_date = Date.new(@year, @month, 1)
    next_month = @month == 12 ? Date.new(@year + 1, 1, 1) : Date.new(@year, @month + 1, 1)
    end_date = next_month - 1

    # Calculate actual calendar display range (includes padding days)
    days_back_to_sunday = start_date.wday
    calendar_start = start_date - days_back_to_sunday

    days_forward_to_saturday = 6 - end_date.wday
    calendar_end = end_date + days_forward_to_saturday
    
    # Get all user's bands
    user_band_ids = current_user.bands.pluck(:id)
    
    # Get current band gigs for the full calendar range
    @current_band_gigs = if current_band
      current_band.gigs.where(performance_date: calendar_start..calendar_end)
                        .includes(:venue)
                        .order(:performance_date)
    else
      []
    end
    
    # Get user's gigs from other bands for the full calendar range
    @other_band_gigs = Gig.joins(:band)
                          .where(bands: { id: user_band_ids })
                          .where(performance_date: calendar_start..calendar_end)
                          .where.not(band_id: current_band&.id)
                          .includes(:band, :venue)
                          .order(:performance_date)
    
    # Get bandmate conflicts (other users in current band who have gigs with different bands)
    @bandmate_conflicts = if current_band
      # Get all users in current band except current user
      bandmate_ids = current_band.users.where.not(id: current_user.id).pluck(:id)
      
      # Get bands of those bandmates (excluding current band)
      bandmate_band_ids = UserBand.where(user_id: bandmate_ids)
                                 .where.not(band_id: current_band.id)
                                 .pluck(:band_id)
      
      # Get gigs from those bands for the full calendar range - simplified query
      if bandmate_band_ids.any?
        Gig.joins(:band)
           .where(bands: { id: bandmate_band_ids })
           .where(performance_date: calendar_start..calendar_end)
           .includes(:band)
           .order(:performance_date)
      else
        []
      end
    else
      []
    end
    
    # Get blackout dates for all users in current band for the full calendar range (if there is one)
    if current_band
      bandmate_ids = current_band.users.pluck(:id)
      @blackout_dates = BlackoutDate.where(user_id: bandmate_ids)
                                    .where(blackout_date: calendar_start..calendar_end)
                                    .includes(:user)
    else
      @blackout_dates = current_user.blackout_dates
                                    .where(blackout_date: calendar_start..calendar_end)
    end
    
    erb :calendar
  end

  # Blackout date management
  post '/blackout_dates' do
    require_login
    
    date_param = params[:date]
    reason = params[:reason]
    
    return { error: 'Date is required' }.to_json unless date_param
    
    begin
      # Clean and validate date parameter
      cleaned_date = date_param.to_s.strip
      return { error: 'Date is required' }.to_json if cleaned_date.empty?
      
      # Try multiple parsing approaches for robustness
      blackout_date = if cleaned_date.match?(/^\d{4}-\d{2}-\d{2}$/)
        Date.strptime(cleaned_date, '%Y-%m-%d')
      else
        Date.parse(cleaned_date)
      end
      
      # Check if blackout already exists for this user/date
      existing = current_user.blackout_dates.find_by(blackout_date: blackout_date)
      
      if existing
        content_type :json
        return { error: 'Blackout date already exists' }.to_json
      end
      
      # Create the blackout date
      blackout = current_user.blackout_dates.build(
        blackout_date: blackout_date,
        reason: reason
      )
      
      if blackout.save
        content_type :json
        { success: true, blackout_date: blackout_date.to_s, reason: reason }.to_json
      else
        content_type :json
        { error: blackout.errors.full_messages.join(', ') }.to_json
      end
      
    rescue Date::Error => e
      content_type :json
      { error: 'Invalid date format' }.to_json
    rescue ActiveRecord::RecordNotUnique => e
      content_type :json
      { error: 'Blackout date already exists' }.to_json
    rescue ActiveRecord::RecordInvalid => e
      content_type :json
      { error: e.record.errors.full_messages.join(', ') }.to_json
    rescue => e
      # Log the actual error for debugging
      content_type :json
      { error: 'Failed to create blackout date' }.to_json
    end
  end

  post '/blackout_dates/bulk' do
    require_login
    
    dates_param = params[:dates]
    reason = params[:reason]
    
    return { error: 'Dates are required' }.to_json unless dates_param
    
    begin
      date_strings = dates_param.split(',')
      created_count = 0
      errors = []
      
      date_strings.each do |date_str|
        begin
          # Clean and validate date string
          cleaned_date = date_str.strip
          next if cleaned_date.empty?
          
          # Try multiple parsing approaches for robustness
          blackout_date = if cleaned_date.match?(/^\d{4}-\d{2}-\d{2}$/)
            Date.strptime(cleaned_date, '%Y-%m-%d')
          else
            Date.parse(cleaned_date)
          end
          
          # Check if blackout already exists for this user/date
          existing = current_user.blackout_dates.find_by(blackout_date: blackout_date)
          
          unless existing
            blackout = current_user.blackout_dates.create(
              blackout_date: blackout_date,
              reason: reason
            )
            
            if blackout.persisted?
              created_count += 1
            else
              errors << "Failed to create blackout for #{date_str}: #{blackout.errors.full_messages.join(', ')}"
            end
          end
        rescue Date::Error => e
          errors << "Invalid date format for #{date_str}: #{e.message}"
          next
        end
      end
      
      content_type :json
      if errors.empty?
        { success: true, created_count: created_count, message: "Created #{created_count} blackout date#{created_count == 1 ? '' : 's'}" }.to_json
      else
        { success: false, created_count: created_count, errors: errors }.to_json
      end
      
    rescue => e
      # Log the actual error for debugging
      content_type :json
      { error: 'Failed to create blackout dates' }.to_json
    end
  end

  delete '/blackout_dates/bulk' do
    require_login
    
    dates_param = params[:dates]
    
    return { error: 'Dates are required' }.to_json unless dates_param
    
    begin
      date_strings = dates_param.split(',')
      deleted_count = 0
      
      date_strings.each do |date_str|
        begin
          # Clean and validate date string
          cleaned_date = date_str.strip
          next if cleaned_date.empty?
          
          # Try multiple parsing approaches for robustness
          blackout_date = if cleaned_date.match?(/^\d{4}-\d{2}-\d{2}$/)
            Date.strptime(cleaned_date, '%Y-%m-%d')
          else
            Date.parse(cleaned_date)
          end
          
          # Find and delete the blackout date for current user
          blackout = current_user.blackout_dates.find_by(blackout_date: blackout_date)
          
          if blackout
            blackout.destroy
            deleted_count += 1
          end
        rescue Date::Error => e
          # Skip invalid dates silently in bulk operations
          next
        end
      end
      
      content_type :json
      { success: true, deleted_count: deleted_count, message: "Removed #{deleted_count} blackout date#{deleted_count == 1 ? '' : 's'}" }.to_json
      
    rescue => e
      # Log the actual error for debugging
      content_type :json
      { error: 'Failed to remove blackout dates' }.to_json
    end
  end

  delete '/blackout_dates/:date' do
    require_login
    
    begin
      # Clean and validate date parameter
      date_param = params[:date].to_s.strip
      return { error: 'Date is required' }.to_json if date_param.empty?
      
      # Try multiple parsing approaches for robustness
      blackout_date = if date_param.match?(/^\d{4}-\d{2}-\d{2}$/)
        Date.strptime(date_param, '%Y-%m-%d')
      else
        Date.parse(date_param)
      end
      
      # Find and delete the blackout date for current user
      blackout = current_user.blackout_dates.find_by(blackout_date: blackout_date)
      
      if blackout
        blackout.destroy
        content_type :json
        { success: true, message: 'Blackout date removed' }.to_json
      else
        content_type :json
        { error: 'Blackout date not found' }.to_json
      end
      
    rescue Date::Error => e
      content_type :json
      { error: 'Invalid date format' }.to_json
    rescue => e
      # Log the actual error for debugging
      content_type :json
      { error: 'Failed to remove blackout date' }.to_json
    end
  end
end