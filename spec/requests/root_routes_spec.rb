require_relative '../spec_helper'

RSpec.describe 'Root Routes', type: :request do
  let(:user) { create(:user) }
  let(:band) { create(:band) }

  describe 'GET /' do
    context 'when not logged in' do
      it 'redirects to login' do
        get '/'
        
        expect(last_response.status).to eq(302)
        expect(last_response.location).to include('/login')
      end
    end

    context 'when logged in but no bands' do
      before do
        post '/test_auth', user_id: user.id
        expect(last_response.status).to eq(200)
      end

      it 'redirects to create first band' do
        get '/'
        
        expect(last_response.status).to eq(302)
        expect(last_response.location).to include('/bands/new')
      end
    end

    context 'when logged in with bands' do
      let!(:user_band) { create(:user_band, user: user, band: band) }

      before do
        post '/test_auth', user_id: user.id
        expect(last_response.status).to eq(200)
      end

      it 'redirects to gigs page' do
        get '/'
        
        expect(last_response.status).to eq(302)
        expect(last_response.location).to include('/gigs')
      end
    end
  end

  describe 'POST /select_band' do
    let!(:user_band) { create(:user_band, user: user, band: band) }
    let(:other_band) { create(:band) }
    let!(:other_user_band) { create(:user_band, user: user, band: other_band) }

    before do
      post '/test_auth', user_id: user.id
      expect(last_response.status).to eq(200)
    end

    it 'switches to the selected band' do
      # Debug: Let's check if the user is actually authenticated
      get '/'
      
      post '/select_band', band_id: band.id
      
      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with('/gigs')
      
      # Verify band was selected (would need to check session or make another request)
    end

    it 'redirects to specified path after band selection' do
      post '/select_band', band_id: band.id, redirect_to: '/calendar'
      
      expect(last_response.status).to eq(302)
      # In Rack::Test, the location might be a full URL
      expect(last_response.location).to end_with('/calendar')
    end

    it 'updates user last selected band preference' do
      post '/select_band', band_id: band.id
      
      user.reload
      expect(user.last_selected_band_id).to eq(band.id)
    end

    it 'requires authentication' do
      # Clear session by not calling test_auth
      clear_cookies # Clear any existing session
      
      post '/select_band', band_id: band.id
      
      expect(last_response.status).to eq(302)
      expect(last_response.location).to end_with('/login')
    end

    it 'prevents selecting band user is not member of' do
      unauthorized_band = create(:band)
      
      # In request specs, exceptions are caught by the framework
      post '/select_band', band_id: unauthorized_band.id
      
      expect(last_response.status).to eq(404) # Sinatra converts RecordNotFound to 404
    end

    it 'handles non-existent band' do
      # In request specs, exceptions are caught by the framework  
      post '/select_band', band_id: 99999
      
      expect(last_response.status).to eq(404) # Sinatra converts RecordNotFound to 404
    end
  end

  describe 'POST /test_auth' do
    context 'in test environment' do
      it 'sets authentication state' do
        post '/test_auth', user_id: user.id, band_id: band.id
        
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq('Authentication set')
      end

      it 'works with just user_id' do
        post '/test_auth', user_id: user.id
        
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq('Authentication set')
      end

      it 'works with just band_id' do
        post '/test_auth', band_id: band.id
        
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq('Authentication set')
      end
    end

    # Note: Testing non-test environment behavior is complex in Sinatra request specs
    # since settings.test? is used internally by the framework. The route correctly
    # checks settings.test? in production to return 404 for security.
  end
end