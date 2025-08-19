require 'sinatra'
require 'sinatra/activerecord'
require 'json'
require 'erb'
require 'bcrypt'
require 'rack/method_override'

enable :sessions
use Rack::MethodOverride
set :session_secret, ENV['SESSION_SECRET'] || 'your_secret_key_here_that_is_very_long_and_secure_at_least_64_chars'

# Account creation code for user registration (required)
# Set BANDMATE_ACCT_CREATION_SECRET environment variable to enable account creation

# Database configuration
configure :development do
  set :database, { adapter: 'sqlite3', database: 'bandmate.db' }
end

configure :production do
  database_path = ENV['DATABASE_PATH'] || 'bandmate.db'
  set :database, { adapter: 'sqlite3', database: database_path }
end

configure :test do
  set :database, { adapter: 'sqlite3', database: 'bandmate_test.db' }
  set :bind, '0.0.0.0'
  set :port, 4567
  set :protection, false
  set :environment, :test
  set :dump_errors, false
  set :raise_errors, true
  set :show_exceptions, false
end

# Models
class User < ActiveRecord::Base
  has_secure_password
  has_many :user_bands
  has_many :bands, through: :user_bands
  belongs_to :last_selected_band, class_name: 'Band', optional: true
  
  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 6 }, if: :password_digest_changed?
  validates :email, uniqueness: { case_sensitive: false }, allow_blank: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
end

class UserBand < ActiveRecord::Base
  belongs_to :user
  belongs_to :band
end

class Band < ActiveRecord::Base
  belongs_to :owner, class_name: 'User', optional: true
  has_and_belongs_to_many :songs
  has_many :set_lists
  has_many :venues
  has_many :user_bands
  has_many :users, through: :user_bands
  
  validates :name, presence: true
  validates :name, uniqueness: true
  
  def owner?
    owner.present?
  end
  
  def owned_by?(user)
    owner == user
  end
end

class GlobalSong < ActiveRecord::Base
  has_many :songs
  
  validates :title, presence: true
  validates :artist, presence: true
  validates :key, presence: true
  validates :tempo, numericality: { greater_than: 0 }, allow_nil: true
  
  # Scope for searching global songs
  scope :search, ->(query) { 
    where('LOWER(title) LIKE ? OR LOWER(artist) LIKE ?', "%#{query.downcase}%", "%#{query.downcase}%") if query.present?
  }
end

class Song < ActiveRecord::Base
  belongs_to :global_song, optional: true
  has_and_belongs_to_many :bands
  has_many :set_list_songs
  has_many :set_lists, through: :set_list_songs
  
  validates :title, presence: true
  validates :artist, presence: true
  validates :key, presence: true
  validates :tempo, numericality: { greater_than: 0 }, allow_nil: true
  
  # Create a band-specific copy of a global song
  def self.create_from_global_song(global_song, band_ids = [])
    song = new(
      title: global_song.title,
      artist: global_song.artist,
      key: global_song.key,
      original_key: global_song.original_key,
      tempo: global_song.tempo,
      genre: global_song.genre,
      url: global_song.url,
      notes: global_song.notes,
      duration: global_song.duration,
      year: global_song.year,
      album: global_song.album,
      lyrics: global_song.lyrics,
      global_song: global_song
    )
    song.band_ids = band_ids
    song
  end
end

class Venue < ActiveRecord::Base
  belongs_to :band, optional: true
  has_many :set_lists
  
  validates :name, presence: true
  validates :location, presence: true
  validates :contact_name, presence: true
  validates :phone_number, presence: true
end

class SetList < ActiveRecord::Base
  belongs_to :band
  belongs_to :venue, optional: true
  has_many :set_list_songs, dependent: :destroy
  has_many :songs, through: :set_list_songs
  
  validates :name, presence: true
  validates :band, presence: true
  validates :performance_date, presence: true
end

class SetListSong < ActiveRecord::Base
  belongs_to :set_list
  belongs_to :song
  
  validates :position, presence: true, numericality: { greater_than: 0 }
end

