require 'spec_helper'

RSpec.describe 'Blackout Dates API', type: :request do
  let(:user) { create(:user) }
  let(:band) { create(:band, owner: user) }
  
  before do
    create(:user_band, user: user, band: band)
  end
  
  def login_as(user, band = nil)
    post '/test_auth', user_id: user.id, band_id: band&.id
  end

  describe 'POST /blackout_dates' do
    it 'requires authentication' do
      post '/blackout_dates', date: '2025-12-25', reason: 'Holiday'
      
      expect(last_response).to be_redirect
      expect(last_response.location).to end_with('/login')
    end

    it 'creates a blackout date with valid data' do
      login_as(user, band)
      
      expect {
        post '/blackout_dates', date: '2025-12-25', reason: 'Holiday'
      }.to change(BlackoutDate, :count).by(1)
      
      expect(last_response.status).to eq(200)
      response_data = JSON.parse(last_response.body)
      expect(response_data['success']).to be true
      expect(response_data['blackout_date']).to eq('2025-12-25')
      expect(response_data['reason']).to eq('Holiday')
    end

    it 'creates blackout date without reason' do
      login_as(user, band)
      
      expect {
        post '/blackout_dates', date: '2025-12-25'
      }.to change(BlackoutDate, :count).by(1)
      
      expect(last_response.status).to eq(200)
      response_data = JSON.parse(last_response.body)
      expect(response_data['success']).to be true
      expect(response_data['reason']).to be_nil
    end

    it 'returns error when date is missing' do
      login_as(user, band)
      
      post '/blackout_dates', reason: 'Holiday'
      
      expect(last_response.status).to eq(200)
      response_data = JSON.parse(last_response.body)
      expect(response_data['error']).to eq('Date is required')
    end

    it 'returns error when date is empty string' do
      login_as(user, band)
      
      post '/blackout_dates', date: '', reason: 'Holiday'
      
      expect(last_response.status).to eq(200)
      response_data = JSON.parse(last_response.body)
      expect(response_data['error']).to eq('Date is required')
    end

    it 'returns error when date is invalid' do
      login_as(user, band)
      
      post '/blackout_dates', date: 'invalid-date', reason: 'Holiday'
      
      expect(last_response.status).to eq(200)
      response_data = JSON.parse(last_response.body)
      expect(response_data['error']).to eq('Invalid date format')
    end

    it 'returns error when blackout date already exists' do
      login_as(user, band)
      create(:blackout_date, user: user, blackout_date: Date.parse('2025-12-25'))
      
      post '/blackout_dates', date: '2025-12-25', reason: 'Holiday'
      
      expect(last_response.status).to eq(200)
      response_data = JSON.parse(last_response.body)
      expect(response_data['error']).to eq('Blackout date already exists')
    end

    it 'handles various date formats' do
      login_as(user, band)
      
      # Test ISO format
      post '/blackout_dates', date: '2025-12-25', reason: 'Holiday'
      expect(last_response.status).to eq(200)
      
      # Test other formats
      post '/blackout_dates', date: 'Dec 25, 2024', reason: 'Holiday'
      expect(last_response.status).to eq(200)
    end

    it 'handles whitespace in date parameter' do
      login_as(user, band)
      
      post '/blackout_dates', date: '  2025-12-25  ', reason: 'Holiday'
      
      expect(last_response.status).to eq(200)
      response_data = JSON.parse(last_response.body)
      expect(response_data['success']).to be true
    end
  end

  describe 'POST /blackout_dates/bulk' do
    it 'requires authentication' do
      post '/blackout_dates/bulk', dates: '2025-12-25,2025-12-26', reason: 'Holiday'
      
      expect(last_response).to be_redirect
      expect(last_response.location).to end_with('/login')
    end

    it 'creates multiple blackout dates' do
      login_as(user, band)
      
      expect {
        post '/blackout_dates/bulk', dates: '2025-12-25,2025-12-26', reason: 'Holiday'
      }.to change(BlackoutDate, :count).by(2)
      
      expect(last_response.status).to eq(200)
      response_data = JSON.parse(last_response.body)
      expect(response_data['success']).to be true
      expect(response_data['created_count']).to eq(2)
    end

    it 'creates blackout dates without reason' do
      login_as(user, band)
      
      expect {
        post '/blackout_dates/bulk', dates: '2025-12-25,2025-12-26'
      }.to change(BlackoutDate, :count).by(2)
      
      expect(last_response.status).to eq(200)
      response_data = JSON.parse(last_response.body)
      expect(response_data['success']).to be true
    end

    it 'handles partial failures gracefully' do
      login_as(user, band)
      create(:blackout_date, user: user, blackout_date: Date.parse('2025-12-25'))
      
      post '/blackout_dates/bulk', dates: '2025-12-25,2025-12-26,invalid-date', reason: 'Holiday'
      
      expect(last_response.status).to eq(200)
      response_data = JSON.parse(last_response.body)
      expect(response_data['success']).to be false
      expect(response_data['created_count']).to eq(1)
      expect(response_data['errors']).not_to be_empty
    end

    it 'skips empty date strings' do
      login_as(user, band)
      
      post '/blackout_dates/bulk', dates: '2025-12-25,,2025-12-26,', reason: 'Holiday'
      
      expect(last_response.status).to eq(200)
      response_data = JSON.parse(last_response.body)
      expect(response_data['success']).to be true
      expect(response_data['created_count']).to eq(2)
    end

    it 'returns error when dates parameter is missing' do
      login_as(user, band)
      
      post '/blackout_dates/bulk', reason: 'Holiday'
      
      expect(last_response.status).to eq(200)
      response_data = JSON.parse(last_response.body)
      expect(response_data['error']).to eq('Dates are required')
    end

    it 'handles single date' do
      login_as(user, band)
      
      expect {
        post '/blackout_dates/bulk', dates: '2025-12-25', reason: 'Holiday'
      }.to change(BlackoutDate, :count).by(1)
      
      expect(last_response.status).to eq(200)
      response_data = JSON.parse(last_response.body)
      expect(response_data['success']).to be true
      expect(response_data['created_count']).to eq(1)
    end
  end

  describe 'DELETE /blackout_dates/bulk' do
    it 'requires authentication' do
      delete '/blackout_dates/bulk', dates: '2025-12-25,2025-12-26'
      
      expect(last_response).to be_redirect
      expect(last_response.location).to end_with('/login')
    end

    it 'deletes multiple blackout dates' do
      login_as(user, band)
      blackout1 = create(:blackout_date, user: user, blackout_date: Date.parse('2025-12-25'))
      blackout2 = create(:blackout_date, user: user, blackout_date: Date.parse('2025-12-26'))
      
      expect {
        delete '/blackout_dates/bulk', dates: '2025-12-25,2025-12-26'
      }.to change(BlackoutDate, :count).by(-2)
      
      expect(last_response.status).to eq(200)
      response_data = JSON.parse(last_response.body)
      expect(response_data['success']).to be true
      expect(response_data['deleted_count']).to eq(2)
    end

    it 'handles non-existent dates gracefully' do
      login_as(user, band)
      
      delete '/blackout_dates/bulk', dates: '2025-12-25,2025-12-26'
      
      expect(last_response.status).to eq(200)
      response_data = JSON.parse(last_response.body)
      expect(response_data['success']).to be true
      expect(response_data['deleted_count']).to eq(0)
    end

    it 'skips invalid dates silently' do
      login_as(user, band)
      blackout = create(:blackout_date, user: user, blackout_date: Date.parse('2025-12-25'))
      
      delete '/blackout_dates/bulk', dates: '2025-12-25,invalid-date,2025-12-26'
      
      expect(last_response.status).to eq(200)
      response_data = JSON.parse(last_response.body)
      expect(response_data['success']).to be true
      expect(response_data['deleted_count']).to eq(1)
    end

    it 'handles empty date strings' do
      login_as(user, band)
      blackout = create(:blackout_date, user: user, blackout_date: Date.parse('2025-12-25'))
      
      delete '/blackout_dates/bulk', dates: '2025-12-25,,2025-12-26,'
      
      expect(last_response.status).to eq(200)
      response_data = JSON.parse(last_response.body)
      expect(response_data['success']).to be true
      expect(response_data['deleted_count']).to eq(1)
    end
  end

  describe 'DELETE /blackout_dates/:date' do
    it 'requires authentication' do
      delete '/blackout_dates/2025-12-25'
      
      expect(last_response).to be_redirect
      expect(last_response.location).to end_with('/login')
    end

    it 'deletes a blackout date' do
      login_as(user, band)
      blackout = create(:blackout_date, user: user, blackout_date: Date.parse('2025-12-25'))
      
      expect {
        delete '/blackout_dates/2025-12-25'
      }.to change(BlackoutDate, :count).by(-1)
      
      expect(last_response.status).to eq(200)
      response_data = JSON.parse(last_response.body)
      expect(response_data['success']).to be true
      expect(response_data['message']).to eq('Blackout date removed')
    end

    it 'returns error when blackout date not found' do
      login_as(user, band)
      
      delete '/blackout_dates/2025-12-25'
      
      expect(last_response.status).to eq(200)
      response_data = JSON.parse(last_response.body)
      expect(response_data['error']).to eq('Blackout date not found')
    end

    it 'handles invalid date format' do
      login_as(user, band)
      
      delete '/blackout_dates/invalid-date'
      
      expect(last_response.status).to eq(200)
      response_data = JSON.parse(last_response.body)
      expect(response_data['error']).to eq('Invalid date format')
    end

    it 'handles empty date parameter' do
      login_as(user, band)
      
      delete '/blackout_dates/'
      
      expect(last_response.status).to eq(404) # Route not found
    end

    it 'handles whitespace in date parameter' do
      login_as(user, band)
      blackout = create(:blackout_date, user: user, blackout_date: Date.parse('2025-12-25'))
      
      delete "/blackout_dates/#{URI.encode_www_form_component('  2025-12-25  ')}"
      
      expect(last_response.status).to eq(200)
      response_data = JSON.parse(last_response.body)
      expect(response_data['success']).to be true
    end
  end
end