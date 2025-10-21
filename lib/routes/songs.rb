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

    # Set breadcrumbs
    set_breadcrumbs(breadcrumb_for_section('songs'))

    @search = params[:search]

    @songs = filter_by_current_band(Song).active.order('LOWER(title)')

    # Apply search filter
    if @search.present?
      @songs = @songs.where('LOWER(title) LIKE ? OR LOWER(artist) LIKE ?', "%#{@search.downcase}%", "%#{@search.downcase}%")
    end

    erb :songs
  end

  get '/songs/new' do
    require_login
    return redirect '/gigs' unless current_band

    # Set breadcrumbs
    set_breadcrumbs(
      breadcrumb_for_section('songs'),
      { label: 'New', icon: '➕', url: nil }
    )

    erb :new_song
  end

  # Copy from catalog routes - must come before /songs/:id
  get '/songs/copy_from_catalog' do
    require_login
    return redirect '/gigs' unless current_band

    @search = params[:search]

    # Get all song catalogs not already in current band
    existing_song_catalog_ids = current_band.songs.where.not(song_catalog_id: nil).pluck(:song_catalog_id)
    @song_catalogs = SongCatalog.where.not(id: existing_song_catalog_ids).order('LOWER(title)')

    # Apply search filter
    if @search.present?
      @song_catalogs = @song_catalogs.search(@search)
    end

    # Get current band songs for the right column
    @band_songs = current_band.songs.order('LOWER(title)')

    erb :copy_from_song_catalogs
  end

  post '/songs/copy_from_catalog' do
    require_login
    return redirect '/gigs' unless current_band

    song_catalog_ids = params[:song_catalog_ids] || []

    copied_count = 0
    song_catalog_ids.each do |song_catalog_id|
      song_catalog = SongCatalog.find(song_catalog_id)

      # Check if song is already in this band
      existing_song = current_band.songs.find_by(song_catalog_id: song_catalog_id)
      next if existing_song

      song = Song.create_from_song_catalog(song_catalog, [current_band.id])

      if song.save
        copied_count += 1
      end
    end

    redirect "/songs?copied=#{copied_count}"
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

  # ============================================================================
  # SONG ARCHIVING ROUTES (must come before :id routes)
  # ============================================================================

  get '/songs/archived' do
    require_login
    return redirect '/gigs' unless current_band

    # Set breadcrumbs
    set_breadcrumbs(
      breadcrumb_for_section('songs'),
      { label: 'Archived', icon: '📦', url: nil }
    )

    @songs = filter_by_current_band(Song).archived.order('LOWER(title)')
    erb :archived_songs
  end

  post '/songs/:id/archive' do
    require_login
    return redirect '/gigs' unless current_band

    song = current_band.songs.find(params[:id])
    song.archive!

    redirect '/songs'
  end

  post '/songs/:id/unarchive' do
    require_login
    return redirect '/gigs' unless current_band

    song = current_band.songs.find(params[:id])
    song.unarchive!

    redirect '/songs'
  end

  get '/songs/:id' do
    require_login
    @song = current_band.songs.find(params[:id])

    # Set breadcrumbs
    set_breadcrumbs(
      breadcrumb_for_section('songs'),
      { label: @song.title, icon: '🎵', url: nil }
    )

    erb :show_song
  end

  get '/songs/:id/edit' do
    require_login
    @song = current_band.songs.find(params[:id])

    # Set breadcrumbs
    set_breadcrumbs(
      breadcrumb_for_section('songs'),
      { label: @song.title, icon: '🎵', url: "/songs/#{@song.id}" },
      { label: 'Edit', icon: '✏️', url: nil }
    )

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
  # SONG CATALOG ROUTES
  # ============================================================================

  get '/song_catalogs' do
    require_login

    @search = params[:search]
    @song_catalogs = SongCatalog.order('LOWER(title)')

    # Apply search filter
    if @search.present?
      @song_catalogs = @song_catalogs.search(@search)
    end

    erb :song_catalogs
  end

  get '/song_catalog' do
    require_login

    @search = params[:search]
    @song_catalogs = SongCatalog.order('LOWER(title)')

    # Apply search filter
    if @search.present?
      @song_catalogs = @song_catalogs.search(@search)
    end

    erb :song_catalog
  end

  get '/song_catalog/new' do
    require_login
    erb :new_song_catalog
  end

  get '/song_catalogs/new' do
    require_login
    erb :new_song_catalog
  end

  post '/song_catalog' do
    require_login
    song_catalog = SongCatalog.new(params[:song_catalog])

    if song_catalog.save
      redirect '/song_catalog'
    else
      @errors = song_catalog.errors.full_messages
      erb :new_song_catalog
    end
  end

  post '/song_catalogs' do
    require_login
    song_catalog = SongCatalog.new(params[:song_catalog])

    if song_catalog.save
      redirect '/song_catalogs'
    else
      @errors = song_catalog.errors.full_messages
      erb :new_song_catalog
    end
  end

  get '/song_catalog/:id' do
    require_login
    @song_catalog = SongCatalog.find(params[:id])
    @bands = user_bands
    erb :show_song_catalog
  end

  get '/song_catalogs/:id' do
    require_login
    @song_catalog = SongCatalog.find(params[:id])
    @bands = user_bands
    erb :show_song_catalog
  end

  get '/song_catalog/:id/edit' do
    require_login
    @song_catalog = SongCatalog.find(params[:id])
    erb :edit_song_catalog
  end

  get '/song_catalogs/:id/edit' do
    require_login
    @song_catalog = SongCatalog.find(params[:id])

    # Set breadcrumbs
    set_breadcrumbs(
      breadcrumb_for_section('song_catalogs'),
      { label: @song_catalog.title, icon: '🎵', url: "/song_catalogs/#{@song_catalog.id}" },
      { label: 'Edit', icon: '✏️', url: nil }
    )

    erb :edit_song_catalog
  end

  put '/song_catalog/:id' do
    require_login
    @song_catalog = SongCatalog.find(params[:id])

    if @song_catalog.update(params[:song_catalog])
      redirect "/song_catalog/#{@song_catalog.id}"
    else
      @errors = @song_catalog.errors.full_messages
      erb :edit_song_catalog
    end
  end

  put '/song_catalogs/:id' do
    require_login
    @song_catalog = SongCatalog.find(params[:id])

    if @song_catalog.update(params[:song_catalog])
      redirect "/song_catalogs/#{@song_catalog.id}"
    else
      @errors = @song_catalog.errors.full_messages
      erb :edit_song_catalog
    end
  end

  delete '/song_catalog/:id' do
    require_login
    song_catalog = SongCatalog.find(params[:id])
    song_catalog.destroy
    redirect '/song_catalog'
  end

  delete '/song_catalogs/:id' do
    require_login
    song_catalog = SongCatalog.find(params[:id])
    song_catalog.destroy
    redirect '/song_catalogs'
  end
end