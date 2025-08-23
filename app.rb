require 'sinatra'
require 'sinatra/activerecord'
require 'json'
require 'erb'
require 'bcrypt'
require 'rack/method_override'

enable :sessions
enable :static
use Rack::MethodOverride
set :session_secret, ENV['SESSION_SECRET'] || 'your_secret_key_here_that_is_very_long_and_secure_at_least_64_chars'
set :public_folder, File.dirname(__FILE__) + '/public'

# Account creation code for user registration (required)
# Set BANDMATE_ACCT_CREATION_SECRET environment variable to enable account creation

# Database configuration
configure :development do
  set :database, {
    adapter: 'postgresql',
    host: ENV['DATABASE_HOST'] || 'localhost',
    port: ENV['DATABASE_PORT'] || 5432,
    database: ENV['DATABASE_NAME'] || 'bandmate_development',
    username: ENV['DATABASE_USERNAME'] || 'postgres',
    password: ENV['DATABASE_PASSWORD'] || ''
  }
end

configure :production do
  # Use DATABASE_URL if available (common on Heroku), otherwise use individual env vars
  if ENV['DATABASE_URL']
    set :database, ENV['DATABASE_URL']
  else
    set :database, {
      adapter: 'postgresql',
      host: ENV['DATABASE_HOST'] || 'localhost',
      port: ENV['DATABASE_PORT'] || 5432,
      database: ENV['DATABASE_NAME'] || 'bandmate_production',
      username: ENV['DATABASE_USERNAME'] || 'postgres',
      password: ENV['DATABASE_PASSWORD'] || ''
    }
  end
end

configure :test do
  set :database, {
    adapter: 'postgresql',
    host: ENV['DATABASE_HOST'] || 'localhost',
    port: ENV['DATABASE_PORT'] || 5432,
    database: ENV['DATABASE_NAME'] || 'bandmate_test',
    username: ENV['DATABASE_USERNAME'] || 'postgres',
    password: ENV['DATABASE_PASSWORD'] || ''
  }
  set :bind, '0.0.0.0'
  set :port, 4567
  set :protection, false
  set :dump_errors, false
  set :raise_errors, true
  set :show_exceptions, false
end

# Models
class User < ActiveRecord::Base
  has_secure_password
  has_many :user_bands
  has_many :bands, through: :user_bands
  has_many :blackout_dates, dependent: :destroy
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
  has_and_belongs_to_many :songs, join_table: 'songs_bands'
  has_many :gigs
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
  has_and_belongs_to_many :bands, join_table: 'songs_bands'
  has_many :gig_songs
  has_many :gigs, through: :gig_songs
  
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
  has_many :gigs
  
  validates :name, presence: true
  validates :location, presence: true
  validates :contact_name, presence: true
  validates :phone_number, presence: true
end

class Gig < ActiveRecord::Base
  belongs_to :band
  belongs_to :venue, optional: true
  has_many :gig_songs, dependent: :destroy
  has_many :songs, through: :gig_songs
  
  validates :name, presence: true
  validates :band, presence: true
  validates :performance_date, presence: true
end

class GigSong < ActiveRecord::Base
  belongs_to :gig
  belongs_to :song
  
  validates :position, presence: true, numericality: { greater_than: 0 }
end

class BlackoutDate < ActiveRecord::Base
  belongs_to :user
  
  validates :blackout_date, presence: true
  validates :user, presence: true
  validates :user_id, uniqueness: { scope: :blackout_date }
  validate :blackout_date_not_in_past
  
  scope :for_date_range, ->(start_date, end_date) { where(blackout_date: start_date..end_date) }
  
  private
  
  def blackout_date_not_in_past
    return unless blackout_date.present?
    
    if blackout_date < Date.current
      errors.add(:blackout_date, "cannot be in the past")
    end
  end
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
  
  def gigs_for_date(date)
    gigs = {}
    
    # Current band gigs
    @current_band_gigs.select { |gig| gig.performance_date == date }.each do |gig|
      gigs[:current] ||= []
      gigs[:current] << gig
    end
    
    # Other band gigs
    @other_band_gigs.select { |gig| gig.performance_date == date }.each do |gig|
      gigs[:other] ||= []
      gigs[:other] << gig
    end
    
    # Bandmate conflicts
    @bandmate_conflicts.select { |gig| gig.performance_date == date }.each do |gig|
      gigs[:conflicts] ||= []
      gigs[:conflicts] << gig
    end
    
    # Blackout dates
    @blackout_dates.select { |blackout| blackout.blackout_date == date }.each do |blackout|
      gigs[:blackouts] ||= []
      gigs[:blackouts] << blackout
    end
    
    gigs
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
end

# ============================================================================
# ROUTES
# ============================================================================

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

# Root route
get '/' do
  require_login
  
  # If user has no bands, redirect to create or join a band
  if user_bands.empty?
    redirect '/bands/new?first_band=true'
  end
  
  # Redirect to set lists as the main screen
  redirect '/gigs'
end

# Band selection
post '/select_band' do
  require_login
  band = current_user.bands.find_by(id: params[:band_id])
  if band
    session[:band_id] = band.id
    # Save this as the user's preferred band
    current_user.update(last_selected_band_id: band.id)
  end
  
  # Check if we're on a specific record page and redirect to appropriate list
  referrer = request.env['HTTP_REFERER'] || ''
  
  if referrer.match?(/\/songs\/\d+/)
    redirect '/songs'
  elsif referrer.match?(/\/gigs\/\d+/)
    redirect '/gigs'
  elsif referrer.match?(/\/venues\/\d+/)
    redirect '/venues'
  elsif referrer.match?(/\/bands\/\d+/)
    redirect '/bands'
  elsif referrer.match?(/\/global_songs\/\d+/)
    redirect '/global_songs'
  else
    redirect back
  end
