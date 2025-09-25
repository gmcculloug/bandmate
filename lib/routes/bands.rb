require 'sinatra/base'

module Routes
end

class Routes::Bands < Sinatra::Base
  configure do
    set :views, File.join(File.dirname(__FILE__), '..', '..', 'views')
  end
  
  helpers ApplicationHelpers
  
  # ============================================================================
  # BAND ROUTES
  # ============================================================================

  get '/bands' do
    require_login
    @bands = user_bands.order(:name)
    erb :bands
  end

  get '/bands/new' do
    require_login
    erb :new_band
  end

  post '/bands' do
    require_login
    
    band = Band.new(params[:band])
    band.owner = current_user
    
    if band.save
      # Associate the current user with the new band
      current_user.bands << band
      
      # Set this as the current band if it's the user's first band
      if current_user.bands.count == 1
        session[:band_id] = band.id
        # Save this as the user's preferred band
        current_user.update(last_selected_band_id: band.id)
        redirect '/gigs'
      else
        redirect '/bands'
      end
    else
      @errors = band.errors.full_messages
      erb :new_band
    end
  end

  get '/bands/:id' do
    require_login
    @band = user_bands.find(params[:id])
    erb :show_band
  end

  get '/bands/:id/edit' do
    require_login
    @band = user_bands.find(params[:id])
    
    # Any band member can edit the band
    unless @band.users.include?(current_user)
      @errors = ["You must be a member of this band to edit it"]
      return erb :show_band
    end
    
    erb :edit_band
  end

  put '/bands/:id' do
    require_login
    @band = user_bands.find(params[:id])
    
    # Any band member can edit the band
    unless @band.users.include?(current_user)
      @errors = ["You must be a member of this band to edit it"]
      return erb :show_band
    end
    
    if @band.update(params[:band])
      redirect "/bands/#{@band.id}"
    else
      @errors = @band.errors.full_messages
      erb :edit_band
    end
  end

  delete '/bands/:id' do
    require_login
    band = user_bands.find(params[:id])
    
    # Only the owner can delete the band
    unless band.owned_by?(current_user)
      @errors = ["Only the band owner can delete this band"]
      return erb :show_band
    end
    
    # If this was the current band, clear the session
    if current_band&.id == band.id
      session[:band_id] = nil
    end
    
    # Remove all user associations with the band
    band.users.clear
    
    # Delete the band
    band.destroy
    
    redirect '/bands'
  end

  # ============================================================================
  # BAND USER MANAGEMENT ROUTES
  # ============================================================================

  post '/bands/:id/add_user' do
    require_login
    @band = user_bands.find(params[:id])
    
    # Any band member can add users
    unless @band.users.include?(current_user)
      @user_error = "You must be a member of this band to add new members"
      return erb :edit_band
    end
    
    username = params[:username]&.strip
    
    if username.blank?
      @user_error = "Username cannot be empty"
      return erb :edit_band
    end
    
    # Find user by username (case insensitive)
    user = User.where('LOWER(username) = ?', username.downcase).first
    
    if user.nil?
      @user_error = "User '#{username}' not found"
      return erb :edit_band
    end
    
    if @band.users.include?(user)
      @user_error = "User '#{username}' is already a member of this band"
      return erb :edit_band
    end
    
    # Add user to band
    @band.users << user
    @user_success = "Successfully added '#{username}' to the band"
    
    erb :edit_band
  end

  post '/bands/:id/remove_user' do
    require_login
    @band = user_bands.find(params[:id])
    user_to_remove = User.find(params[:user_id])
    
    # Any band member can remove other members, but users can always remove themselves
    if user_to_remove != current_user && !@band.users.include?(current_user)
      @user_error = "You must be a member of this band to remove other members"
      return erb :edit_band
    end
    
    # Prevent removing the band owner
    if user_to_remove == @band.owner
      @user_error = "Cannot remove the band owner. The owner must transfer ownership first."
      return erb :edit_band
    end
    
    # Prevent removing the last user from the band
    if @band.users.count <= 1
      @user_error = "Cannot remove the last member from the band"
      return erb :edit_band
    end
    
    if @band.users.include?(user_to_remove)
      @band.users.delete(user_to_remove)
      
      if user_to_remove == current_user
        # User is removing themselves - redirect to bands list with message
        redirect '/bands?left_band=true'
      else
        # Member removing another user - stay on edit page with success message
        @user_success = "Successfully removed '#{user_to_remove.username}' from the band"
        erb :edit_band
      end
    else
      @user_error = "User is not a member of this band"
      erb :edit_band
    end
  end

  post '/bands/:id/transfer_ownership' do
    require_login
    @band = user_bands.find(params[:id])
    new_owner = User.find(params[:new_owner_id])
    
    # Only the current owner can transfer ownership
    unless @band.owned_by?(current_user)
      @user_error = "Only the band owner can transfer ownership"
      return erb :edit_band
    end
    
    # New owner must be a member of the band
    unless @band.users.include?(new_owner)
      @user_error = "The new owner must be a member of this band"
      return erb :edit_band
    end
    
    # Cannot transfer ownership to yourself
    if new_owner == current_user
      @user_error = "You are already the owner of this band"
      return erb :edit_band
    end
    
    # Transfer ownership
    @band.update(owner: new_owner)
    @user_success = "Successfully transferred ownership to '#{new_owner.username}'"
    
    erb :edit_band
  end

  # ============================================================================
  # COPY SONGS TO BAND ROUTES
  # ============================================================================

  get '/bands/:band_id/copy_songs' do
    require_login
    @band = user_bands.find(params[:band_id])
    @search = params[:search]
    @song_catalogs = SongCatalog.order('LOWER(title)')

    # Apply search filter
    if @search.present?
      @song_catalogs = @song_catalogs.search(@search)
    end

    # Exclude songs already copied to this band based on song_catalog_id
    existing_song_catalog_ids = @band.songs.where.not(song_catalog_id: nil).pluck(:song_catalog_id)
    @song_catalogs = @song_catalogs.where.not(id: existing_song_catalog_ids)

    erb :copy_songs_to_band
  end

  post '/bands/:band_id/copy_songs' do
    require_login
    @band = user_bands.find(params[:band_id])
    song_catalog_ids = params[:song_catalog_ids] || []

    copied_count = 0
    song_catalog_ids.each do |song_catalog_id|
      song_catalog = SongCatalog.find(song_catalog_id)
      song = Song.create_from_global_song(song_catalog, [@band.id])

      if song.save
        copied_count += 1
      end
    end

    # If copying from a specific song catalog page, redirect back to that song
    if params[:from_song_catalog]
      redirect "/song_catalog/#{params[:from_song_catalog]}?copied=#{copied_count}"
    else
      # Otherwise redirect to the band page (bulk copy)
      redirect "/bands/#{@band.id}?copied=#{copied_count}"
    end
  end

  # ============================================================================
  # GOOGLE CALENDAR INTEGRATION ROUTES
  # ============================================================================

  post '/bands/:id/google_calendar_settings' do
    require_login
    @band = user_bands.find(params[:id])
    
    # Any band member can configure Google Calendar settings
    unless @band.users.include?(current_user)
      @google_calendar_error = "You must be a member of this band to configure Google Calendar settings"
      return erb :edit_band
    end
    
    # Update Google Calendar settings
    google_calendar_enabled = params[:google_calendar_enabled] == '1'
    google_calendar_id = params[:google_calendar_id]&.strip
    
    if google_calendar_enabled && google_calendar_id.blank?
      @google_calendar_error = "Calendar ID is required when Google Calendar sync is enabled"
      return erb :edit_band
    end
    
    @band.update!(
      google_calendar_enabled: google_calendar_enabled,
      google_calendar_id: google_calendar_id
    )
    
    @google_calendar_success = "Google Calendar settings updated successfully"
    erb :edit_band
  end

  post '/bands/:id/test_google_calendar' do
    require_login
    @band = user_bands.find(params[:id])
    
    unless @band.users.include?(current_user)
      content_type :json
      return { success: false, error: "You must be a member of this band" }.to_json
    end
    
    calendar_id = params[:google_calendar_id]&.strip
    
    if calendar_id.blank?
      content_type :json
      return { success: false, error: "Calendar ID is required" }.to_json
    end
    
    # Temporarily update the band's calendar ID for testing
    original_calendar_id = @band.google_calendar_id
    @band.update!(google_calendar_id: calendar_id, google_calendar_enabled: true)
    
    begin
      result = @band.test_google_calendar_connection
      
      # Restore original calendar ID if test failed
      if !result[:success]
        @band.update!(google_calendar_id: original_calendar_id)
      end
      
      content_type :json
      result.to_json
    rescue => e
      # Restore original calendar ID on error
      @band.update!(google_calendar_id: original_calendar_id)
      
      content_type :json
      { success: false, error: e.message }.to_json
    end
  end

  post '/bands/:id/sync_google_calendar' do
    require_login
    @band = user_bands.find(params[:id])
    
    unless @band.users.include?(current_user)
      content_type :json
      return { success: false, error: "You must be a member of this band" }.to_json
    end
    
    unless @band.google_calendar_enabled?
      content_type :json
      return { success: false, error: "Google Calendar sync is not enabled for this band" }.to_json
    end
    
    begin
      result = @band.sync_all_gigs_to_google_calendar

      content_type :json
      result.to_json
    rescue => e
      content_type :json
      { success: false, error: e.message, synced_count: 0, total_count: 0 }.to_json
    end
  end
end