require 'dotenv/load'
require 'sinatra'
require 'sinatra/activerecord'
require 'json'
require 'erb'
require 'bcrypt'
require 'rack/method_override'

# Load models
require_relative 'lib/models/user'
require_relative 'lib/models/user_band'
require_relative 'lib/models/band'
require_relative 'lib/models/song_catalog'
require_relative 'lib/models/song'
require_relative 'lib/models/venue'
require_relative 'lib/models/gig'
require_relative 'lib/models/gig_song'
require_relative 'lib/models/blackout_date'
require_relative 'lib/models/google_calendar_event'
require_relative 'lib/models/practice'
require_relative 'lib/models/practice_availability'

# Load services
require_relative 'lib/services/google_calendar_service'
require_relative 'lib/services/error_handler'

# Load helpers
require_relative 'lib/helpers/icon_helpers'
require_relative 'lib/helpers/application_helpers'

# Load route modules
require_relative 'lib/routes/authentication'
require_relative 'lib/routes/bands'
require_relative 'lib/routes/songs'
require_relative 'lib/routes/gigs'
require_relative 'lib/routes/venues'
require_relative 'lib/routes/calendar'
require_relative 'lib/routes/practices'
require_relative 'lib/routes/api'

enable :sessions
enable :static
use Rack::MethodOverride
set :session_secret, ENV['SESSION_SECRET'] || 'your_secret_key_here_that_is_very_long_and_secure_at_least_64_chars'
set :public_folder, File.dirname(__FILE__) + '/public'

# Include application helpers
helpers ApplicationHelpers

# Mount route modules
use Routes::Authentication
use Routes::Bands
use Routes::Songs
use Routes::Gigs
use Routes::Venues
use Routes::Calendar
use Routes::Practices
use Routes::Api

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

# ============================================================================
# ROUTES
# ============================================================================

# Test authentication route (only available in test mode)
post '/test_auth' do
  if settings.test?
    # Allow tests to set authentication state directly
    # Handle both direct params and nested params format
    auth_params = params[:params] || params

    @test_session = {}
    @test_session[:user_id] = auth_params[:user_id] if auth_params[:user_id]
    @test_session[:band_id] = auth_params[:band_id] if auth_params[:band_id]
    session[:user_id] = auth_params[:user_id] if auth_params[:user_id]
    session[:band_id] = auth_params[:band_id] if auth_params[:band_id]
    status 200
    body "Authentication set"
  else
    status 404
  end
end

# Health check endpoint for load balancers and monitoring
get '/health' do
  content_type :json
  { status: 'ok', timestamp: Time.now.iso8601 }.to_json
end

# Application root route
get '/' do
  if logged_in?
    # If user has no bands, redirect to create first band
    if user_bands.empty?
      redirect '/bands/new?first_band=true'
    else
      redirect '/gigs'
    end
  else
    redirect '/login'
  end
end

# Band selection route
post '/select_band' do
  require_login
  
  band = user_bands.find_by(id: params[:band_id])
  if band
    session[:band_id] = band.id
    # Save this as the user's preferred band
    current_user.update(last_selected_band_id: band.id)
    
    # Determine which section to redirect to based on current path
    current_path = params[:current_path] || params[:redirect_to] || '/gigs'

    # Use helper method to map current path to appropriate list view
    redirect_to = redirect_path_for_section(current_path)

    redirect redirect_to
  else
    status 404
  end
end

# Start the server
if __FILE__ == $0
  puts "🎸 Bandmate is starting up..."
  puts ""
  puts "📡 Starting HTTP server on port 4567"

  # Get local IP address for external access
  require 'socket'
  local_ip = Socket.ip_address_list.find { |addr| addr.ipv4? && !addr.ipv4_loopback? }&.ip_address

  if local_ip
    puts "🌐 Your local IP address is: #{local_ip}"
    puts "   Internal access: http://#{local_ip}:4567"
  end
  puts ""

  set :port, 4567
  set :bind, '0.0.0.0'  # Bind to all interfaces
  Sinatra::Application.run!
end