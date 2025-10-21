require 'sinatra/base'

module Routes
end

class Routes::Venues < Sinatra::Base
  configure do
    set :views, File.join(File.dirname(__FILE__), '..', '..', 'views')
  end
  
  helpers ApplicationHelpers
  
  # ============================================================================
  # VENUE ROUTES
  # ============================================================================

  get '/venues' do
    require_login
    return redirect '/gigs' unless current_band

    # Set breadcrumbs
    set_breadcrumbs(breadcrumb_for_section('venues'))

    @venues = filter_by_current_band(Venue).order(:name)
    erb :venues
  end

  get '/venues/new' do
    require_login
    return redirect '/gigs' unless current_band

    # Set breadcrumbs
    set_breadcrumbs(
      breadcrumb_for_section('venues'),
      { label: 'New', icon: '➕', url: nil }
    )

    erb :new_venue
  end

  post '/venues' do
    require_login
    return redirect '/gigs' unless current_band

    venue = Venue.new(params[:venue])
    venue.band = current_band

    if venue.save
      redirect '/venues'
    else
      @errors = venue.errors.full_messages

      # Set breadcrumbs for error case
      set_breadcrumbs(
        breadcrumb_for_section('venues'),
        { label: 'New', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="16"></line><line x1="8" y1="12" x2="16" y2="12"></line></svg>', url: nil }
      )

      erb :new_venue
    end
  end

  get '/venues/:id' do
    require_login
    return redirect '/gigs' unless current_band

    @venue = filter_by_current_band(Venue).find(params[:id])

    # Set breadcrumbs
    set_breadcrumbs(
      breadcrumb_for_section('venues'),
      { label: @venue.name, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M3 21h18"></path><path d="M5 21V7l8-4v18"></path><path d="M19 21V11l-6-4"></path></svg>', url: nil }
    )

    @bands = user_bands
    erb :show_venue
  end

  get '/venues/:id/edit' do
    require_login
    return redirect '/gigs' unless current_band

    @venue = filter_by_current_band(Venue).find(params[:id])

    # Set breadcrumbs
    set_breadcrumbs(
      breadcrumb_for_section('venues'),
      { label: @venue.name, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M3 21h18"></path><path d="M5 21V7l8-4v18"></path><path d="M19 21V11l-6-4"></path></svg>', url: "/venues/#{@venue.id}" },
      { label: 'Edit', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path></svg>', url: nil }
    )

    erb :edit_venue
  end

  put '/venues/:id' do
    require_login
    return redirect '/gigs' unless current_band

    @venue = filter_by_current_band(Venue).find(params[:id])

    if @venue.update(params[:venue])
      redirect "/venues/#{@venue.id}"
    else
      @errors = @venue.errors.full_messages

      # Set breadcrumbs for error case
      set_breadcrumbs(
        breadcrumb_for_section('venues'),
        { label: @venue.name, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M3 21h18"></path><path d="M5 21V7l8-4v18"></path><path d="M19 21V11l-6-4"></path></svg>', url: "/venues/#{@venue.id}" },
        { label: 'Edit', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path></svg>', url: nil }
      )

      erb :edit_venue
    end
  end

  delete '/venues/:id' do
    require_login
    return redirect '/gigs' unless current_band
    
    venue = filter_by_current_band(Venue).find(params[:id])
    
    venue.destroy
    
    redirect '/venues'
  end

  # ============================================================================
  # COPY VENUES TO BAND ROUTES
  # ============================================================================

  # Copy venues to band
  get '/bands/:band_id/copy_venues' do
    require_login
    @band = user_bands.find(params[:band_id])
    
    # Get venues from other bands the user is a member of
    other_band_ids = current_user.bands.where.not(id: @band.id).pluck(:id)
    @venues = Venue.where(band_id: other_band_ids).order(:name)
    
    # Exclude venues already copied to this band (by name and location to avoid exact duplicates)
    existing_venue_signatures = @band.venues.pluck(:name, :location).map { |name, location| "#{name} - #{location}" }
    @venues = @venues.reject do |venue|
      existing_venue_signatures.include?("#{venue.name} - #{venue.location}")
    end
    
    erb :copy_venues_to_band
  end

  post '/bands/:band_id/copy_venues' do
    require_login
    @band = user_bands.find(params[:band_id])
    venue_ids = params[:venue_ids] || []
    
    copied_count = 0
    venue_ids.each do |venue_id|
      source_venue = Venue.find(venue_id)
      
      # Verify user has access to the source venue through band membership
      if current_user.bands.include?(source_venue.band)
        new_venue = Venue.new(
          name: source_venue.name,
          location: source_venue.location,
          contact_name: source_venue.contact_name,
          phone_number: source_venue.phone_number,
          website: source_venue.website,
          notes: source_venue.notes,
          band: @band
        )
        
        if new_venue.save
          copied_count += 1
        end
      end
    end
    
    redirect "/bands/#{@band.id}?venues_copied=#{copied_count}"
  end

  # Copy single venue to band
  get '/venues/:venue_id/copy' do
    require_login
    return redirect '/gigs' unless current_band
    
    @venue = filter_by_current_band(Venue).find(params[:venue_id])
    
    # Get other bands the user is a member of
    @target_bands = current_user.bands.where.not(id: current_band.id).order(:name)
    
    # Filter out bands that already have a venue with the same name
    @target_bands = @target_bands.reject do |band|
      band.venues.where(name: @venue.name).exists?
    end
    
    erb :copy_venue_to_band
  end

  post '/venues/:venue_id/copy' do
    require_login
    return redirect '/gigs' unless current_band
    
    @venue = filter_by_current_band(Venue).find(params[:venue_id])
    
    target_band_id = params[:target_band_id]
    
    if target_band_id.blank?
      @error = "Please select a band to copy the venue to"
      @target_bands = current_user.bands.where.not(id: current_band.id).order(:name)
      @target_bands = @target_bands.reject do |band|
        band.venues.where(name: @venue.name).exists?
      end
      return erb :copy_venue_to_band
    end
    
    target_band = current_user.bands.find(target_band_id)
    
    # Check if target band already has a venue with the same name
    if target_band.venues.where(name: @venue.name).exists?
      @error = "#{target_band.name} already has a venue named '#{@venue.name}'"
      @target_bands = current_user.bands.where.not(id: current_band.id).order(:name)
      @target_bands = @target_bands.reject do |band|
        band.venues.where(name: @venue.name).exists?
      end
      return erb :copy_venue_to_band
    end
    
    # Copy the venue
    new_venue = Venue.new(
      name: @venue.name,
      location: @venue.location,
      contact_name: @venue.contact_name,
      phone_number: @venue.phone_number,
      website: @venue.website,
      notes: @venue.notes,
      band: target_band
    )
    
    if new_venue.save
      # If copying from a specific venue page, redirect back to that venue
      if params[:from_venue]
        redirect "/venues/#{@venue.id}?copied=1"
      else
        # Otherwise redirect to the venue page with the old format
        redirect "/venues/#{@venue.id}?copied_to=#{target_band.name}"
      end
    else
      @error = "Failed to copy venue: #{new_venue.errors.full_messages.join(', ')}"
      @target_bands = current_user.bands.where.not(id: current_band.id).order(:name)
      @target_bands = @target_bands.reject do |band|
        band.venues.where(name: @venue.name).exists?
      end
      erb :copy_venue_to_band
    end
  end
end