# Authentication helpers
helpers do
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
    when 'SetList'
      collection.where(band: current_band)
    when 'Venue'
      collection.where(band: current_band)
    else
      collection
    end
  end
end

# Test authentication route (only available in test mode)
if settings.test?
  post '/test_login' do
    user = User.find(params[:user_id])
    band = params[:band_id] ? Band.find(params[:band_id]) : nil
    
    session[:user_id] = user.id
    session[:band_id] = band.id if band
    
    content_type :json
    { success: true, user_id: user.id, band_id: band&.id }.to_json
  end
end

# Authentication routes
get '/login' do
  erb :login, layout: :layout
end

post '/login' do
  user = User.where('LOWER(username) = ?', params[:username].downcase).first
  
  if user && user.authenticate(params[:password])
    session[:user_id] = user.id
    
    # Restore the last selected band if it exists and user still has access to it
    if user.last_selected_band && user.bands.include?(user.last_selected_band)
      session[:band_id] = user.last_selected_band.id
    elsif user.bands.any?
      # If no saved band or user no longer has access, select the first band
      session[:band_id] = user.bands.first.id
    end
    
    redirect '/set_lists'
  else
    @error = "Invalid username or password"
    erb :login, layout: :layout
  end
end

get '/signup' do
  erb :signup, layout: :layout
end

post '/signup' do
  # Validate account creation code
  login_secret = ENV['BANDMATE_ACCT_CREATION_SECRET']
  if login_secret.nil? || login_secret.empty?
    @errors = ["Account creation code not configured. Please contact administrator."]
    return erb :signup, layout: :layout
  end
  
  if params[:login_secret] != login_secret
    @errors = ["Invalid account creation code. Please check your code and try again."]
    return erb :signup, layout: :layout
  end
  
  user = User.new(username: params[:username], password: params[:password], email: params[:email].presence)
  
  if user.save
    session[:user_id] = user.id
    redirect '/set_lists'
  else
    @errors = user.errors.full_messages
    erb :signup, layout: :layout
  end
end

get '/logout' do
  # Save the current band selection before clearing session
  if logged_in? && current_band
    current_user.update(last_selected_band_id: current_band.id)
  end
  
  session.clear
  redirect '/login'
end

# Account deletion
get '/account/delete' do
  require_login
  erb :delete_account
end

post '/account/delete' do
  require_login
  
  # Verify password for security
  unless current_user.authenticate(params[:password])
    @errors = ["Incorrect password. Please try again."]
    return erb :delete_account
  end
  
  user = current_user
  
  begin
    # Clear session first
    session.clear
    
    # Remove user from all bands first
    user.user_bands.destroy_all
    
    # Clear last selected band reference
    user.update(last_selected_band_id: nil)
    
    # Delete the user
    user.destroy
    
    redirect '/login?account_deleted=true'
  rescue => e
    # If something goes wrong, restore the session
    session[:user_id] = user.id
    @errors = ["Failed to delete account. Please try again or contact support."]
    erb :delete_account
  end
end

# User profile routes
get '/profile' do
  require_login
  erb :profile
end

put '/profile' do
  require_login
  
  user = current_user
  
  # Update user attributes
  if user.update(params[:user])
    @success = "Profile updated successfully!"
    erb :profile
  else
    @errors = user.errors.full_messages
    erb :profile
  end
end

post '/profile/change_password' do
  require_login
  
  user = current_user
  
  # Verify current password
  unless user.authenticate(params[:current_password])
    @errors = ["Current password is incorrect"]
    return erb :profile
  end
  
  # Update password
  if params[:new_password] == params[:confirm_password]
    if user.update(password: params[:new_password])
      @success = "Password changed successfully!"
    else
      @errors = user.errors.full_messages
    end
  else
    @errors = ["New passwords don't match"]
  end
  
  erb :profile
end

post '/select_band' do
  require_login
  band = current_user.bands.find_by(id: params[:band_id])
  if band
    session[:band_id] = band.id
    # Save this as the user's preferred band
    current_user.update(last_selected_band_id: band.id)
  end
  redirect back
end

