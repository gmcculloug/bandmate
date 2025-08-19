require 'spec_helper'

RSpec.describe 'Set Lists API', type: :request do
  let(:user) { create(:user) }
  let(:band) { create(:band, owner: user) }
  
  before do
    create(:user_band, user: user, band: band)
  end
  describe 'GET /set_lists' do
    it 'returns a list of all set lists' do
      login_as(user, band)
      set_list1 = create(:set_list, name: 'Set List A', band: band)
      set_list2 = create(:set_list, name: 'Set List B', band: band)
      
      get '/set_lists'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Set List A')
      expect(last_response.body).to include('Set List B')
    end

    it 'displays set lists in alphabetical order' do
      login_as(user, band)
      set_list_c = create(:set_list, name: 'C Set List', band: band)
      set_list_a = create(:set_list, name: 'A Set List', band: band)
      set_list_b = create(:set_list, name: 'B Set List', band: band)
      
      get '/set_lists'
      
      expect(last_response).to be_ok
      body = last_response.body
      a_index = body.index('A Set List')
      b_index = body.index('B Set List')
      c_index = body.index('C Set List')
      
      expect(a_index).to be < b_index
      expect(b_index).to be < c_index
    end
  end

  describe 'GET /set_lists/new' do
    it 'displays the new set list form' do
      login_as(user, band)
      venue = create(:venue, band: band)
      
      get '/set_lists/new'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('New Set List')
      expect(last_response.body).to include('name')
      expect(last_response.body).to include(band.name)
      expect(last_response.body).to include(venue.name)
    end
  end

  describe 'POST /set_lists' do
    it 'creates a new set list with valid attributes' do
      login_as(user, band)
      venue = create(:venue, band: band)
      set_list_params = {
        name: 'New Set List',
        band_id: band.id,
        venue_id: venue.id,
        performance_date: '2024-12-25',
        start_time: '20:00',
        end_time: '22:00',
        notes: 'A great set list'
      }
      
      expect {
        post '/set_lists', set_list_params
      }.to change(SetList, :count).by(1)
      
      expect(last_response).to be_redirect
      follow_redirect!
      expect(last_response.body).to include('New Set List')
    end

    it 'creates a set list without optional venue' do
      login_as(user, band)
      set_list_params = {
        name: 'Set List No Venue',
        band_id: band.id,
        performance_date: '2024-12-25'
      }
      
      expect {
        post '/set_lists', set_list_params
      }.to change(SetList, :count).by(1)
      
      expect(last_response).to be_redirect
    end

    it 'displays errors for invalid attributes' do
      login_as(user, band)
      set_list_params = {
        name: '',
        band_id: ''
      }
      
      expect {
        post '/set_lists', set_list_params
      }.not_to change(SetList, :count)
      
      expect(last_response).to be_ok
      expect(last_response.body).to include("can't be blank")
    end

    it 'displays errors when performance_date is missing' do
      login_as(user, band)
      set_list_params = {
        name: 'Test Set List',
        band_id: band.id,
        performance_date: ''
      }
      
      expect {
        post '/set_lists', set_list_params
      }.not_to change(SetList, :count)
      
      expect(last_response).to be_ok
      expect(last_response.body).to include("Performance date can't be blank")
    end
  end

  describe 'GET /set_lists/:id' do
    it 'displays a specific set list' do
      login_as(user, band)
      set_list = create(:set_list, name: 'Test Set List', notes: 'Test notes', band: band)
      
      get "/set_lists/#{set_list.id}"
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Test Set List')
      expect(last_response.body).to include('Test notes')
    end

    it 'shows available songs for the band' do
      login_as(user, band)
      set_list = create(:set_list, band: band)
      song1 = create(:song, bands: [band])
      song2 = create(:song, bands: [band])
      
      get "/set_lists/#{set_list.id}"
      
      expect(last_response).to be_ok
      expect(last_response.body).to include(song1.title)
      expect(last_response.body).to include(song2.title)
    end

    it 'does not show songs already in the set list' do
      login_as(user, band)
      set_list = create(:set_list, band: band)
      song1 = create(:song, bands: [band])
      song2 = create(:song, bands: [band])
      
      # Add song1 to the set list
      create(:set_list_song, set_list: set_list, song: song1)
      
      get "/set_lists/#{set_list.id}"
      
      expect(last_response).to be_ok
      # song1 should appear in the "Songs" section (already in set list)
      expect(last_response.body).to include(song1.title)
      # song2 should appear in the "Add Songs to Set List" section (available to add)
      expect(last_response.body).to include(song2.title)
      # song1 should NOT appear in the "Add Songs to Set List" section
      expect(last_response.body).to include('Add Songs to Set List')
      # Verify that song1 is not in the available songs section by checking the form
      expect(last_response.body).to include("song_id\" value=\"#{song2.id}\"")
      expect(last_response.body).not_to include("song_id\" value=\"#{song1.id}\"")
    end

    it 'returns 404 for non-existent set list' do
      login_as(user, band)
      expect { get '/set_lists/999' }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'GET /set_lists/:id/edit' do
    it 'displays the edit form for a set list' do
      login_as(user, band)
      set_list = create(:set_list, name: 'Edit Set List', band: band)
      
      get "/set_lists/#{set_list.id}/edit"
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Edit Set List')
      expect(last_response.body).to include('method="POST"')
      expect(last_response.body).to include('_method" value="PUT"')
    end

    it 'returns 404 for non-existent set list' do
      login_as(user, band)
      expect { get '/set_lists/999/edit' }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'PUT /set_lists/:id' do
    it 'updates a set list with valid attributes' do
      login_as(user, band)
      set_list = create(:set_list, name: 'Old Name', notes: 'Old notes', band: band)
      update_params = {
        name: 'New Name',
        notes: 'New notes',
        performance_date: '2024-12-25'
      }
      
      put "/set_lists/#{set_list.id}", update_params
      
      expect(last_response).to be_redirect
      follow_redirect!
      expect(last_response.body).to include('New Name')
      expect(last_response.body).to include('New notes')
    end

    it 'displays errors for invalid attributes' do
      login_as(user, band)
      set_list = create(:set_list, name: 'Valid Name', band: band)
      update_params = { name: '', band_id: set_list.band.id }
      
      put "/set_lists/#{set_list.id}", update_params
      
      expect(last_response).to be_ok
      expect(last_response.body).to include("can't be blank")
    end

    it 'returns 404 for non-existent set list' do
      login_as(user, band)
      expect { put '/set_lists/999', name: 'New Name' }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'DELETE /set_lists/:id' do
    it 'deletes a set list' do
      login_as(user, band)
      set_list = create(:set_list, name: 'Delete Set List', band: band)
      
      expect {
        delete "/set_lists/#{set_list.id}"
      }.to change(SetList, :count).by(-1)
      
      expect(last_response).to be_redirect
      expect(last_response.location).to end_with('/set_lists')
    end

    it 'returns 404 for non-existent set list' do
      login_as(user, band)
      expect { delete '/set_lists/999' }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'POST /set_lists/:id/songs' do
    it 'adds a song to the set list' do
      login_as(user, band)
      set_list = create(:set_list, band: band)
      song = create(:song, bands: [band])
      
      expect {
        post "/set_lists/#{set_list.id}/songs", song_id: song.id
      }.to change(SetListSong, :count).by(1)
      
      expect(last_response).to be_redirect
      follow_redirect!
      expect(last_response.body).to include(song.title)
    end

    it 'assigns the correct position to the new song' do
      login_as(user, band)
      set_list = create(:set_list, band: band)
      song1 = create(:song, bands: [band])
      song2 = create(:song, bands: [band])
      
      # Add first song
      post "/set_lists/#{set_list.id}/songs", song_id: song1.id
      # Add second song
      post "/set_lists/#{set_list.id}/songs", song_id: song2.id
      
      set_list.reload
      expect(set_list.set_list_songs.find_by(song: song1).position).to eq(1)
      expect(set_list.set_list_songs.find_by(song: song2).position).to eq(2)
    end
  end

  describe 'DELETE /set_lists/:set_list_id/songs/:song_id' do
    it 'removes a song from the set list' do
      login_as(user, band)
      set_list = create(:set_list, band: band)
      song = create(:song, bands: [band])
      set_list_song = create(:set_list_song, set_list: set_list, song: song)
      
      expect {
        delete "/set_lists/#{set_list.id}/songs/#{song.id}"
      }.to change(SetListSong, :count).by(-1)
      
      expect(last_response).to be_redirect
    end

    it 'reorders remaining songs after removal' do
      login_as(user, band)
      set_list = create(:set_list, band: band)
      song1 = create(:song, bands: [band])
      song2 = create(:song, bands: [band])
      song3 = create(:song, bands: [band])
      
      sls1 = create(:set_list_song, set_list: set_list, song: song1, position: 1)
      sls2 = create(:set_list_song, set_list: set_list, song: song2, position: 2)
      sls3 = create(:set_list_song, set_list: set_list, song: song3, position: 3)
      
      # Remove song2
      delete "/set_lists/#{set_list.id}/songs/#{song2.id}"
      
      expect(sls1.reload.position).to eq(1)
      expect(sls3.reload.position).to eq(2)
    end
  end

  describe 'GET /set_lists/:id/print' do
    it 'displays the print view for a set list' do
      login_as(user, band)
      set_list = create(:set_list, name: 'Print Set List', band: band)
      
      get "/set_lists/#{set_list.id}/print"
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Print Set List')
      expect(last_response.body).not_to include('layout') # Should not use layout
    end
  end

  describe 'POST /set_lists/:id/reorder' do
    it 'reorders songs in the set list' do
      login_as(user, band)
      set_list = create(:set_list, band: band)
      song1 = create(:song, bands: [band])
      song2 = create(:song, bands: [band])
      song3 = create(:song, bands: [band])
      
      sls1 = create(:set_list_song, set_list: set_list, song: song1, position: 1)
      sls2 = create(:set_list_song, set_list: set_list, song: song2, position: 2)
      sls3 = create(:set_list_song, set_list: set_list, song: song3, position: 3)
      
      # Reorder: song3, song1, song2
      post "/set_lists/#{set_list.id}/reorder", song_order: [song3.id, song1.id, song2.id]
      
      expect(last_response).to be_ok
      expect(JSON.parse(last_response.body)['success']).to be true
      
      expect(sls3.reload.position).to eq(1)
      expect(sls1.reload.position).to eq(2)
      expect(sls2.reload.position).to eq(3)
    end
  end

  describe 'POST /set_lists/:id/copy' do
    it 'copies a set list with all its songs' do
      login_as(user, band)
      set_list = create(:set_list, name: 'Original Set List', notes: 'Original notes', band: band)
      song1 = create(:song, bands: [band])
      song2 = create(:song, bands: [band])
      
      create(:set_list_song, set_list: set_list, song: song1, position: 1)
      create(:set_list_song, set_list: set_list, song: song2, position: 2)
      
      expect {
        post "/set_lists/#{set_list.id}/copy"
      }.to change(SetList, :count).by(1)
      
      expect(last_response).to be_redirect
      
      new_set_list = SetList.last
      expect(new_set_list.name).to eq("Copy - Original Set List")
      expect(new_set_list.notes).to eq("Original notes")
      expect(new_set_list.band).to eq(set_list.band)
      expect(new_set_list.songs.count).to eq(2)
      expect(new_set_list.songs).to include(song1, song2)
    end
  end
end 