end

# ============================================================================
# AUTHENTICATION ROUTES
# ============================================================================

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
    
    redirect '/gigs'
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
    redirect '/gigs'
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

# ============================================================================
# USER PROFILE AND ACCOUNT ROUTES
# ============================================================================

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
  band.user_bands.destroy_all
  
  # Delete the band
  band.destroy
  
  redirect '/bands'
end

# Band user management
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

# Copy songs to band
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

# Copy songs from global list
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
    redirect '/gigs'
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
  
  gig.destroy
  redirect '/gigs'
end

# Set list management
post '/gigs/:id/songs' do
  require_login
  gig = filter_by_current_band(Gig).find(params[:id])
  
  song = filter_by_current_band(Song).find(params[:song_id])
  position = gig.gig_songs.count + 1
  
  gig_song = GigSong.new(
    gig: gig,
    song: song,
    position: position
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

# Gig utilities
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
    original_gig.gig_songs.includes(:song).order(:position).each do |gig_song|
      GigSong.create!(
        gig_id: new_gig.id,
        song_id: gig_song.song_id,
        position: gig_song.position
      )
    end
    
    redirect "/gigs/#{new_gig.id}"
  rescue => e
    # If something goes wrong, redirect back with an error
    redirect "/gigs/#{params[:id]}?error=copy_failed"
  end
end

# ============================================================================
# VENUE ROUTES
# ============================================================================

get '/venues' do
  require_login
  return redirect '/gigs' unless current_band
  
  @venues = filter_by_current_band(Venue).order(:name)
  erb :venues
end

get '/venues/new' do
  require_login
  return redirect '/gigs' unless current_band
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
    erb :new_venue
  end
end

get '/venues/:id' do
  require_login
  return redirect '/gigs' unless current_band
  
  @venue = filter_by_current_band(Venue).find(params[:id])
  
  @bands = user_bands
  erb :show_venue
end

get '/venues/:id/edit' do
  require_login
  return redirect '/gigs' unless current_band
  
  @venue = filter_by_current_band(Venue).find(params[:id])
  
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
  
  # Get the first and last day of the month
  start_date = Date.new(@year, @month, 1)
  next_month = @month == 12 ? Date.new(@year + 1, 1, 1) : Date.new(@year, @month + 1, 1)
  end_date = next_month - 1
  
  # Get all user's bands
  user_band_ids = current_user.bands.pluck(:id)
  
  # Get current band gigs for this month
  @current_band_gigs = if current_band
    current_band.gigs.where(performance_date: start_date..end_date)
                      .includes(:venue)
                      .order(:performance_date)
  else
    []
  end
  
  # Get user's gigs from other bands
  @other_band_gigs = Gig.joins(:band)
                        .where(bands: { id: user_band_ids })
                        .where(performance_date: start_date..end_date)
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
    
    # Get gigs from those bands - simplified query
    if bandmate_band_ids.any?
      Gig.joins(:band)
         .where(bands: { id: bandmate_band_ids })
         .where(performance_date: start_date..end_date)
         .includes(:band)
         .order(:performance_date)
    else
      []
    end
  else
    []
  end
  
  # Get blackout dates for all users in current band (if there is one)
  if current_band
    bandmate_ids = current_band.users.pluck(:id)
    @blackout_dates = BlackoutDate.where(user_id: bandmate_ids)
                                  .where(blackout_date: start_date..end_date)
                                  .includes(:user)
  else
    @blackout_dates = current_user.blackout_dates
                                  .where(blackout_date: start_date..end_date)
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
    blackout_date = Date.parse(date_param)
    
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
    
  rescue Date::Error
    content_type :json
    { error: 'Invalid date format' }.to_json
  rescue => e
    content_type :json
    { error: 'Failed to create blackout date' }.to_json
  end
end

delete '/blackout_dates/:date' do
  require_login
  
  begin
    blackout_date = Date.parse(params[:date])
    
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
    
  rescue Date::Error
    content_type :json
    { error: 'Invalid date format' }.to_json
  rescue => e
    content_type :json
    { error: 'Failed to remove blackout date' }.to_json
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
      blackout_date = Date.parse(date_str.strip)
      
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
    end
    
    content_type :json
    if errors.empty?
      { success: true, created_count: created_count, message: "Created #{created_count} blackout date#{created_count == 1 ? '' : 's'}" }.to_json
    else
      { success: false, created_count: created_count, errors: errors }.to_json
    end
    
  rescue Date::Error => e
    content_type :json
    { error: "Invalid date format: #{e.message}" }.to_json
  rescue => e
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
      blackout_date = Date.parse(date_str.strip)
      
      # Find and delete the blackout date for current user
      blackout = current_user.blackout_dates.find_by(blackout_date: blackout_date)
      
      if blackout
        blackout.destroy
        deleted_count += 1
      end
    end
    
    content_type :json
    { success: true, deleted_count: deleted_count, message: "Removed #{deleted_count} blackout date#{deleted_count == 1 ? '' : 's'}" }.to_json
    
  rescue Date::Error => e
    content_type :json
    { error: "Invalid date format: #{e.message}" }.to_json
  rescue => e
    content_type :json
    { error: 'Failed to remove blackout dates' }.to_json
  end
end

# ============================================================================
# API ROUTES
# ============================================================================

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

# ============================================================================
# UTILITY ROUTES
# ============================================================================

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