# Routes
get '/' do
  require_login
  
  # If user has no bands, redirect to create or join a band
  if user_bands.empty?
    redirect '/bands/new?first_band=true'
  end
  
  # Redirect to set lists as the main screen
  redirect '/set_lists'
end

# Songs routes
get '/songs' do
  require_login
  return redirect '/set_lists' unless current_band
  
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
  return redirect '/set_lists' unless current_band
  erb :new_song
end

post '/songs' do
  require_login
  return redirect '/set_lists' unless current_band
  
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
  @song = current_band.songs.find_by(id: params[:id])
  
  unless @song
    redirect '/songs'
  end
  
  erb :show_song
end

get '/songs/:id/edit' do
  require_login
  @song = current_band.songs.find_by(id: params[:id])
  
  unless @song
    redirect '/songs'
  end
  
  erb :edit_song
end

put '/songs/:id' do
  require_login
  @song = current_band.songs.find_by(id: params[:id])
  
  unless @song
    redirect '/songs'
  end
  
  if @song.update(params[:song])
    redirect "/songs/#{@song.id}"
  else
    @errors = @song.errors.full_messages
    erb :edit_song
  end
end

delete '/songs/:id' do
  require_login
  song = current_band.songs.find_by(id: params[:id])
  
  if song
    # Clean up associations before deleting the song
    song.set_list_songs.destroy_all
    
    # Remove the song from all bands (many-to-many relationship)
    song.band_ids = []
    
    song.destroy
  end
  
  redirect '/songs'
end

# Global songs routes
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

# Copy global song to band
get '/bands/:band_id/copy_songs' do
  require_login
  @band = user_bands.find(params[:band_id])
  @search = params[:search]
  @global_songs = GlobalSong.order('LOWER(title)')
  
  # Apply search filter
  if @search.present?
    @global_songs = @global_songs.search(@search)
  end
  
  # Exclude songs already copied to this band based on global_song_id
  existing_global_song_ids = @band.songs.where.not(global_song_id: nil).pluck(:global_song_id)
  @global_songs = @global_songs.where.not(id: existing_global_song_ids)
  
  erb :copy_songs_to_band
end

post '/bands/:band_id/copy_songs' do
  require_login
  @band = user_bands.find(params[:band_id])
  global_song_ids = params[:global_song_ids] || []
  
  copied_count = 0
  global_song_ids.each do |global_song_id|
    global_song = GlobalSong.find(global_song_id)
    song = Song.create_from_global_song(global_song, [@band.id])
    
    if song.save
      copied_count += 1
    end
  end
  
  # If copying from a specific global song page, redirect back to that song
  if params[:from_global_song]
    redirect "/global_songs/#{params[:from_global_song]}?copied=#{copied_count}"
  else
    # Otherwise redirect to the band page (bulk copy)
    redirect "/bands/#{@band.id}?copied=#{copied_count}"
  end
end

# Set lists routes
get '/set_lists' do
  require_login
  
  # If user has no bands, redirect to create or join a band
  if user_bands.empty?
    redirect '/bands/new?first_band=true'
  end
  
  # If no band is selected, redirect to band selection
  unless current_band
    redirect '/bands'
  end
  
  @set_lists = filter_by_current_band(SetList).includes(:venue).order(:performance_date)
  erb :set_lists
end

get '/set_lists/new' do
  require_login
  return redirect '/set_lists' unless current_band
  
  @venues = filter_by_current_band(Venue).order(:name)
  @songs = filter_by_current_band(Song).order(:title)
  erb :new_set_list
end

post '/set_lists' do
  require_login
  return redirect '/set_lists' unless current_band
  
  set_list_params = {
    name: params[:name], 
    band_id: current_band.id,
    venue_id: params[:venue_id].presence,
    performance_date: params[:performance_date],
    start_time: params[:start_time].presence,
    end_time: params[:end_time].presence
  }
  
  set_list = SetList.new(set_list_params)
  if set_list.save
    redirect '/set_lists'
  else
    @errors = set_list.errors.full_messages
    @venues = filter_by_current_band(Venue).order(:name)
    @songs = filter_by_current_band(Song).order(:title)
    erb :new_set_list
  end
