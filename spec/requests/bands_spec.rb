require 'spec_helper'

RSpec.describe 'Bands API', type: :request do
  let(:user) { create(:user) }
  let(:band) { create(:band, owner: user) }
  
  before do
    create(:user_band, user: user, band: band)
  end
  describe 'GET /bands' do
    it 'returns a list of user bands' do
      login_as(user, band)
      band1 = create(:band, name: 'Band A', owner: user)
      band2 = create(:band, name: 'Band B', owner: user)
      
      # Associate the user with the new bands
      user.bands << band1
      user.bands << band2
      
      get '/bands'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Band A')
      expect(last_response.body).to include('Band B')
    end

    it 'displays bands in alphabetical order' do
      login_as(user, band)
      band_c = create(:band, name: 'C Band', owner: user)
      band_a = create(:band, name: 'A Band', owner: user)
      band_b = create(:band, name: 'B Band', owner: user)
      
      # Associate the user with the new bands
      user.bands << band_c
      user.bands << band_a
      user.bands << band_b
      
      get '/bands'
      
      expect(last_response).to be_ok
      body = last_response.body
      a_index = body.index('A Band')
      b_index = body.index('B Band')
      c_index = body.index('C Band')
      
      expect(a_index).to be < b_index
      expect(b_index).to be < c_index
    end
  end

  describe 'GET /bands/new' do
    it 'displays the new band form' do
      login_as(user, band)
      get '/bands/new'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('New Band')
      expect(last_response.body).to include('name')
      expect(last_response.body).to include('notes')
    end
  end

  describe 'POST /bands' do
    it 'creates a new band with valid attributes' do
      login_as(user, band)
      band_params = { name: 'New Band', notes: 'A great band' }
      
      expect {
        post '/bands', band: band_params
      }.to change(Band, :count).by(1)
      
      expect(last_response).to be_redirect
      follow_redirect!
      expect(last_response.body).to include('New Band')
    end

    it 'creates the first band and redirects to home' do
      # Create a user without any bands initially
      new_user = create(:user)
      login_as(new_user)
      band_params = { name: 'First Band', notes: 'The first band' }
      
      expect {
        post '/bands', band: band_params
      }.to change(Band, :count).by(1)
      
      expect(last_response).to be_redirect
      expect(last_response.location).to end_with('/')
    end

    it 'creates subsequent bands and redirects to bands index' do
      login_as(user, band)
      create(:band, name: 'Existing Band')
      band_params = { name: 'Second Band', notes: 'Another band' }
      
      expect {
        post '/bands', band: band_params
      }.to change(Band, :count).by(1)
      
      expect(last_response).to be_redirect
      expect(last_response.location).to end_with('/bands')
    end

    it 'displays errors for invalid attributes' do
      login_as(user, band)
      band_params = { name: '', notes: 'Invalid band' }
      
      expect {
        post '/bands', band: band_params
      }.not_to change(Band, :count)
      
      expect(last_response).to be_ok
      expect(last_response.body).to include("can't be blank")
    end

    it 'displays errors for duplicate band names' do
      login_as(user, band)
      create(:band, name: 'Duplicate Band')
      band_params = { name: 'Duplicate Band', notes: 'Another band' }
      
      expect {
        post '/bands', band: band_params
      }.not_to change(Band, :count)
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('has already been taken')
    end
  end

  describe 'GET /bands/:id' do
    it 'displays a specific band' do
      login_as(user, band)
      test_band = create(:band, name: 'Test Band', notes: 'Test notes', owner: user)
      user.bands << test_band
      
      get "/bands/#{test_band.id}"
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Test Band')
      expect(last_response.body).to include('Test notes')
    end

    it 'returns error for non-existent band' do
      login_as(user, band)
      expect {
        get '/bands/999'
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'GET /bands/:id/edit' do
    it 'displays the edit form for a band' do
      login_as(user, band)
      edit_band = create(:band, name: 'Edit Band', notes: 'Edit notes', owner: user)
      user.bands << edit_band
      
      get "/bands/#{edit_band.id}/edit"
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Edit Band')
      expect(last_response.body).to include('Edit notes')
      expect(last_response.body).to include('method="post"')
      expect(last_response.body).to include('_method" value="PUT"')
    end

    it 'returns error for non-existent band' do
      login_as(user, band)
      expect {
        get '/bands/999/edit'
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'PUT /bands/:id' do
    it 'updates a band with valid attributes' do
      login_as(user, band)
      update_band = create(:band, name: 'Old Name', notes: 'Old notes', owner: user)
      user.bands << update_band
      update_params = { name: 'New Name', notes: 'New notes' }
      
      put "/bands/#{update_band.id}", band: update_params
      
      expect(last_response).to be_redirect
      follow_redirect!
      expect(last_response.body).to include('New Name')
      expect(last_response.body).to include('New notes')
    end

    it 'displays errors for invalid attributes' do
      login_as(user, band)
      update_band = create(:band, name: 'Valid Name', owner: user)
      user.bands << update_band
      update_params = { name: '', notes: 'Valid notes' }
      
      put "/bands/#{update_band.id}", band: update_params
      
      expect(last_response).to be_ok
      expect(last_response.body).to include("can't be blank")
    end

    it 'returns error for non-existent band' do
      login_as(user, band)
      expect {
        put '/bands/999', band: { name: 'New Name' }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'DELETE /bands/:id' do
    it 'deletes a band' do
      login_as(user, band)
      delete_band = create(:band, name: 'Delete Band', owner: user)
      user.bands << delete_band
      
      expect {
        delete "/bands/#{delete_band.id}"
      }.to change(Band, :count).by(-1)
      
      expect(last_response).to be_redirect
      expect(last_response.location).to end_with('/bands')
    end

    it 'returns error for non-existent band' do
      login_as(user, band)
      expect {
        delete '/bands/999'
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end 