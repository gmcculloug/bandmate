require 'sinatra/base'

module Routes
end

class Routes::Songs < Sinatra::Base
  configure do
    set :views, File.join(File.dirname(__FILE__), '..', '..', 'views')
  end
  
  helpers ApplicationHelpers
  
  # ============================================================================
  # SONG ROUTES
  # ============================================================================

  get '/songs' do
    require_login
    return redirect '/gigs' unless current_band
    
    @search = params[:search]
    
    @songs = filter_by_current_band(Song).order('LOWER(title)')
    
    # Apply search filter
    if @search.present?
      @songs = @songs.where('LOWER(title) LIKE ? OR LOWER(artist) LIKE ?', "%#{@search.downcase}%", "%#{@search.downcase}%")
    end
    
    erb :songs
  end

  get '/songs/new' do
    require_login
    return redirect '/gigs' unless current_band
    erb :new_song
  end

  post '/songs' do
    require_login
    return redirect '/gigs' unless current_band
    
    song = Song.new(params[:song])
    # If band_ids provided, associate accordingly but ensure current_band is included by default
    provided_band_ids = params.dig(:song, :band_ids)
    if provided_band_ids.is_a?(Array) && provided_band_ids.any?
      # Filter to bands the current user is a member of
      allowed_band_ids = current_user.bands.where(id: provided_band_ids).pluck(:id)
      song.band_ids = (allowed_band_ids + [current_band.id]).uniq
    else
      song.bands = [current_band]
    end
    
    if song.save
      redirect '/songs'
    else
      @errors = song.errors.full_messages
      erb :new_song
    end
  end

  get '/songs/:id' do
    require_login
    @song = current_band.songs.find(params[:id])
    
    erb :show_song
  end

  get '/songs/:id/edit' do
    require_login
    @song = current_band.songs.find(params[:id])
    
    erb :edit_song
  end

  put '/songs/:id' do
    require_login
    @song = current_band.songs.find(params[:id])
    
    if @song.update(params[:song])
      redirect "/songs/#{@song.id}"
    else
      @errors = @song.errors.full_messages
      erb :edit_song
    end
  end

  delete '/songs/:id' do
    require_login
    song = current_band.songs.find(params[:id])
    
    # Clean up associations before deleting the song
    song.gig_songs.destroy_all
    
    # Remove the song from all bands (many-to-many relationship)
    song.band_ids = []
    
    song.destroy
    
    redirect '/songs'
  end

  # ============================================================================
  # COPY SONGS FROM GLOBAL LIST ROUTES
  # ============================================================================

  get '/songs/copy_from_global' do
    require_login
    return redirect '/gigs' unless current_band
    
    @search = params[:search]
    
    # Get all global songs not already in current band
    existing_global_song_ids = current_band.songs.where.not(global_song_id: nil).pluck(:global_song_id)
    @global_songs = GlobalSong.where.not(id: existing_global_song_ids).order('LOWER(title)')
    
    # Apply search filter
    if @search.present?
      @global_songs = @global_songs.search(@search)
    end
    
    # Get current band songs for the right column
    @band_songs = current_band.songs.order('LOWER(title)')
    
    erb :copy_from_global_songs
  end

  post '/songs/copy_from_global' do
    require_login
    return redirect '/gigs' unless current_band
    
    global_song_ids = params[:global_song_ids] || []
    
    copied_count = 0
    global_song_ids.each do |global_song_id|
      global_song = GlobalSong.find(global_song_id)
      
      # Check if song is already in this band
      existing_song = current_band.songs.find_by(global_song_id: global_song_id)
      next if existing_song
      
      song = Song.create_from_global_song(global_song, [current_band.id])
      
      if song.save
        copied_count += 1
      end
    end
    
    redirect "/songs?copied=#{copied_count}"
  end

  # ============================================================================
  # GLOBAL SONG ROUTES
  # ============================================================================

  get '/global_songs' do
    require_login
    
    @search = params[:search]
    @global_songs = GlobalSong.order('LOWER(title)')
    
    # Apply search filter
    if @search.present?
      @global_songs = @global_songs.search(@search)
    end
    
    erb :global_songs
  end

  get '/global_songs/new' do
    require_login
    erb :new_global_song
  end

  post '/global_songs' do
    require_login
    global_song = GlobalSong.new(params[:global_song])
    
    if global_song.save
      redirect '/global_songs'
    else
      @errors = global_song.errors.full_messages
      erb :new_global_song
    end
  end

  get '/global_songs/:id' do
    require_login
    @global_song = GlobalSong.find(params[:id])
    @bands = user_bands
    erb :show_global_song
  end

  get '/global_songs/:id/edit' do
    require_login
    @global_song = GlobalSong.find(params[:id])
    erb :edit_global_song
  end

  put '/global_songs/:id' do
    require_login
    @global_song = GlobalSong.find(params[:id])
    
    if @global_song.update(params[:global_song])
      redirect "/global_songs/#{@global_song.id}"
    else
      @errors = @global_song.errors.full_messages
      erb :edit_global_song
    end
  end

  delete '/global_songs/:id' do
    require_login
    global_song = GlobalSong.find(params[:id])
    global_song.destroy
    redirect '/global_songs'
  end
end