end

get '/set_lists/:id' do
  require_login
  @set_list = filter_by_current_band(SetList).includes(:venue).find_by(id: params[:id])
  
  unless @set_list
    redirect '/set_lists'
  end
  
  @available_songs = filter_by_current_band(Song).where.not(id: @set_list.song_ids).order(:title)
  erb :show_set_list
end

get '/set_lists/:id/edit' do
  require_login
  @set_list = filter_by_current_band(SetList).find_by(id: params[:id])
  
  unless @set_list
    redirect '/set_lists'
  end
  
  @venues = filter_by_current_band(Venue).order(:name)
  erb :edit_set_list
end

put '/set_lists/:id' do
  require_login
  @set_list = filter_by_current_band(SetList).find_by(id: params[:id])
  
  unless @set_list
    redirect '/set_lists'
  end
  set_list_params = {
    name: params[:name], 
    notes: params[:notes],
    band_id: current_band.id,
    venue_id: params[:venue_id].presence,
    performance_date: params[:performance_date],
    start_time: params[:start_time].presence,
    end_time: params[:end_time].presence
  }
  
  if @set_list.update(set_list_params)
    redirect "/set_lists/#{@set_list.id}"
  else
    @errors = @set_list.errors.full_messages
    @venues = filter_by_current_band(Venue).order(:name)
    erb :edit_set_list
  end
end

delete '/set_lists/:id' do
  require_login
  set_list = filter_by_current_band(SetList).find_by(id: params[:id])
  
  if set_list
    set_list.destroy
  end
  
  redirect '/set_lists'
end

# Add song to set list
post '/set_lists/:id/songs' do
  require_login
  set_list = filter_by_current_band(SetList).find_by(id: params[:id])
  
  unless set_list
    redirect '/set_lists'
  end
  song = filter_by_current_band(Song).find_by(id: params[:song_id])
  
  unless song
    redirect '/set_lists'
  end
  position = set_list.set_list_songs.count + 1
  
  set_list_song = SetListSong.new(
    set_list: set_list,
    song: song,
    position: position
  )
  
  if set_list_song.save
    redirect "/set_lists/#{set_list.id}"
  else
    @errors = set_list_song.errors.full_messages
    @set_list = set_list
    erb :show_set_list
  end
end

# Remove song from set list
delete '/set_lists/:set_list_id/songs/:song_id' do
  require_login
  set_list = filter_by_current_band(SetList).find_by(id: params[:set_list_id])
  
  unless set_list
    redirect '/set_lists'
  end
  set_list_song = set_list.set_list_songs.find_by(song_id: params[:song_id])
  set_list_song.destroy if set_list_song
  
  # Reorder remaining songs
  set_list.set_list_songs.order(:position).each_with_index do |sls, index|
    sls.update(position: index + 1)
  end
  
  redirect "/set_lists/#{set_list.id}"
end

# Print set list
get '/set_lists/:id/print' do
  require_login
  @set_list = filter_by_current_band(SetList).find_by(id: params[:id])
  
  unless @set_list
    redirect '/set_lists'
  end
  erb :print_set_list, layout: false
end

# Reorder songs in set list
post '/set_lists/:id/reorder' do
  require_login
  set_list = filter_by_current_band(SetList).find_by(id: params[:id])
  
  unless set_list
    content_type :json
    return { success: false, error: "Set list not found" }.to_json
  end
  song_order = params[:song_order]
  
  if song_order && song_order.is_a?(Array)
    song_order.each_with_index do |song_id, index|
      set_list_song = set_list.set_list_songs.find_by(song_id: song_id)
      set_list_song.update(position: index + 1) if set_list_song
    end
  end
  
  content_type :json
  { success: true }.to_json
end

