require 'sinatra'
require 'sinatra/activerecord'
require 'json'
require 'erb'

# Database configuration
database_path = ENV['DATABASE_PATH'] || 'bandage.db'
set :database, { adapter: 'sqlite3', database: database_path }

# Models
class Band < ActiveRecord::Base
  has_and_belongs_to_many :songs
  has_many :set_lists
  
  validates :name, presence: true
  validates :name, uniqueness: true
end

class Song < ActiveRecord::Base
  has_and_belongs_to_many :bands
  has_many :set_list_songs
  has_many :set_lists, through: :set_list_songs
  
  validates :title, presence: true
  validates :artist, presence: true
  validates :key, presence: true
  validates :bands, presence: true

  validates :tempo, numericality: { greater_than: 0 }, allow_nil: true
end

class Venue < ActiveRecord::Base
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
end

class SetListSong < ActiveRecord::Base
  belongs_to :set_list
  belongs_to :song
  
  validates :position, presence: true, numericality: { greater_than: 0 }
end

# Routes
get '/' do
  # Check if there are any bands, if not redirect to create first band
  if Band.count == 0
    redirect '/bands/new?first_band=true'
  end
  
  @songs = Song.order(:title)
  @set_lists = SetList.order(:name)
  @bands = Band.order(:name)
  erb :index
end

# Songs routes
get '/songs' do
  @search = params[:search]
  @band_filter = params[:band_id]
  @bands = Band.order(:name)
  
  @songs = Song.order('LOWER(title)')
  
  # Apply search filter
  if @search.present?
    @songs = @songs.where('LOWER(title) LIKE ? OR LOWER(artist) LIKE ?', "%#{@search.downcase}%", "%#{@search.downcase}%")
  end
  
  # Apply band filter
  if @band_filter.present?
    @songs = @songs.joins(:bands).where(bands: { id: @band_filter })
  end
  
  erb :songs
end

get '/songs/new' do
  @bands = Band.order(:name)
  erb :new_song
end

post '/songs' do
  song = Song.new(params[:song])
  
  # Handle band associations
  if params[:song] && params[:song][:band_ids]
    band_ids = params[:song][:band_ids].reject(&:blank?)
    song.band_ids = band_ids
  end
  
  if song.save
    redirect '/songs'
  else
    @errors = song.errors.full_messages
    @bands = Band.order(:name)
    erb :new_song
  end
end

get '/songs/:id' do
  @song = Song.find(params[:id])
  erb :show_song
end

get '/songs/:id/edit' do
  @song = Song.find(params[:id])
  @bands = Band.order(:name)
  erb :edit_song
end

put '/songs/:id' do
  @song = Song.find(params[:id])
  
  # Handle band associations
  if params[:song] && params[:song][:band_ids]
    band_ids = params[:song][:band_ids].reject(&:blank?)
    @song.band_ids = band_ids
  end
  
  if @song.update(params[:song])
    redirect "/songs/#{@song.id}"
  else
    @errors = @song.errors.full_messages
    @bands = Band.order(:name)
    erb :edit_song
  end
end

delete '/songs/:id' do
  song = Song.find(params[:id])
  song.destroy
  redirect '/songs'
end

# Set lists routes
get '/set_lists' do
  @set_lists = SetList.includes(:venue).order(:name)
  erb :set_lists
end

get '/set_lists/new' do
  @bands = Band.order(:name)
  @venues = Venue.order(:name)
  @songs = Song.order(:title)
  erb :new_set_list
end

post '/set_lists' do
  set_list_params = {
    name: params[:name], 
    band_id: params[:band_id],
    venue_id: params[:venue_id].presence,
    performance_date: params[:performance_date].presence,
    start_time: params[:start_time].presence,
    end_time: params[:end_time].presence
  }
  
  set_list = SetList.new(set_list_params)
  if set_list.save
    redirect '/set_lists'
  else
    @errors = set_list.errors.full_messages
    @bands = Band.order(:name)
    @venues = Venue.order(:name)
    @songs = Song.order(:title)
    erb :new_set_list
  end
end

get '/set_lists/:id' do
  @set_list = SetList.includes(:venue).find(params[:id])
  # Get songs from the same band for adding to set list
  @available_songs = Song.joins(:bands).where(bands: { id: @set_list.band.id }).where.not(id: @set_list.song_ids).order(:title)
  erb :show_set_list
end

get '/set_lists/:id/edit' do
  @set_list = SetList.find(params[:id])
  @bands = Band.order(:name)
  @venues = Venue.order(:name)
  erb :edit_set_list
end

put '/set_lists/:id' do
  @set_list = SetList.find(params[:id])
  set_list_params = {
    name: params[:name], 
    band_id: params[:band_id],
    venue_id: params[:venue_id].presence,
    performance_date: params[:performance_date].presence,
    start_time: params[:start_time].presence,
    end_time: params[:end_time].presence
  }
  
  if @set_list.update(set_list_params)
    redirect "/set_lists/#{@set_list.id}"
  else
    @errors = @set_list.errors.full_messages
    @bands = Band.order(:name)
    @venues = Venue.order(:name)
    erb :edit_set_list
  end
