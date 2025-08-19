ENV['RACK_ENV'] = 'test'

require 'rspec'
require 'rack/test'
require 'capybara/rspec'
require 'factory_bot'
require 'faker'
require_relative '../app'

# Load factories
require_relative 'factories'

puts "[DEBUG] ActiveRecord DB file: #{ActiveRecord::Base.connection_db_config.database}"

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.include Capybara::DSL
  config.include FactoryBot::Syntax::Methods

  def app
    Sinatra::Application
  end

  def login_as(user, band = nil)
    # For testing, we'll use the test login route
    # This bypasses the normal authentication flow
    if band
      # Ensure user is a member of the band
      user.bands << band unless user.bands.include?(band)
    end
    
    # Use the test login route to set the session
    post '/test_login', user_id: user.id, band_id: band&.id
  end

  config.before(:each) do
    # Clear in proper order to respect foreign key constraints
    SetListSong.delete_all
    SetList.delete_all
    UserBand.delete_all
    # Clear many-to-many relationships first
    ActiveRecord::Base.connection.execute("DELETE FROM bands_songs")
    Song.delete_all
    Venue.delete_all
    # Clear user's last_selected_band_id reference before deleting bands
    User.update_all(last_selected_band_id: nil)
    Band.delete_all
    User.delete_all
    GlobalSong.delete_all
  end
end

Capybara.app = Sinatra::Application
Capybara.default_driver = :rack_test
Capybara.javascript_driver = :selenium_chrome_headless

class String
  def camelize
    self.split('_').map(&:capitalize).join
  end
end 