require 'spec_helper'

RSpec.describe 'Practice Routes', type: :request do
  let(:user) { create(:user) }
  let(:band) { create(:band) }
  let(:practice) { create(:practice, band: band, created_by_user: user) }

  shared_context 'logged in user' do
    before do
      # Set up user-band association
      band.users << user
      # Simulate login
      login_as(user, band)
    end
  end

  describe 'GET /practices' do
    context 'when logged in' do
      include_context 'logged in user'
      it 'returns success' do
        get '/practices'
        expect(last_response).to be_ok
      end

      it 'displays practices' do
        practice # create the practice
        get '/practices'
        expect(last_response.body).to include('Practice Scheduling')
        expect(last_response.body).to include(practice.formatted_week_range)
      end

      it 'shows empty state when no practices exist' do
        get '/practices'
        expect(last_response.body).to include('No Practice Sessions Yet')
        expect(last_response.body).to include('Schedule your first practice session')
      end
    end

    context 'when not logged in' do
      it 'redirects to login' do
        get '/practices'
        expect(last_response).to be_redirect
        expect(last_response.location).to include('/login')
      end
    end
  end

  describe 'GET /practices/new' do
    context 'when logged in' do
      include_context 'logged in user'

      it 'returns success' do
        get '/practices/new'
        expect(last_response).to be_ok
      end

      it 'displays the new practice form' do
        get '/practices/new'
        expect(last_response.body).to include('Schedule Practice Session')
        expect(last_response.body).to include('practice_title')
        expect(last_response.body).to include('week_start_date')
      end
    end

    context 'when not logged in' do
      it 'redirects to login' do
        get '/practices/new'
        expect(last_response).to be_redirect
        expect(last_response.location).to include('/login')
      end
    end
  end

  describe 'POST /practices' do
    let(:valid_params) do
      {
        title: 'Weekly Practice',
        week_start_date: Date.current.beginning_of_week(:sunday).to_s,
        description: 'Practice session for upcoming gig'
      }
    end

    context 'when logged in' do
      include_context 'logged in user'

      it 'creates a new practice with valid params' do
        expect {
          post '/practices', valid_params
        }.to change(Practice, :count).by(1)

        practice = Practice.last
        expect(practice.title).to eq('Weekly Practice')
        expect(practice.band).to eq(band)
        expect(practice.created_by_user).to eq(user)
        expect(last_response).to be_redirect
        expect(last_response.location).to include("/practices/#{practice.id}")
      end

      it 'adjusts week_start_date to Sunday' do
        # Use a Wednesday date
        wednesday = Date.current.beginning_of_week(:sunday) + 3.days
        post '/practices',valid_params.merge(week_start_date: wednesday.to_s)

        practice = Practice.last
        expect(practice.week_start_date.wday).to eq(0) # Sunday
        expect(practice.week_start_date).to eq(wednesday.beginning_of_week(:sunday))
      end

      it 'handles invalid date format' do
        post '/practices',valid_params.merge(week_start_date: 'invalid-date')
        expect(last_response.body).to include('Invalid date format')
      end

      it 'does not create practice with duplicate week for same band' do
        create(:practice, band: band, week_start_date: Date.current.beginning_of_week(:sunday))

        post '/practices',valid_params
        expect(last_response.body).to include('Week start date already has a practice scheduled for this week')
      end
    end

    context 'when not logged in' do
      it 'redirects to login' do
        post '/practices',valid_params
        expect(last_response).to be_redirect
        expect(last_response.location).to include('/login')
      end
    end
  end

  describe 'GET /practices/:id' do
    context 'when logged in' do
      include_context 'logged in user'

      it 'returns success' do
        get "/practices/#{practice.id}"
        expect(last_response).to be_ok
      end

      it 'displays practice details' do
        get "/practices/#{practice.id}"
        expect(last_response.body).to include(practice.title)
        expect(last_response.body).to include(practice.formatted_week_range)
        expect(last_response.body).to include('Your Availability')
      end

      it 'shows finalized status when practice is finalized' do
        practice.update!(status: 'finalized')
        get "/practices/#{practice.id}"
        expect(last_response.body).to include('finalized')
        expect(last_response.body).to include('No further changes can be made')
      end

      it 'redirects if practice does not exist' do
        get '/practices/99999'
        expect(last_response).to be_redirect
        expect(last_response.location).to include('/practices')
      end

      it 'redirects if practice belongs to different band' do
        other_band = create(:band)
        other_practice = create(:practice, band: other_band)

        get "/practices/#{other_practice.id}"
        expect(last_response).to be_redirect
        expect(last_response.location).to include('/practices')
      end
    end

    context 'when not logged in' do
      it 'redirects to login' do
        get "/practices/#{practice.id}"
        expect(last_response).to be_redirect
        expect(last_response.location).to include('/login')
      end
    end
  end

  describe 'POST /practices/:id/availability' do
    let(:availability_params) do
      {
        'availability_0' => 'available',
        'availability_1' => 'maybe',
        'availability_2' => 'not_available',
        'notes_0' => 'Available all day',
        'notes_1' => 'Only after 7pm',
        'notes_2' => 'Out of town'
      }
    end

    context 'when logged in' do
      include_context 'logged in user'

      it 'creates availability entries' do
        expect {
          post "/practices/#{practice.id}/availability", params: availability_params
        }.to change(PracticeAvailability, :count).by(3)

        availabilities = practice.practice_availabilities.where(user: user).order(:day_of_week)
        expect(availabilities[0].availability).to eq('available')
        expect(availabilities[0].notes).to eq('Available all day')
        expect(availabilities[1].availability).to eq('maybe')
        expect(availabilities[1].notes).to eq('Only after 7pm')
        expect(availabilities[2].availability).to eq('not_available')
        expect(availabilities[2].notes).to eq('Out of town')
      end

      it 'replaces existing availability entries' do
        # Create existing availability
        create(:practice_availability, practice: practice, user: user, day_of_week: 0, availability: 'not_available')

        expect {
          post "/practices/#{practice.id}/availability", params: availability_params
        }.to change(PracticeAvailability, :count).by(2) # net change: -1 + 3 = 2

        availability = practice.practice_availabilities.find_by(user: user, day_of_week: 0)
        expect(availability.availability).to eq('available')
      end

      it 'skips empty availability params' do
        params_with_empty = availability_params.merge('availability_3' => '')

        expect {
          post "/practices/#{practice.id}/availability", params: params_with_empty
        }.to change(PracticeAvailability, :count).by(3) # only 3, not 4

        expect(practice.practice_availabilities.where(user: user, day_of_week: 3)).to be_empty
      end

      it 'redirects to practice show page' do
        post "/practices/#{practice.id}/availability", params: availability_params
        expect(last_response).to be_redirect
        expect(last_response.location).to include("/practices/#{practice.id}")
      end
    end

    context 'when not logged in' do
      it 'redirects to login' do
        post "/practices/#{practice.id}/availability", params: availability_params
        expect(last_response).to be_redirect
        expect(last_response.location).to include('/login')
      end
    end
  end

  describe 'POST /practices/:id/finalize' do
    context 'when logged in as practice creator' do
      include_context 'logged in user'

      it 'finalizes the practice' do
        post "/practices/#{practice.id}/finalize"

        practice.reload
        expect(practice.status).to eq('finalized')
        expect(last_response).to be_redirect
        expect(last_response.location).to include("/practices/#{practice.id}")
      end
    end

    context 'when logged in as band owner' do
      let(:owner) { create(:user) }
      let(:owned_band) { create(:band, owner: owner) }
      let(:owned_practice) { create(:practice, band: owned_band) }

      before do
        owned_band.users << owner
        post '/test_auth', params: { user_id: owner.id, band_id: owned_band.id }
      end

      it 'allows finalization' do
        post "/practices/#{owned_practice.id}/finalize"

        owned_practice.reload
        expect(owned_practice.status).to eq('finalized')
      end
    end

    context 'when logged in as regular band member' do
      include_context 'logged in user'

      let(:other_user) { create(:user) }
      let(:other_practice) { create(:practice, band: band, created_by_user: other_user) }

      it 'does not allow finalization' do
        post "/practices/#{other_practice.id}/finalize"

        other_practice.reload
        expect(other_practice.status).to eq('active')
        expect(last_response).to be_redirect
        expect(last_response.location).to include("/practices/#{other_practice.id}")
      end
    end
  end

  describe 'DELETE /practices/:id' do
    context 'when logged in as practice creator' do
      include_context 'logged in user'

      it 'deletes the practice' do
        practice_id = practice.id

        expect {
          delete "/practices/#{practice_id}"
        }.to change(Practice, :count).by(-1)

        expect(last_response).to be_redirect
        expect(last_response.location).to include('/practices')
      end
    end

    context 'when logged in as band owner' do
      let(:owner) { create(:user) }
      let(:owned_band) { create(:band, owner: owner) }
      let(:owned_practice) { create(:practice, band: owned_band) }

      before do
        owned_band.users << owner
        post '/test_auth', params: { user_id: owner.id, band_id: owned_band.id }
      end

      it 'allows deletion' do
        practice_id = owned_practice.id

        expect {
          delete "/practices/#{practice_id}"
        }.to change(Practice, :count).by(-1)
      end
    end

    context 'when logged in as regular band member' do
      include_context 'logged in user'

      let(:other_user) { create(:user) }
      let(:other_practice) { create(:practice, band: band, created_by_user: other_user) }

      it 'does not allow deletion' do
        # Create the practice before the expectation block to avoid lazy evaluation issues
        practice_id = other_practice.id

        expect {
          delete "/practices/#{practice_id}"
        }.not_to change(Practice, :count)

        expect(last_response).to be_redirect
        expect(last_response.location).to include("/practices/#{practice_id}")
      end
    end
  end
end