# Copy set list
post '/set_lists/:id/copy' do
  require_login
  begin
    original_set_list = filter_by_current_band(SetList).find_by(id: params[:id])
    
    unless original_set_list
      redirect '/set_lists'
    end
    
    # Create new set list with copied name and notes
    new_name = "Copy - #{original_set_list.name}"
    new_set_list = SetList.create!(
      name: new_name,
      notes: original_set_list.notes,
      band: original_set_list.band,
      performance_date: original_set_list.performance_date || Date.current
    )
    
    # Copy all songs with their positions
    original_set_list.set_list_songs.includes(:song).order(:position).each do |set_list_song|
      SetListSong.create!(
        set_list_id: new_set_list.id,
        song_id: set_list_song.song_id,
        position: set_list_song.position
      )
    end
    
    redirect "/set_lists/#{new_set_list.id}"
  rescue => e
    # If something goes wrong, redirect back with an error
    redirect "/set_lists/#{params[:id]}?error=copy_failed"
  end
end

# Bands routes
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
      redirect '/set_lists'
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
  
  # Only the owner can edit the band
  unless @band.owned_by?(current_user)
    @errors = ["Only the band owner can edit this band"]
    return erb :show_band
  end
  
  erb :edit_band
end

put '/bands/:id' do
  require_login
  @band = user_bands.find(params[:id])
  
  # Only the owner can edit the band
  unless @band.owned_by?(current_user)
    @errors = ["Only the band owner can edit this band"]
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
  band.user_bands.destroy_all
  
  # Delete the band
  band.destroy
  
  redirect '/bands'
end

# Add user to band
post '/bands/:id/add_user' do
  require_login
  @band = user_bands.find(params[:id])
  
  # Only the owner can add users
  unless @band.owned_by?(current_user)
    @user_error = "Only the band owner can add new members"
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

# Remove user from band
post '/bands/:id/remove_user' do
  require_login
  @band = user_bands.find(params[:id])
  user_to_remove = User.find(params[:user_id])
  
  # Users can always remove themselves, but only owners can remove others
  if user_to_remove != current_user && !@band.owned_by?(current_user)
    @user_error = "Only the band owner can remove other members"
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
      # Owner removing another user - stay on edit page with success message
      @user_success = "Successfully removed '#{user_to_remove.username}' from the band"
      erb :edit_band
    end
  else
    @user_error = "User is not a member of this band"
    erb :edit_band
  end
end

# Venues routes
get '/venues' do
  require_login
  return redirect '/set_lists' unless current_band
  
  @venues = filter_by_current_band(Venue).order(:name)
  erb :venues
end

get '/venues/new' do
  require_login
  return redirect '/set_lists' unless current_band
  erb :new_venue
end

post '/venues' do
  require_login
  return redirect '/set_lists' unless current_band
  
  venue = Venue.new(params[:venue])
  venue.band = current_band
  
  if venue.save
    redirect '/venues'
  else
    @errors = venue.errors.full_messages
    erb :new_venue
  end
end

get '/venues/:id' do
  require_login
  return redirect '/set_lists' unless current_band
  
  @venue = filter_by_current_band(Venue).find_by(id: params[:id])
  
  unless @venue
    redirect '/venues'
  end
  
  @bands = user_bands
  erb :show_venue
end

get '/venues/:id/edit' do
  require_login
  return redirect '/set_lists' unless current_band
  
  @venue = filter_by_current_band(Venue).find_by(id: params[:id])
  
  unless @venue
    redirect '/venues'
  end
  
  erb :edit_venue
end

put '/venues/:id' do
  require_login
  return redirect '/set_lists' unless current_band
  
  @venue = filter_by_current_band(Venue).find_by(id: params[:id])
  
  unless @venue
    redirect '/venues'
  end
  if @venue.update(params[:venue])
    redirect "/venues/#{@venue.id}"
  else
    @errors = @venue.errors.full_messages
    erb :edit_venue
  end
end

delete '/venues/:id' do
  require_login
  return redirect '/set_lists' unless current_band
  
  venue = filter_by_current_band(Venue).find_by(id: params[:id])
  
  if venue
    venue.destroy
  end
  
  redirect '/venues'
end

