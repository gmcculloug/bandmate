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
      { label: 'New', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="16"></line><line x1="8" y1="12" x2="16" y2="12"></line></svg>', url: nil }
    )

    erb :new_song
  end

  # Copy from catalog routes - must come before /songs/:id
  get '/songs/copy_from_catalog' do
    require_login
    return redirect '/gigs' unless current_band

    # Set breadcrumbs
    set_breadcrumbs(
      breadcrumb_for_section('songs'),
      { label: 'Copy from Catalog', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg>', url: nil }
    )

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
      { label: 'Archived', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><polyline points="21,8 21,21 3,21 3,8"></polyline><rect x="1" y="3" width="22" height="5"></rect><line x1="10" y1="12" x2="14" y2="12"></line></svg>', url: nil }
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

    # Set breadcrumbs based on context
    if params[:from_gig]
      # Coming from a gig - use gig breadcrumbs
      @gig = filter_by_current_band(Gig).find(params[:from_gig])
      set_breadcrumbs(
        breadcrumb_for_section('gigs'),
        { label: @gig.name, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"></path><rect x="8" y="2" width="8" height="4" rx="1" ry="1"></rect></svg>', url: "/gigs/#{@gig.id}" },
        { label: @song.title, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M9 18V5l12-2v13"></path><circle cx="6" cy="18" r="3"></circle><circle cx="18" cy="16" r="3"></circle></svg>', url: nil }
      )
    else
      # Default song breadcrumbs
      set_breadcrumbs(
        breadcrumb_for_section('songs'),
        { label: @song.title, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M9 18V5l12-2v13"></path><circle cx="6" cy="18" r="3"></circle><circle cx="18" cy="16" r="3"></circle></svg>', url: nil }
      )
    end

    erb :show_song
  end

  get '/songs/:id/edit' do
    require_login
    @song = current_band.songs.find(params[:id])

    # Set breadcrumbs based on context
    if params[:from_gig]
      # Coming from a gig - use gig breadcrumbs
      @gig = filter_by_current_band(Gig).find(params[:from_gig])
      set_breadcrumbs(
        breadcrumb_for_section('gigs'),
        { label: @gig.name, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"></path><rect x="8" y="2" width="8" height="4" rx="1" ry="1"></rect></svg>', url: "/gigs/#{@gig.id}" },
        { label: @song.title, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M9 18V5l12-2v13"></path><circle cx="6" cy="18" r="3"></circle><circle cx="18" cy="16" r="3"></circle></svg>', url: "/songs/#{@song.id}?from_gig=#{@gig.id}" },
        { label: 'Edit', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path></svg>', url: nil }
      )
    else
      # Default song breadcrumbs
      set_breadcrumbs(
        breadcrumb_for_section('songs'),
        { label: @song.title, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M9 18V5l12-2v13"></path><circle cx="6" cy="18" r="3"></circle><circle cx="18" cy="16" r="3"></circle></svg>', url: "/songs/#{@song.id}" },
        { label: 'Edit', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path></svg>', url: nil }
      )
    end

    erb :edit_song
  end

  put '/songs/:id' do
    require_login
    @song = current_band.songs.find(params[:id])

    if @song.update(params[:song])
      # Preserve gig context on successful update
      if params[:from_gig]
        redirect "/songs/#{@song.id}?from_gig=#{params[:from_gig]}"
      else
        redirect "/songs/#{@song.id}"
      end
    else
      @errors = @song.errors.full_messages

      # Set breadcrumbs for error case (same as edit route)
      if params[:from_gig]
        @gig = filter_by_current_band(Gig).find(params[:from_gig])
        set_breadcrumbs(
          breadcrumb_for_section('gigs'),
          { label: @gig.name, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"></path><rect x="8" y="2" width="8" height="4" rx="1" ry="1"></rect></svg>', url: "/gigs/#{@gig.id}" },
          { label: @song.title, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M9 18V5l12-2v13"></path><circle cx="6" cy="18" r="3"></circle><circle cx="18" cy="16" r="3"></circle></svg>', url: "/songs/#{@song.id}?from_gig=#{@gig.id}" },
          { label: 'Edit', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path></svg>', url: nil }
        )
      else
        set_breadcrumbs(
          breadcrumb_for_section('songs'),
          { label: @song.title, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M9 18V5l12-2v13"></path><circle cx="6" cy="18" r="3"></circle><circle cx="18" cy="16" r="3"></circle></svg>', url: "/songs/#{@song.id}" },
          { label: 'Edit', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path></svg>', url: nil }
        )
      end

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

    # Set breadcrumbs
    set_breadcrumbs(
      breadcrumb_for_section('songs'),
      breadcrumb_for_section('song_catalogs')
    )

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

    # Set breadcrumbs
    set_breadcrumbs(
      breadcrumb_for_section('songs'),
      breadcrumb_for_section('song_catalogs')
    )

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

    # Set breadcrumbs
    set_breadcrumbs(
      breadcrumb_for_section('songs'),
      breadcrumb_for_section('song_catalogs'),
      { label: 'New', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="16"></line><line x1="8" y1="12" x2="16" y2="12"></line></svg>', url: nil }
    )

    erb :new_song_catalog
  end

  get '/song_catalogs/new' do
    require_login

    # Set breadcrumbs
    set_breadcrumbs(
      breadcrumb_for_section('songs'),
      breadcrumb_for_section('song_catalogs'),
      { label: 'New', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="16"></line><line x1="8" y1="12" x2="16" y2="12"></line></svg>', url: nil }
    )

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

    # Set breadcrumbs
    set_breadcrumbs(
      breadcrumb_for_section('songs'),
      breadcrumb_for_section('song_catalogs'),
      { label: @song_catalog.title, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M9 18V5l12-2v13"></path><circle cx="6" cy="18" r="3"></circle><circle cx="18" cy="16" r="3"></circle></svg>', url: nil }
    )

    @bands = user_bands
    erb :show_song_catalog
  end

  get '/song_catalogs/:id' do
    require_login
    @song_catalog = SongCatalog.find(params[:id])

    # Set breadcrumbs
    set_breadcrumbs(
      breadcrumb_for_section('songs'),
      breadcrumb_for_section('song_catalogs'),
      { label: @song_catalog.title, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M9 18V5l12-2v13"></path><circle cx="6" cy="18" r="3"></circle><circle cx="18" cy="16" r="3"></circle></svg>', url: nil }
    )

    @bands = user_bands
    erb :show_song_catalog
  end

  get '/song_catalog/:id/edit' do
    require_login
    @song_catalog = SongCatalog.find(params[:id])

    # Set breadcrumbs
    set_breadcrumbs(
      breadcrumb_for_section('songs'),
      breadcrumb_for_section('song_catalogs'),
      { label: @song_catalog.title, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M9 18V5l12-2v13"></path><circle cx="6" cy="18" r="3"></circle><circle cx="18" cy="16" r="3"></circle></svg>', url: "/song_catalogs/#{@song_catalog.id}" },
      { label: 'Edit', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path></svg>', url: nil }
    )

    erb :edit_song_catalog
  end

  get '/song_catalogs/:id/edit' do
    require_login
    @song_catalog = SongCatalog.find(params[:id])

    # Set breadcrumbs
    set_breadcrumbs(
      breadcrumb_for_section('songs'),
      breadcrumb_for_section('song_catalogs'),
      { label: @song_catalog.title, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M9 18V5l12-2v13"></path><circle cx="6" cy="18" r="3"></circle><circle cx="18" cy="16" r="3"></circle></svg>', url: "/song_catalogs/#{@song_catalog.id}" },
      { label: 'Edit', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path></svg>', url: nil }
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