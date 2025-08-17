require 'spec_helper'

RSpec.describe 'Bands API', type: :request do
  describe 'GET /bands' do
    it 'returns a list of all bands' do
      band1 = create(:band, name: 'Band A')
      band2 = create(:band, name: 'Band B')
      
      get '/bands'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Band A')
      expect(last_response.body).to include('Band B')
    end

    it 'displays bands in alphabetical order' do
      band_c = create(:band, name: 'C Band')
      band_a = create(:band, name: 'A Band')
      band_b = create(:band, name: 'B Band')
      
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
      get '/bands/new'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('New Band')
      expect(last_response.body).to include('name')
      expect(last_response.body).to include('notes')
    end
  end

  describe 'POST /bands' do
    it 'creates a new band with valid attributes' do
      band_params = { name: 'New Band', notes: 'A great band' }
      
      expect {
        post '/bands', band: band_params
      }.to change(Band, :count).by(1)
      
      expect(last_response).to be_redirect
      follow_redirect!
      expect(last_response.body).to include('New Band')
    end

    it 'creates the first band and redirects to home' do
      band_params = { name: 'First Band', notes: 'The first band' }
      
      expect {
        post '/bands', band: band_params
      }.to change(Band, :count).by(1)
      
      expect(last_response).to be_redirect
      expect(last_response.location).to end_with('/')
    end

    it 'creates subsequent bands and redirects to bands index' do
      create(:band, name: 'Existing Band')
      band_params = { name: 'Second Band', notes: 'Another band' }
      
      expect {
        post '/bands', band: band_params
      }.to change(Band, :count).by(1)
      
      expect(last_response).to be_redirect
      expect(last_response.location).to end_with('/bands')
    end

    it 'displays errors for invalid attributes' do
      band_params = { name: '', notes: 'Invalid band' }
      
      expect {
        post '/bands', band: band_params
      }.not_to change(Band, :count)
      
      expect(last_response).to be_ok
      expect(last_response.body).to include("can't be blank")
    end

    it 'displays errors for duplicate band names' do
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
      band = create(:band, name: 'Test Band', notes: 'Test notes')
      
      get "/bands/#{band.id}"
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Test Band')
      expect(last_response.body).to include('Test notes')
    end

    it 'returns 404 for non-existent band' do
      get '/bands/999'
      
      expect(last_response).to be_not_found
    end
  end

  describe 'GET /bands/:id/edit' do
    it 'displays the edit form for a band' do
      band = create(:band, name: 'Edit Band', notes: 'Edit notes')
      
      get "/bands/#{band.id}/edit"
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Edit Band')
      expect(last_response.body).to include('Edit notes')
      expect(last_response.body).to include('method="post"')
      expect(last_response.body).to include('_method" value="put"')
    end

    it 'returns 404 for non-existent band' do
      get '/bands/999/edit'
      
      expect(last_response).to be_not_found
    end
  end

  describe 'PUT /bands/:id' do
    it 'updates a band with valid attributes' do
      band = create(:band, name: 'Old Name', notes: 'Old notes')
      update_params = { name: 'New Name', notes: 'New notes' }
      
      put "/bands/#{band.id}", band: update_params
      
      expect(last_response).to be_redirect
      follow_redirect!
      expect(last_response.body).to include('New Name')
      expect(last_response.body).to include('New notes')
    end

    it 'displays errors for invalid attributes' do
      band = create(:band, name: 'Valid Name')
      update_params = { name: '', notes: 'Valid notes' }
      
      put "/bands/#{band.id}", band: update_params
      
      expect(last_response).to be_ok
      expect(last_response.body).to include("can't be blank")
    end

    it 'returns 404 for non-existent band' do
      put '/bands/999', band: { name: 'New Name' }
      
      expect(last_response).to be_not_found
    end
  end

  describe 'DELETE /bands/:id' do
    it 'deletes a band' do
      band = create(:band, name: 'Delete Band')
      
      expect {
        delete "/bands/#{band.id}"
      }.to change(Band, :count).by(-1)
      
      expect(last_response).to be_redirect
      expect(last_response.location).to end_with('/bands')
    end

    it 'returns 404 for non-existent band' do
      delete '/bands/999'
      
      expect(last_response).to be_not_found
    end
  end
end 