end

delete '/set_lists/:id' do
  set_list = SetList.find(params[:id])
  set_list.destroy
  redirect '/set_lists'
end

# Add song to set list
post '/set_lists/:id/songs' do
  set_list = SetList.find(params[:id])
  song = Song.find(params[:song_id])
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
  set_list = SetList.find(params[:set_list_id])
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
  @set_list = SetList.find(params[:id])
  erb :print_set_list, layout: false
end

# Reorder songs in set list
post '/set_lists/:id/reorder' do
  set_list = SetList.find(params[:id])
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
  begin
    original_set_list = SetList.find(params[:id])
    
    # Create new set list with copied name and notes
    new_name = "Copy - #{original_set_list.name}"
    new_set_list = SetList.create!(
      name: new_name,
      notes: original_set_list.notes,
      band: original_set_list.band
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
  @bands = Band.order(:name)
  erb :bands
end

get '/bands/new' do
  erb :new_band
end

post '/bands' do
  band = Band.new(params[:band])
  if band.save
    # If this is the first band, redirect to home page
    if Band.count == 1
      redirect '/'
    else
      redirect '/bands'
    end
  else
    @errors = band.errors.full_messages
    erb :new_band
  end
end

get '/bands/:id' do
  @band = Band.find(params[:id])
  erb :show_band
end

get '/bands/:id/edit' do
  @band = Band.find(params[:id])
  erb :edit_band
end

put '/bands/:id' do
  @band = Band.find(params[:id])
  if @band.update(params[:band])
    redirect "/bands/#{@band.id}"
  else
    @errors = @band.errors.full_messages
    erb :edit_band
  end
end

delete '/bands/:id' do
  band = Band.find(params[:id])
  band.destroy
  redirect '/bands'
end

# Venues routes
get '/venues' do
  @venues = Venue.order(:name)
  erb :venues
end

get '/venues/new' do
  erb :new_venue
end

post '/venues' do
  venue = Venue.new(params[:venue])
  if venue.save
    redirect '/venues'
  else
    @errors = venue.errors.full_messages
    erb :new_venue
  end
end

get '/venues/:id' do
  @venue = Venue.find(params[:id])
  erb :show_venue
end

get '/venues/:id/edit' do
  @venue = Venue.find(params[:id])
  erb :edit_venue
end

put '/venues/:id' do
  @venue = Venue.find(params[:id])
  if @venue.update(params[:venue])
    redirect "/venues/#{@venue.id}"
  else
    @errors = @venue.errors.full_messages
    erb :edit_venue
  end
end

delete '/venues/:id' do
  venue = Venue.find(params[:id])
  venue.destroy
  redirect '/venues'
end

# API routes for AJAX
get '/api/songs' do
  content_type :json
  band_id = params[:band_id]
  if band_id.present?
    songs = Song.joins(:bands).where(bands: { id: band_id }).order(:title)
  else
    songs = Song.order(:title)
  end
  songs.map { |song| { id: song.id, title: song.title, artist: song.artist } }.to_json
end

# Create database tables
get '/setup' do
  ActiveRecord::Schema.define do
    create_table :bands, force: true do |t|
      t.string :name, null: false
      t.text :notes
      t.timestamps
    end

    create_table :songs, force: true do |t|
      t.string :title, null: false
      t.string :artist, null: false
      t.string :key, null: false
      t.string :original_key
      t.integer :tempo
      t.string :genre
      t.string :url
      t.text :notes
      t.string :duration
      t.integer :year
      t.string :album
      t.timestamps
    end

    create_table :bands_songs, force: true do |t|
      t.references :band, null: false
      t.references :song, null: false
      t.timestamps
    end

    create_table :venues, force: true do |t|
      t.string :name, null: false
      t.string :location, null: false
      t.string :contact_name, null: false
      t.string :phone_number, null: false
      t.string :website
      t.timestamps
    end

    create_table :set_lists, force: true do |t|
      t.string :name, null: false
      t.text :notes
      t.references :band, null: false
      t.references :venue
      t.date :performance_date
      t.time :start_time
      t.time :end_time
      t.timestamps
    end

    create_table :set_list_songs, force: true do |t|
      t.references :set_list, null: false
      t.references :song, null: false
      t.integer :position, null: false
      t.timestamps
    end
  end
  
  # Create a default band if none exists
  if Band.count == 0
    Band.create!(name: "My Band", notes: "Default band created during setup")
  end
  
  "Database setup complete! Default band 'My Band' has been created."
end

# Start the server
if __FILE__ == $0
  puts "🎸 Bandage is starting up..."
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