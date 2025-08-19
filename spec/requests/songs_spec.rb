require 'spec_helper'

RSpec.describe 'Songs API', type: :request do
  let(:user) { create(:user) }
  let(:band) { create(:band, owner: user) }
  
  before do
    create(:user_band, user: user, band: band)
  end
  describe 'GET /songs' do
    it 'returns a list of all songs' do
      login_as(user, band)
      song1 = create(:song, title: 'Song A', artist: 'Artist A', bands: [band])
      song2 = create(:song, title: 'Song B', artist: 'Artist B', bands: [band])
      
      get '/songs'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Song A')
      expect(last_response.body).to include('Song B')
    end

    it 'displays songs in alphabetical order by title' do
      login_as(user, band)
      song_c = create(:song, title: 'C Song', bands: [band])
      song_a = create(:song, title: 'A Song', bands: [band])
      song_b = create(:song, title: 'B Song', bands: [band])
      
      get '/songs'
      
      expect(last_response).to be_ok
      body = last_response.body
      a_index = body.index('A Song')
      b_index = body.index('B Song')
      c_index = body.index('C Song')
      
      expect(a_index).to be < b_index
      expect(b_index).to be < c_index
    end

    it 'filters songs by search term' do
      login_as(user, band)
      song1 = create(:song, title: 'Wonderwall', artist: 'Oasis', bands: [band])
      song2 = create(:song, title: 'Yellow', artist: 'Coldplay', bands: [band])
      
      get '/songs', search: 'wonderwall'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Wonderwall')
      expect(last_response.body).not_to include('Yellow')
    end

    it 'filters songs by artist' do
      login_as(user, band)
      song1 = create(:song, title: 'Wonderwall', artist: 'Oasis', bands: [band])
      song2 = create(:song, title: 'Yellow', artist: 'Coldplay', bands: [band])
      
      get '/songs', search: 'oasis'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Wonderwall')
      expect(last_response.body).not_to include('Yellow')
    end

    it 'shows songs for the currently selected band' do
      band1 = create(:band, name: 'Band 1', owner: user)
      band2 = create(:band, name: 'Band 2')
      create(:user_band, user: user, band: band1)

      song1 = create(:song, title: 'Song 1', bands: [band1])
      song2 = create(:song, title: 'Song 2', bands: [band2])

      login_as(user, band1)
      get '/songs'

      expect(last_response).to be_ok
      expect(last_response.body).to include('Song 1')
      expect(last_response.body).not_to include('Song 2')
    end

    it 'combines search with the currently selected band' do
      band1 = create(:band, name: 'Band 1', owner: user)
      band2 = create(:band, name: 'Band 2')
      create(:user_band, user: user, band: band1)

      song1 = create(:song, title: 'Rock Song', artist: 'Rock Artist', bands: [band1])
      song2 = create(:song, title: 'Jazz Song', artist: 'Jazz Artist', bands: [band1])
      song3 = create(:song, title: 'Rock Song', artist: 'Rock Artist', bands: [band2])

      login_as(user, band1)
      get '/songs', search: 'rock'

      expect(last_response).to be_ok
      expect(last_response.body).to include('Rock Song')
      expect(last_response.body).not_to include('Jazz Song')
      # Should not include songs from other bands with the same title
      expect(last_response.body.scan('Rock Song').length).to eq(1)
    end
  end

  describe 'GET /songs/new' do
    it 'displays the new song form' do
      login_as(user, band)
      
      get '/songs/new'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('New Song')
      expect(last_response.body).to include('title')
      expect(last_response.body).to include('artist')
      expect(last_response.body).to include('key')
      expect(last_response.body).to include(band.name)
    end
  end

  describe 'POST /songs' do
    it 'creates a new song with valid attributes' do
      login_as(user, band)
      song_params = {
        title: 'New Song',
        artist: 'New Artist',
        key: 'C',
        tempo: '120',
        notes: 'A great song',
        band_ids: [band.id]
      }
      
      expect {
        post '/songs', song: song_params
      }.to change(Song, :count).by(1)
      
      expect(last_response).to be_redirect
      follow_redirect!
      expect(last_response.body).to include('New Song')
      expect(last_response.body).to include('New Artist')
    end

    it 'associates song with multiple bands' do
      login_as(user, band)
      band1 = create(:band)
      band2 = create(:band)
      create(:user_band, user: user, band: band1)
      create(:user_band, user: user, band: band2)
      song_params = {
        title: 'Multi Band Song',
        artist: 'Multi Artist',
        key: 'G',
        band_ids: [band1.id, band2.id]
      }
      
      post '/songs', song: song_params
      
      song = Song.last
      expect(song.bands).to include(band1, band2)
    end

    it 'displays errors for invalid attributes' do
      login_as(user, band)
      song_params = {
        title: '',
        artist: '',
        key: '',
        band_ids: []
      }
      
      expect {
        post '/songs', song: song_params
      }.not_to change(Song, :count)
      
      expect(last_response).to be_ok
      expect(last_response.body).to include("can't be blank")
    end

    it 'displays errors for invalid tempo' do
      login_as(user, band)
      song_params = {
        title: 'Valid Song',
        artist: 'Valid Artist',
        key: 'C',
        tempo: '-10',
        band_ids: [band.id]
      }
      
      expect {
        post '/songs', song: song_params
      }.not_to change(Song, :count)
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('must be greater than 0')
    end
  end

  describe 'GET /songs/:id' do
    it 'displays a specific song' do
      login_as(user, band)
      song = create(:song, title: 'Test Song', artist: 'Test Artist', key: 'C', bands: [band])
      
      get "/songs/#{song.id}"
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Test Song')
      expect(last_response.body).to include('Test Artist')
      expect(last_response.body).to include('C')
    end

    it 'returns 404 for non-existent song' do
      login_as(user, band)
      expect { get '/songs/999' }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'GET /songs/:id/edit' do
    it 'displays the edit form for a song' do
      login_as(user, band)
      song = create(:song, title: 'Edit Song', artist: 'Edit Artist', bands: [band])
      
      get "/songs/#{song.id}/edit"
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Edit Song')
      expect(last_response.body).to include('Edit Artist')
      expect(last_response.body).to include('method="POST"')
      expect(last_response.body).to include('_method" value="PUT"')
    end

    it 'returns 404 for non-existent song' do
      login_as(user, band)
      expect { get '/songs/999/edit' }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'PUT /songs/:id' do
    it 'updates a song with valid attributes' do
      login_as(user, band)
      song = create(:song, title: 'Old Title', artist: 'Old Artist', bands: [band])
      update_params = {
        title: 'New Title',
        artist: 'New Artist',
        key: 'G',
        tempo: '140'
      }
      
      put "/songs/#{song.id}", song: update_params
      
      expect(last_response).to be_redirect
      follow_redirect!
      expect(last_response.body).to include('New Title')
      expect(last_response.body).to include('New Artist')
    end

    it 'updates band associations' do
      login_as(user, band)
      song = create(:song, bands: [band])
      old_band = song.bands.first
      new_band = create(:band)
      
      update_params = {
        title: song.title,
        artist: song.artist,
        key: song.key,
        band_ids: [new_band.id]
      }
      
      put "/songs/#{song.id}", song: update_params
      
      song.reload
      expect(song.bands).to include(new_band)
      expect(song.bands).not_to include(old_band)
    end

    it 'displays errors for invalid attributes' do
      login_as(user, band)
      song = create(:song, title: 'Valid Title', bands: [band])
      update_params = { title: '', artist: 'Valid Artist', key: 'C' }
      
      put "/songs/#{song.id}", song: update_params
      
      expect(last_response).to be_ok
      expect(last_response.body).to include("can't be blank")
    end

    it 'returns 404 for non-existent song' do
      login_as(user, band)
      expect { put '/songs/999', song: { title: 'New Title' } }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'DELETE /songs/:id' do
    it 'deletes a song' do
      login_as(user, band)
      song = create(:song, title: 'Delete Song', bands: [band])
      
      expect {
        delete "/songs/#{song.id}"
      }.to change(Song, :count).by(-1)
      
      expect(last_response).to be_redirect
      expect(last_response.location).to end_with('/songs')
    end

    it 'returns 404 for non-existent song' do
      login_as(user, band)
      expect { delete '/songs/999' }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end 