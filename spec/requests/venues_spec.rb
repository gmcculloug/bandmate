require 'spec_helper'

RSpec.describe 'Venues API', type: :request do
  describe 'GET /venues' do
    it 'returns a list of all venues' do
      venue1 = create(:venue, name: 'Venue A')
      venue2 = create(:venue, name: 'Venue B')
      
      get '/venues'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Venue A')
      expect(last_response.body).to include('Venue B')
    end

    it 'displays venues in alphabetical order' do
      venue_c = create(:venue, name: 'C Venue')
      venue_a = create(:venue, name: 'A Venue')
      venue_b = create(:venue, name: 'B Venue')
      
      get '/venues'
      
      expect(last_response).to be_ok
      body = last_response.body
      a_index = body.index('A Venue')
      b_index = body.index('B Venue')
      c_index = body.index('C Venue')
      
      expect(a_index).to be < b_index
      expect(b_index).to be < c_index
    end
  end

  describe 'GET /venues/new' do
    it 'displays the new venue form' do
      get '/venues/new'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('New Venue')
      expect(last_response.body).to include('name')
      expect(last_response.body).to include('location')
      expect(last_response.body).to include('contact_name')
      expect(last_response.body).to include('phone_number')
    end
  end

  describe 'POST /venues' do
    it 'creates a new venue with valid attributes' do
      venue_params = {
        name: 'New Venue',
        location: '123 Main St, City, State',
        contact_name: 'John Doe',
        phone_number: '555-1234',
        notes: 'A great venue'
      }
      
      expect {
        post '/venues', venue: venue_params
      }.to change(Venue, :count).by(1)
      
      expect(last_response).to be_redirect
      follow_redirect!
      expect(last_response.body).to include('New Venue')
    end

    it 'displays errors for invalid attributes' do
      venue_params = {
        name: '',
        location: '',
        contact_name: '',
        phone_number: ''
      }
      
      expect {
        post '/venues', venue: venue_params
      }.not_to change(Venue, :count)
      
      expect(last_response).to be_ok
      expect(last_response.body).to include("can't be blank")
    end
  end

  describe 'GET /venues/:id' do
    it 'displays a specific venue' do
      venue = create(:venue, name: 'Test Venue', location: 'Test Location')
      
      get "/venues/#{venue.id}"
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Test Venue')
      expect(last_response.body).to include('Test Location')
    end

    it 'returns 404 for non-existent venue' do
      get '/venues/999'
      
      expect(last_response).to be_not_found
    end
  end

  describe 'GET /venues/:id/edit' do
    it 'displays the edit form for a venue' do
      venue = create(:venue, name: 'Edit Venue', location: 'Edit Location')
      
      get "/venues/#{venue.id}/edit"
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Edit Venue')
      expect(last_response.body).to include('Edit Location')
      expect(last_response.body).to include('method="post"')
      expect(last_response.body).to include('_method" value="put"')
    end

    it 'returns 404 for non-existent venue' do
      get '/venues/999/edit'
      
      expect(last_response).to be_not_found
    end
  end

  describe 'PUT /venues/:id' do
    it 'updates a venue with valid attributes' do
      venue = create(:venue, name: 'Old Name', location: 'Old Location')
      update_params = {
        name: 'New Name',
        location: 'New Location',
        contact_name: 'New Contact',
        phone_number: '555-5678'
      }
      
      put "/venues/#{venue.id}", venue: update_params
      
      expect(last_response).to be_redirect
      follow_redirect!
      expect(last_response.body).to include('New Name')
      expect(last_response.body).to include('New Location')
    end

    it 'displays errors for invalid attributes' do
      venue = create(:venue, name: 'Valid Name')
      update_params = { name: '', location: 'Valid Location' }
      
      put "/venues/#{venue.id}", venue: update_params
      
      expect(last_response).to be_ok
      expect(last_response.body).to include("can't be blank")
    end

    it 'returns 404 for non-existent venue' do
      put '/venues/999', venue: { name: 'New Name' }
      
      expect(last_response).to be_not_found
    end
  end

  describe 'DELETE /venues/:id' do
    it 'deletes a venue' do
      venue = create(:venue, name: 'Delete Venue')
      
      expect {
        delete "/venues/#{venue.id}"
      }.to change(Venue, :count).by(-1)
      
      expect(last_response).to be_redirect
      expect(last_response.location).to end_with('/venues')
    end

    it 'returns 404 for non-existent venue' do
      delete '/venues/999'
      
      expect(last_response).to be_not_found
    end
  end
end 