# Copy venues from other bands user is a member of
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
        band: @band
      )
      
      if new_venue.save
        copied_count += 1
      end
    end
  end
  
  redirect "/bands/#{@band.id}?venues_copied=#{copied_count}"
end

# Copy a single venue to another band
get '/venues/:venue_id/copy' do
  require_login
  return redirect '/set_lists' unless current_band
  
  @venue = filter_by_current_band(Venue).find_by(id: params[:venue_id])
  
  unless @venue
    redirect '/venues'
  end
  
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
  return redirect '/set_lists' unless current_band
  
  @venue = filter_by_current_band(Venue).find_by(id: params[:venue_id])
  
  unless @venue
    redirect '/venues'
  end
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

# API routes for AJAX
get '/api/songs' do
  require_login
  content_type :json
  
  if current_band
    songs = filter_by_current_band(Song).order(:title)
  else
    songs = []
  end
  songs.map { |song| { id: song.id, title: song.title, artist: song.artist } }.to_json
end

# Song lookup from songbpm.com
get '/api/lookup_song' do
  require_login
  content_type :json
  
  title = params[:title]
  artist = params[:artist] || ''
  
  if title.blank?
    return { error: 'Title is required' }.to_json
  end
  
  begin
    # First try the mock database for demo purposes
    mock_data = get_mock_song_data(title, artist)
    if mock_data[:found]
      return {
        success: true,
        data: mock_data
      }.to_json
    end
    
    # If not in mock data, try songbpm.com
    require 'net/http'
    require 'uri'
    require 'json'
    
    # Construct search query for songbpm.com
    query = "#{title} #{artist}".strip
    search_url = "https://songbpm.com/#{URI.encode_www_form_component(title.downcase.gsub(/\s+/, '-'))}"
    
    # Set up HTTP request with proper headers
    uri = URI(search_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'Mozilla/5.0 (compatible; Bandmate/1.0)'
    
    response = http.request(request)
    
    if response.code == '200'
      # Parse the HTML response to extract song data
      html = response.body
      song_data = parse_songbpm_response(html, title, artist)
      
      if song_data[:found]
        {
          success: true,
          data: song_data
        }.to_json
      else
        {
          success: false,
          error: 'Song not found on songbpm.com'
        }.to_json
      end
    else
      {
        success: false,
        error: 'Failed to fetch data from songbpm.com'
      }.to_json
    end
  rescue => e
    {
      success: false,
      error: "Lookup failed: #{e.message}"
    }.to_json
  end
end

private

def get_mock_song_data(title, artist)
  # Mock database of popular songs for demonstration
  # In a real implementation, this could be a local database or multiple API sources
  mock_songs = {
    'billie jean' => {
      artist: 'Michael Jackson',
      key: 'F#/Gb',
      tempo: 117,
      duration: '4:54'
    },
    'bohemian rhapsody' => {
      artist: 'Queen',
      key: 'A#/Bb',
      tempo: 72,
      duration: '5:55'
    },
    'hotel california' => {
      artist: 'Eagles',
      key: 'B',
      tempo: 75,
      duration: '6:30'
    },
    'stairway to heaven' => {
      artist: 'Led Zeppelin',
      key: 'A',
      tempo: 82,
      duration: '8:02'
    },
    'sweet child o mine' => {
      artist: 'Guns N\' Roses',
      key: 'D',
      tempo: 125,
      duration: '5:03'
    },
    'wonderwall' => {
      artist: 'Oasis',
      key: 'F#/Gb',
      tempo: 87,
      duration: '4:18'
    },
    'hey jude' => {
      artist: 'The Beatles',
      key: 'F',
      tempo: 75,
      duration: '7:11'
    },
    'imagine' => {
      artist: 'John Lennon',
      key: 'C',
      tempo: 76,
      duration: '3:03'
    },
    'smells like teen spirit' => {
      artist: 'Nirvana',
      key: 'F',
      tempo: 117,
      duration: '5:01'
    },
    'purple rain' => {
      artist: 'Prince',
      key: 'A#/Bb',
      tempo: 110,
      duration: '8:41'
    }
  }
  
  # Normalize title for lookup
  normalized_title = title.downcase.strip
  
  # Look for exact match or partial match
  song_data = mock_songs[normalized_title]
  
  if song_data
    # If artist is provided and doesn't match, don't use this data
    if artist.present? && !artist.downcase.include?(song_data[:artist].downcase.split.first.downcase)
      return { found: false }
    end
    
    {
      found: true,
      artist: song_data[:artist],
      key: song_data[:key],
      tempo: song_data[:tempo],
      duration: song_data[:duration]
    }
  else
    { found: false }
  end
end

def parse_songbpm_response(html, title, artist)
  # Simple HTML parsing to extract song information
  # This looks for common patterns in songbpm.com HTML structure
  
  begin
    # Look for BPM information
    bpm_match = html.match(/(\d+)\s*BPM/i)
    tempo = bpm_match ? bpm_match[1].to_i : nil
    
    # Look for key information
    key_match = html.match(/Key[:\s]*([A-G][#♯♭b]?\s*(?:major|minor|maj|min)?)/i)
    key = key_match ? normalize_key(key_match[1].strip) : nil
    
    # Look for duration information
    duration_match = html.match(/(\d{1,2}):(\d{2})/i)
    duration = duration_match ? "#{duration_match[1]}:#{duration_match[2]}" : nil
    
    # Extract artist name from the page if not provided
    if artist.blank?
      artist_match = html.match(/<h2[^>]*>([^<]+)<\/h2>/i) || 
                     html.match(/by\s+([^<\n]+)/i) ||
                     html.match(/artist[:\s]*([^<\n]+)/i)
      artist = artist_match ? artist_match[1].strip : nil
    end
    
    # Check if we found any useful data
    found = tempo || key || duration || artist
    
    {
      found: !!found,
      artist: artist,
      key: key,
      tempo: tempo,
      duration: duration
    }
  rescue => e
    {
      found: false,
      error: "Parsing error: #{e.message}"
    }
  end
end

def normalize_key(key_string)
  # Normalize key format to match our application's format
  key_string = key_string.gsub(/♯/, '#').gsub(/♭/, 'b')
  
  # Remove major/minor designations since our app only stores the root key
  key_string = key_string.gsub(/\s*(major|maj|minor|min|m)\s*/i, '').strip
  
  # Map common variations to our dropdown format
  key_mappings = {
    'Db' => 'C#/Db',
    'C#' => 'C#/Db',
    'Eb' => 'D#/Eb',
    'D#' => 'D#/Eb',
    'Gb' => 'F#/Gb',
    'F#' => 'F#/Gb',
    'Ab' => 'G#/Ab',
    'G#' => 'G#/Ab',
    'Bb' => 'A#/Bb',
    'A#' => 'A#/Bb'
  }
  
  key_mappings[key_string] || key_string
end

# Database setup route (legacy support)
get '/setup' do
  begin
    # Check if migrations table exists
    unless ActiveRecord::Base.connection.table_exists?('schema_migrations')
      # Run migrations if they haven't been run
      ActiveRecord::Base.connection.migration_context.migrate
    end
    
    # Seed the database
    if Band.count == 0
      Band.create!(name: "My Band", notes: "Default band created during setup")
    end
    
    "Database setup complete! Default band 'My Band' has been created."
  rescue => e
    "Database setup failed: #{e.message}. Please run 'rake db:setup' instead."
  end
end

# Start the server
if __FILE__ == $0
  puts "🎸 Bandmate is starting up..."
  puts "Visit http://localhost:4567 to access the application"
  puts "Visit http://localhost:4567/setup to initialize the database (first time only)"
  puts ""
  
  # Get local IP address for external access
  require 'socket'
  local_ip = Socket.ip_address_list.find { |addr| addr.ipv4? && !addr.ipv4_loopback? }&.ip_address
  if local_ip
    puts "🌐 External access: http://#{local_ip}:4567"
  end
  puts "Press Ctrl+C to stop the server"
  puts ""
  
  set :port, 4567
  set :bind, '0.0.0.0'  # Bind to all interfaces
  Sinatra::Application.run!
end 