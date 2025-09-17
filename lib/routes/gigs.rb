require 'sinatra/base'

module Routes
end

class Routes::Gigs < Sinatra::Base
  configure do
    set :views, File.join(File.dirname(__FILE__), '..', '..', 'views')
  end
  
  helpers ApplicationHelpers
  
  # ============================================================================
  # GIG ROUTES
  # ============================================================================

  get '/gigs' do
    require_login
    
    # If user has no bands, redirect to create or join a band
    if user_bands.empty?
      redirect '/bands/new?first_band=true'
    end
    
    # If no band is selected, redirect to band selection
    unless current_band
      redirect '/bands'
    end
    
    all_gigs = filter_by_current_band(Gig).includes(:venue)
    today = Date.current
    @upcoming_gigs = all_gigs.where('performance_date >= ?', today).order(:performance_date) || []
    @past_gigs = all_gigs.where('performance_date < ?', today).order(performance_date: :desc) || []
    erb :gigs
  end

  get '/gigs/new' do
    require_login
    return redirect '/gigs' unless current_band
    
    @venues = filter_by_current_band(Venue).order(:name)
    @songs = filter_by_current_band(Song).order(:title)
    erb :new_gig
  end

  post '/gigs' do
    require_login
    return redirect '/gigs' unless current_band
    
    gig_params = {
      name: params[:name], 
      band_id: current_band.id,
      venue_id: params[:venue_id].presence,
      performance_date: params[:performance_date],
      start_time: params[:start_time].presence,
      end_time: params[:end_time].presence
    }
    
    gig = Gig.new(gig_params)
    if gig.save
      # Sync to Google Calendar if enabled
      current_band.sync_gig_to_google_calendar(gig) if current_band.google_calendar_enabled?
      redirect "/gigs/#{gig.id}"
    else
      @errors = gig.errors.full_messages
      @venues = filter_by_current_band(Venue).order(:name)
      @songs = filter_by_current_band(Song).order(:title)
      erb :new_gig
    end
  end

  get '/gigs/:id' do
    require_login
    @gig = filter_by_current_band(Gig).includes(:venue).find(params[:id])
    
    @available_songs = filter_by_current_band(Song).where.not(id: @gig.song_ids).order(:title)
    erb :show_gig
  end

  get '/gigs/:id/edit' do
    require_login
    @gig = filter_by_current_band(Gig).find(params[:id])
    
    @venues = filter_by_current_band(Venue).order(:name)
    erb :edit_gig
  end

  get '/gigs/:id/manage_songs' do
    require_login
    @gig = filter_by_current_band(Gig).find(params[:id])
    
    # Get all songs for the current band
    @all_band_songs = filter_by_current_band(Song).order(:title)
    
    # Get songs currently available (not in this gig)
    @available_songs = @all_band_songs.where.not(id: @gig.song_ids)
    
    # Get songs already in this gig, organized by set number
    @gig_songs_by_set = @gig.gig_songs.includes(:song).order(:set_number, :position).group_by(&:set_number) || {}
    
    # Prepare JSON data for JavaScript
    @all_band_songs_json = @all_band_songs.map { |song| 
      {
        id: song.id.to_s,
        title: song.title,
        artist: song.artist || "",
        key: song.key || "",
        duration: song.duration || ""
      }
    }.to_json
    
    @sets_songs_json = @gig_songs_by_set.transform_values { |gig_songs|
      gig_songs.map { |gig_song|
        {
          id: gig_song.song.id.to_s,
          title: gig_song.song.title,
          artist: gig_song.song.artist || "",
          key: gig_song.song.key || "",
          duration: gig_song.song.duration || ""
        }
      }
    }.to_json
    
    erb :manage_gig_songs
  end

  put '/gigs/:id' do
    require_login
    @gig = filter_by_current_band(Gig).find(params[:id])
    
    gig_params = {
      name: params[:name], 
      notes: params[:notes],
      band_id: current_band.id,
      venue_id: params[:venue_id].presence,
      performance_date: params[:performance_date],
      start_time: params[:start_time].presence,
      end_time: params[:end_time].presence
    }
    
    if @gig.update(gig_params)
      # Sync to Google Calendar if enabled
      current_band.sync_gig_to_google_calendar(@gig) if current_band.google_calendar_enabled?
      redirect "/gigs/#{@gig.id}"
    else
      @errors = @gig.errors.full_messages
      @venues = filter_by_current_band(Venue).order(:name)
      erb :edit_gig
    end
  end

  delete '/gigs/:id' do
    require_login
    gig = filter_by_current_band(Gig).find(params[:id])
    
    # Remove from Google Calendar if enabled
    current_band.remove_gig_from_google_calendar(gig) if current_band.google_calendar_enabled?
    
    gig.destroy
    redirect '/gigs'
  end

  # ============================================================================
  # GIG SONG MANAGEMENT ROUTES
  # ============================================================================

  post '/gigs/:id/songs' do
    require_login
    gig = filter_by_current_band(Gig).find(params[:id])
    
    song = filter_by_current_band(Song).find(params[:song_id])
    set_number = params[:set_number] || 1
    position = gig.gig_songs.where(set_number: set_number).count + 1
    
    gig_song = GigSong.new(
      gig: gig,
      song: song,
      position: position,
      set_number: set_number
    )
    
    if gig_song.save
      redirect "/gigs/#{gig.id}"
    else
      @errors = gig_song.errors.full_messages
      @gig = gig
      erb :show_gig
    end
  end

  delete '/gigs/:gig_id/songs/:song_id' do
    require_login
    gig = filter_by_current_band(Gig).find(params[:gig_id])
    
    gig_song = gig.gig_songs.find_by(song_id: params[:song_id])
    gig_song.destroy if gig_song
    
    # Reorder remaining songs
    gig.gig_songs.order(:position).each_with_index do |sls, index|
      sls.update(position: index + 1)
    end
    
    redirect "/gigs/#{gig.id}"
  end

  post '/gigs/:id/reorder' do
    require_login
    gig = filter_by_current_band(Gig).find(params[:id])
    song_order = params[:song_order]
    
    if song_order && song_order.is_a?(Array)
      song_order.each_with_index do |song_id, index|
        gig_song = gig.gig_songs.find_by(song_id: song_id)
        gig_song.update(position: index + 1) if gig_song
      end
    end
    
    content_type :json
    { success: true }.to_json
  end

  post '/gigs/:id/update_songs' do
    require_login
    gig = filter_by_current_band(Gig).find(params[:id])
    
    # Clear existing songs
    gig.gig_songs.destroy_all
    
    # Process each set
    sets_data = params[:sets] || {}
    sets_data.each do |set_number, songs|
      songs.each_with_index do |song_id, position|
        next if song_id.blank?
        
        song = filter_by_current_band(Song).find(song_id)
        GigSong.create!(
          gig: gig,
          song: song,
          set_number: set_number.to_i,
          position: position + 1
        )
      end
    end
    
    content_type :json
    { success: true }.to_json
  end

  # ============================================================================
  # GIG UTILITY ROUTES
  # ============================================================================

  get '/gigs/:id/print' do
    require_login
    @gig = filter_by_current_band(Gig).find(params[:id])
    
    erb :print_gig, layout: false
  end

  post '/gigs/:id/copy' do
    require_login
    begin
      original_gig = filter_by_current_band(Gig).find(params[:id])
      
      # Create new set list with copied name and notes
      new_name = "Copy - #{original_gig.name}"
      new_gig = Gig.create!(
        name: new_name,
        notes: original_gig.notes,
        band: original_gig.band,
        performance_date: original_gig.performance_date || Date.current
      )
      
      # Copy all songs with their positions
      original_gig.gig_songs.includes(:song).order(:set_number, :position).each do |gig_song|
        GigSong.create!(
          gig_id: new_gig.id,
          song_id: gig_song.song_id,
          position: gig_song.position,
          set_number: gig_song.set_number
        )
      end
      
      redirect "/gigs/#{new_gig.id}"
    rescue => e
      # If something goes wrong, redirect back with an error
      redirect "/gigs/#{params[:id]}?error=copy_failed"
    end
  end
end