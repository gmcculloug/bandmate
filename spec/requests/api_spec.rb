require 'spec_helper'

RSpec.describe 'API Endpoints', type: :request do
  describe 'GET /api/songs' do
    it 'returns songs as JSON' do
      user = create(:user)
      band = create(:band, owner: user)
      song1 = create(:song, title: 'Song 1', artist: 'Artist 1', bands: [band])
      song2 = create(:song, title: 'Song 2', artist: 'Artist 2', bands: [band])
      
      login_as(user, band)
      get '/api/songs'
      
      expect(last_response).to be_ok
      expect(last_response.content_type).to include('application/json')
      
      songs = JSON.parse(last_response.body)
      expect(songs.length).to eq(2)
      expect(songs.first['title']).to eq('Song 1')
      expect(songs.first['artist']).to eq('Artist 1')
    end

    it 'filters songs by band when band_id is provided' do
      user = create(:user)
      band1 = create(:band, name: 'Band 1', owner: user)
      band2 = create(:band, name: 'Band 2', owner: user)
      
      song1 = create(:song, title: 'Song 1', artist: 'Artist 1', bands: [band1])
      song2 = create(:song, title: 'Song 2', artist: 'Artist 2', bands: [band2])
      
      login_as(user, band1)
      get '/api/songs', band_id: band1.id
      
      expect(last_response).to be_ok
      songs = JSON.parse(last_response.body)
      expect(songs.length).to eq(1)
      expect(songs.first['title']).to eq('Song 1')
    end

    it 'returns empty array when no songs match band filter' do
      user = create(:user)
      band = create(:band, owner: user)
      
      login_as(user, band)
      get '/api/songs', band_id: band.id
      
      expect(last_response).to be_ok
      songs = JSON.parse(last_response.body)
      expect(songs).to eq([])
    end

    it 'returns all songs when band_id is not provided' do
      user = create(:user)
      band = create(:band, owner: user)
      song1 = create(:song, title: 'Song 1', bands: [band])
      song2 = create(:song, title: 'Song 2', bands: [band])
      
      login_as(user, band)
      get '/api/songs'
      
      expect(last_response).to be_ok
      songs = JSON.parse(last_response.body)
      expect(songs.length).to eq(2)
    end
  end

  describe 'GET /setup' do
    it 'sets up the database when no bands exist' do
      # Ensure no bands exist
      Band.destroy_all
      
      get '/setup'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Database setup complete')
      expect(last_response.body).to include('My Band')
      
      # Check that a band was created
      expect(Band.count).to eq(1)
      expect(Band.first.name).to eq('My Band')
    end

    it 'does not create duplicate bands when bands already exist' do
      existing_band = create(:band, name: 'Existing Band')
      initial_count = Band.count
      
      get '/setup'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Database setup complete')
      
      # Check that no new band was created
      expect(Band.count).to eq(initial_count)
      expect(Band.where(name: 'My Band')).to be_empty
    end

    it 'handles database setup errors gracefully' do
      # Mock a database error by temporarily breaking the connection
      allow(ActiveRecord::Base.connection).to receive(:table_exists?).and_raise(StandardError.new('Database error'))
      
      get '/setup'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Database setup failed')
      expect(last_response.body).to include('Please run')
    end
  end

  describe 'GET /' do
    it 'redirects to create first band when no bands exist' do
      user = create(:user)
      Band.destroy_all
      
      login_as(user)
      get '/'
      
      expect(last_response).to be_redirect
      expect(last_response.location).to include('/bands/new')
      expect(last_response.location).to include('first_band=true')
    end

    it 'displays the home page when bands exist' do
      user = create(:user)
      band = create(:band, owner: user)
      song = create(:song, bands: [band])
      set_list = create(:set_list, band: band)
      
      login_as(user, band)
      get '/'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include(band.name)
      expect(last_response.body).to include(song.title)
      expect(last_response.body).to include(set_list.name)
    end
  end
end 