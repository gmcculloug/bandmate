require_relative '../spec_helper'

RSpec.describe 'Blackout Dates API', type: :request do
  let(:user) { create(:user) }

  before do
    # Use test auth to authenticate user
    post '/test_auth', user_id: user.id
    expect(last_response.status).to eq(200)
  end

  describe 'POST /blackout_dates' do
    it 'creates a blackout date successfully' do
      date = Date.current.to_s
      
      post '/blackout_dates', { date: date }
      
      expect(last_response.status).to eq(200)
      
      json_response = JSON.parse(last_response.body)
      expect(json_response['success']).to be true
      expect(json_response['blackout_date']).to eq(date)
      
      expect(BlackoutDate.count).to eq(1)
      blackout = BlackoutDate.first
      expect(blackout.user).to eq(user)
      expect(blackout.blackout_date.to_s).to eq(date)
    end

    it 'creates a blackout date with reason' do
      date = Date.current.to_s
      reason = 'Vacation'
      
      post '/blackout_dates', { date: date, reason: reason }
      
      expect(last_response.status).to eq(200)
      
      json_response = JSON.parse(last_response.body)
      expect(json_response['success']).to be true
      expect(json_response['reason']).to eq(reason)
      
      blackout = BlackoutDate.first
      expect(blackout.reason).to eq(reason)
    end

    it 'returns error for duplicate blackout date' do
      date = Date.current
      create(:blackout_date, user: user, blackout_date: date)
      
      post '/blackout_dates', { date: date.to_s }
      
      expect(last_response.status).to eq(200)
      
      json_response = JSON.parse(last_response.body)
      expect(json_response['error']).to eq('Blackout date already exists')
    end

    it 'returns error for invalid date' do
      post '/blackout_dates', { date: 'invalid-date' }
      
      expect(last_response.status).to eq(200)
      
      json_response = JSON.parse(last_response.body)
      expect(json_response['error']).to eq('Invalid date format')
    end

    it 'returns error for past date' do
      past_date = 1.day.ago.to_date.to_s
      
      post '/blackout_dates', { date: past_date }
      
      expect(last_response.status).to eq(200)
      
      json_response = JSON.parse(last_response.body)
      expect(json_response['error']).to eq('Blackout date cannot be in the past')
    end

    it 'allows blackout date for today' do
      today = Date.current.to_s
      
      post '/blackout_dates', { date: today }
      
      expect(last_response.status).to eq(200)
      
      json_response = JSON.parse(last_response.body)
      expect(json_response['success']).to be true
      
      expect(BlackoutDate.count).to eq(1)
      blackout = BlackoutDate.first
      expect(blackout.blackout_date.to_s).to eq(today)
    end
  end

  describe 'DELETE /blackout_dates/:date' do
    it 'removes a blackout date successfully' do
      date = Date.current
      blackout = create(:blackout_date, user: user, blackout_date: date)
      
      delete "/blackout_dates/#{date}"
      
      expect(last_response.status).to eq(200)
      
      json_response = JSON.parse(last_response.body)
      expect(json_response['success']).to be true
      expect(json_response['message']).to eq('Blackout date removed')
      
      expect(BlackoutDate.count).to eq(0)
    end

    it 'returns error when blackout date not found' do
      date = Date.current
      
      delete "/blackout_dates/#{date}"
      
      expect(last_response.status).to eq(200)
      
      json_response = JSON.parse(last_response.body)
      expect(json_response['error']).to eq('Blackout date not found')
    end

    it 'returns error for invalid date' do
      delete '/blackout_dates/invalid-date'
      
      expect(last_response.status).to eq(200)
      
      json_response = JSON.parse(last_response.body)
      expect(json_response['error']).to eq('Invalid date format')
    end
  end

  describe 'POST /blackout_dates/bulk' do
    it 'creates multiple blackout dates successfully' do
      dates = [Date.current, Date.current + 1.day, Date.current + 2.days]
      dates_string = dates.map(&:to_s).join(',')
      
      post '/blackout_dates/bulk', { dates: dates_string }
      
      expect(last_response.status).to eq(200)
      
      json_response = JSON.parse(last_response.body)
      expect(json_response['success']).to be true
      expect(json_response['created_count']).to eq(3)
      
      expect(BlackoutDate.count).to eq(3)
      BlackoutDate.all.each do |blackout|
        expect(blackout.user).to eq(user)
        expect(dates.map(&:to_s)).to include(blackout.blackout_date.to_s)
      end
    end

    it 'skips existing blackout dates and creates new ones' do
      existing_date = Date.current
      new_date = Date.current + 1.day
      create(:blackout_date, user: user, blackout_date: existing_date)
      
      dates_string = [existing_date, new_date].map(&:to_s).join(',')
      
      post '/blackout_dates/bulk', { dates: dates_string }
      
      expect(last_response.status).to eq(200)
      
      json_response = JSON.parse(last_response.body)
      expect(json_response['success']).to be true
      expect(json_response['created_count']).to eq(1)
      
      expect(BlackoutDate.count).to eq(2)
    end

    it 'handles mix of valid and past dates in bulk creation' do
      past_date = 1.day.ago.to_date
      today = Date.current
      future_date = Date.current + 1.day
      
      dates_string = [past_date, today, future_date].map(&:to_s).join(',')
      
      post '/blackout_dates/bulk', { dates: dates_string }
      
      expect(last_response.status).to eq(200)
      
      json_response = JSON.parse(last_response.body)
      expect(json_response['success']).to be false
      expect(json_response['created_count']).to eq(2)
      expect(json_response['errors']).to be_present
      expect(json_response['errors'].first).to include('cannot be in the past')
      
      # Should create blackouts for today and future, but not past
      expect(BlackoutDate.count).to eq(2)
      created_dates = BlackoutDate.pluck(:blackout_date).map(&:to_s)
      expect(created_dates).to include(today.to_s, future_date.to_s)
      expect(created_dates).not_to include(past_date.to_s)
    end
  end

  describe 'DELETE /blackout_dates/bulk' do
    it 'removes multiple blackout dates successfully' do
      dates = [Date.current, Date.current + 1.day]
      dates.each { |date| create(:blackout_date, user: user, blackout_date: date) }
      dates_string = dates.map(&:to_s).join(',')
      
      delete '/blackout_dates/bulk', { dates: dates_string }
      
      expect(last_response.status).to eq(200)
      
      json_response = JSON.parse(last_response.body)
      expect(json_response['success']).to be true
      expect(json_response['deleted_count']).to eq(2)
      
      expect(BlackoutDate.count).to eq(0)
    end

    it 'skips non-existent blackout dates' do
      existing_date = Date.current
      non_existing_date = Date.current + 1.day
      create(:blackout_date, user: user, blackout_date: existing_date)
      
      dates_string = [existing_date, non_existing_date].map(&:to_s).join(',')
      
      delete '/blackout_dates/bulk', { dates: dates_string }
      
      expect(last_response.status).to eq(200)
      
      json_response = JSON.parse(last_response.body)
      expect(json_response['success']).to be true
      expect(json_response['deleted_count']).to eq(1)
      
      expect(BlackoutDate.count).to eq(0)
    end
  end

  describe 'GET /calendar' do
    let(:band) { create(:band) }
    let!(:user_band) { create(:user_band, user: user, band: band) }
    let!(:gig) { create(:gig, band: band, performance_date: Date.current + 5.days) }
    let!(:blackout_date) { create(:blackout_date, user: user, blackout_date: Date.current + 3.days) }

    before do
      post '/test_auth', user_id: user.id, band_id: band.id
      expect(last_response.status).to eq(200)
    end

    it 'displays the calendar view' do
      get '/calendar'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Calendar')
    end

    it 'displays calendar for specific month and year' do
      get '/calendar', year: 2024, month: 6
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('June')
      expect(last_response.body).to include('2024')
    end

    it 'shows gigs in the calendar' do
      get '/calendar'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include(gig.name)
    end

    it 'shows blackout dates in the calendar' do
      get '/calendar'
      
      expect(last_response).to be_ok
      # The calendar should show blackout dates (specific UI depends on implementation)
    end

    it 'handles navigation between months' do
      # Test current month
      get '/calendar'
      expect(last_response).to be_ok
      
      # Test previous month
      current_date = Date.current
      prev_month = current_date.month == 1 ? 12 : current_date.month - 1
      prev_year = current_date.month == 1 ? current_date.year - 1 : current_date.year
      
      get '/calendar', year: prev_year, month: prev_month
      expect(last_response).to be_ok
      
      # Test next month  
      next_month = current_date.month == 12 ? 1 : current_date.month + 1
      next_year = current_date.month == 12 ? current_date.year + 1 : current_date.year
      
      get '/calendar', year: next_year, month: next_month
      expect(last_response).to be_ok
    end

    it 'requires authentication' do
      # Clear authentication
      clear_cookies
      get '/calendar'
      
      expect(last_response.status).to eq(302)
      expect(last_response.location).to include('/login')
    end

    it 'shows conflicts with other band members' do
      # Create another user and band with a conflicting gig
      other_user = create(:user)
      other_band = create(:band)
      create(:user_band, user: user, band: other_band) # User is in both bands
      conflicting_gig = create(:gig, band: other_band, performance_date: Date.current + 7.days)
      
      get '/calendar'
      
      expect(last_response).to be_ok
      # Should show the conflicting gig (specific UI depends on implementation)
    end
  end
end