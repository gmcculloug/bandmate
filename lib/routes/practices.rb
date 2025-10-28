require 'sinatra/base'

module Routes
end

class Routes::Practices < Sinatra::Base
  configure do
    set :views, File.join(File.dirname(__FILE__), '..', '..', 'views')
  end

  helpers ApplicationHelpers

  # ============================================================================
  # PRACTICE ROUTES
  # ============================================================================

  get '/practices' do
    require_login

    # If user has no bands, redirect to create or join a band
    if user_bands.empty?
      redirect '/bands/new?first_band=true'
    end

    # If no band is selected, redirect to band selection
    unless current_band
      redirect '/bands'
    end

    # Set breadcrumbs
    set_breadcrumbs(breadcrumb_for_section('practices'))

    @practices = current_band.practices.includes(:created_by_user)
    today = Date.current

    # Active practices: end_date (or calculated end date) is today or in the future
    @active_practices = @practices.where('COALESCE(end_date, week_start_date + INTERVAL \'6 days\') >= ?', today).order(week_start_date: :asc)

    # Count of archived practices for display
    @archived_practices_count = @practices.where('COALESCE(end_date, week_start_date + INTERVAL \'6 days\') < ?', today).count

    erb :practices
  end

  get '/practices/past' do
    require_login

    # If user has no bands, redirect to create or join a band
    if user_bands.empty?
      redirect '/bands/new?first_band=true'
    end

    # If no band is selected, redirect to band selection
    unless current_band
      redirect '/bands'
    end

    # Set breadcrumbs
    set_breadcrumbs(
      breadcrumb_for_section('practices'),
      { label: 'Past Practices', icon: '', url: nil }
    )

    @practices = current_band.practices.includes(:created_by_user)
    today = Date.current

    # Archived practices: end_date (or calculated end date) is in the past
    @archived_practices = @practices.where('COALESCE(end_date, week_start_date + INTERVAL \'6 days\') < ?', today).order(week_start_date: :asc)

    erb :past_practices
  end

  get '/practices/new' do
    require_login
    return redirect '/practices' unless current_band

    # Set breadcrumbs
    set_breadcrumbs(
      breadcrumb_for_section('practices'),
      { label: 'New', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="16"></line><line x1="8" y1="12" x2="16" y2="12"></line></svg>', url: nil }
    )

    @practice = Practice.new
    erb :new_practice
  end

  post '/practices' do
    require_login
    return redirect '/practices' unless current_band

    # Parse the start and end dates
    begin
      start_date = Date.parse(params[:week_start_date])
      end_date = Date.parse(params[:end_date])
    rescue Date::Error
      @error = "Invalid date format"
      return erb :new_practice
    end

    # Validate that end date is after start date
    if end_date < start_date
      @error = "End date must be after start date"
      return erb :new_practice
    end

    @practice = current_band.practices.new(
      week_start_date: start_date,
      end_date: end_date,
      title: params[:title],
      description: params[:description],
      created_by_user: current_user
    )

    if @practice.save
      redirect "/practices/#{@practice.id}"
    else
      @error = @practice.errors.full_messages.join(', ')
      erb :new_practice
    end
  end

  get '/practices/:id' do
    require_login
    return redirect '/practices' unless current_band

    @practice = current_band.practices.find_by(id: params[:id])
    return redirect '/practices' unless @practice

    # Set breadcrumbs
    breadcrumb_label = @practice.title.present? ? "#{@practice.title} #{@practice.formatted_week_range}" : "Practice #{@practice.formatted_week_range}"
    set_breadcrumbs(
      breadcrumb_for_section('practices'),
      { label: breadcrumb_label, url: nil }
    )

    @band_members = current_band.users.order(:username)
    @current_user_availabilities = @practice.practice_availabilities.where(user: current_user).index_by(&:day_of_week)
    @availability_summary = @practice.availability_summary
    @best_day = @practice.best_day

    erb :show_practice
  end


  post '/practices/:id/responses' do
    require_login
    return redirect '/practices' unless current_band

    @practice = current_band.practices.find_by(id: params[:id])
    return redirect '/practices' unless @practice

    # Clear all existing availability for this practice
    @practice.practice_availabilities.destroy_all

    # Process availability data for all users from the responses form
    current_band.users.each do |user|
      @practice.practice_dates.each_with_index do |date, day_index|
        availability_param = params["user_#{user.id}_day_#{day_index}"]

        # Skip if no availability is set or if it's empty
        next unless availability_param && !availability_param.empty?

        # Get notes data for this specific user
        notes_param = params["user_#{user.id}_notes_#{day_index}"]

        @practice.practice_availabilities.create!(
          user: user,
          day_of_week: day_index,
          availability: availability_param,
          notes: notes_param,
          suggested_start_time: nil,
          suggested_end_time: nil
        )
      end
    end

    redirect "/practices/#{@practice.id}"
  end

  post '/practices/:id/finalize' do
    require_login
    return redirect '/practices' unless current_band

    @practice = current_band.practices.find_by(id: params[:id])
    return redirect '/practices' unless @practice

    # Only the creator or band owner can finalize
    unless @practice.created_by_user == current_user || current_band.owned_by?(current_user)
      redirect "/practices/#{@practice.id}"
      return
    end

    @practice.update!(status: 'finalized')
    redirect "/practices/#{@practice.id}"
  end

  post '/practices/:id/reopen' do
    require_login
    return redirect '/practices' unless current_band

    @practice = current_band.practices.find_by(id: params[:id])
    return redirect '/practices' unless @practice

    # Only the creator or band owner can reopen
    unless @practice.created_by_user == current_user || current_band.owned_by?(current_user)
      redirect "/practices/#{@practice.id}"
      return
    end

    @practice.update!(status: 'active')
    redirect "/practices/#{@practice.id}"
  end

  delete '/practices/:id' do
    require_login
    return redirect '/practices' unless current_band

    @practice = current_band.practices.find_by(id: params[:id])
    return redirect '/practices' unless @practice

    # Only the creator or band owner can delete
    unless @practice.created_by_user == current_user || current_band.owned_by?(current_user)
      redirect "/practices/#{@practice.id}"
      return
    end

    @practice.destroy
    redirect '/practices'
  end
end