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
        expect(last_response.body).to include('start_date')
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
        start_date: Date.current.to_s,
        end_date: (Date.current + 6.days).to_s,
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

      it 'creates practice with custom date range' do
        # Use a custom date range
        start_date = Date.current + 1.week
        end_date = start_date + 4.days
        post '/practices', valid_params.merge(start_date: start_date.to_s, end_date: end_date.to_s)

        practice = Practice.last
        expect(practice.start_date).to eq(start_date)
        expect(practice.end_date).to eq(end_date)
      end

      it 'handles invalid date format' do
        post '/practices', valid_params.merge(start_date: 'invalid-date')
        expect(last_response.body).to include('Invalid date format')
      end

      it 'does not create practice with overlapping dates for same band' do
        create(:practice, band: band, start_date: Date.current, end_date: Date.current + 6.days)

        post '/practices', valid_params
        expect(last_response.body).to include('Practice dates overlap with an existing practice session')
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
      start_date = practice.start_date
      {
        "availability_#{start_date}" => 'available',
        "availability_#{start_date + 1.day}" => 'maybe',
        "availability_#{start_date + 2.days}" => 'not_available',
        "notes_#{start_date}" => 'Available all day',
        "notes_#{start_date + 1.day}" => 'Only after 7pm',
        "notes_#{start_date + 2.days}" => 'Out of town'
      }
    end

    context 'when logged in' do
      include_context 'logged in user'

      it 'creates availability entries' do
        expect {
          post "/practices/#{practice.id}/availability", params: availability_params
        }.to change(PracticeAvailability, :count).by(3)

        start_date = practice.start_date
        availabilities = practice.practice_availabilities.where(user: user).order(:specific_date)
        expect(availabilities[0].availability).to eq('available')
        expect(availabilities[0].notes).to eq('Available all day')
        expect(availabilities[0].specific_date).to eq(start_date)
        expect(availabilities[1].availability).to eq('maybe')
        expect(availabilities[1].notes).to eq('Only after 7pm')
        expect(availabilities[1].specific_date).to eq(start_date + 1.day)
        expect(availabilities[2].availability).to eq('not_available')
        expect(availabilities[2].notes).to eq('Out of town')
        expect(availabilities[2].specific_date).to eq(start_date + 2.days)
      end

      it 'replaces existing availability entries' do
        # Create existing availability
        create(:practice_availability, practice: practice, user: user, specific_date: practice.start_date, availability: 'not_available')

        expect {
          post "/practices/#{practice.id}/availability", params: availability_params
        }.to change(PracticeAvailability, :count).by(2) # net change: -1 + 3 = 2

        availability = practice.practice_availabilities.find_by(user: user, specific_date: practice.start_date)
        expect(availability.availability).to eq('available')
      end

      it 'skips empty availability params' do
        params_with_empty = availability_params.merge('availability_3' => '')

        expect {
          post "/practices/#{practice.id}/availability", params: params_with_empty
        }.to change(PracticeAvailability, :count).by(3) # only 3, not 4

        expect(practice.practice_availabilities.where(user: user, specific_date: practice.start_date + 3.days)).to be_empty
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
        # Owner is already a user of the band via the band factory
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

  describe 'GET /practices/:id/edit' do
    context 'when logged in as practice creator' do
      include_context 'logged in user'

      it 'returns success' do
        get "/practices/#{practice.id}/edit"
        expect(last_response).to be_ok
      end

      it 'displays the edit practice form' do
        get "/practices/#{practice.id}/edit"
        expect(last_response.body).to include('Edit Practice Session')
        expect(last_response.body).to include('practice_title')
        expect(last_response.body).to include('start_date')
        expect(last_response.body).to include(practice.title)
        expect(last_response.body).to include(practice.start_date.to_s)
      end

      it 'shows warning when practice has availability responses' do
        create(:practice_availability, practice: practice, user: user)
        get "/practices/#{practice.id}/edit"
        expect(last_response.body).to include('already has member availability responses')
        expect(last_response.body).to include('all existing availability responses will be cleared')
      end
    end

    context 'when logged in as band owner' do
      let(:owner) { create(:user) }
      let(:owned_band) { create(:band, owner: owner) }
      let(:owned_practice) { create(:practice, band: owned_band) }

      before do
        # Owner is already a user of the band via the band factory
        post '/test_auth', params: { user_id: owner.id, band_id: owned_band.id }
      end

      it 'allows editing' do
        get "/practices/#{owned_practice.id}/edit"
        expect(last_response).to be_ok
        expect(last_response.body).to include('Edit Practice Session')
      end
    end

    context 'when logged in as regular band member' do
      include_context 'logged in user'

      let(:other_user) { create(:user) }
      let(:other_practice) { create(:practice, band: band, created_by_user: other_user) }

      it 'does not allow editing' do
        get "/practices/#{other_practice.id}/edit"
        expect(last_response).to be_redirect
        expect(last_response.location).to include("/practices/#{other_practice.id}")
      end
    end

    context 'when not logged in' do
      it 'redirects to login' do
        get "/practices/#{practice.id}/edit"
        expect(last_response).to be_redirect
        expect(last_response.location).to include('/login')
      end
    end
  end

  describe 'PUT /practices/:id' do
    let(:update_params) do
      {
        title: 'Updated Practice',
        start_date: (Date.current + 1.week).to_s,
        end_date: (Date.current + 1.week + 6.days).to_s,
        description: 'Updated description'
      }
    end

    context 'when logged in as practice creator' do
      include_context 'logged in user'

      it 'updates the practice with valid params' do
        put "/practices/#{practice.id}", update_params

        practice.reload
        expect(practice.title).to eq('Updated Practice')
        expect(practice.description).to eq('Updated description')
        expect(last_response).to be_redirect
        expect(last_response.location).to include("/practices/#{practice.id}")
      end

      it 'updates practice with custom date range' do
        # Use a custom date range
        start_date = Date.current + 1.week
        end_date = start_date + 4.days  # 5-day practice period
        put "/practices/#{practice.id}", update_params.merge(start_date: start_date.to_s, end_date: end_date.to_s)

        practice.reload
        expect(practice.start_date).to eq(start_date)
        expect(practice.end_date).to eq(end_date)
      end

      it 'clears availability responses when dates change' do
        # Create some availability responses
        create(:practice_availability, practice: practice, user: user, specific_date: practice.start_date)
        create(:practice_availability, practice: practice, user: user, specific_date: practice.start_date + 1.day)

        expect {
          put "/practices/#{practice.id}", update_params
        }.to change(PracticeAvailability, :count).by(-2)
      end

      it 'does not clear availability responses when dates stay the same' do
        # Create some availability responses
        create(:practice_availability, practice: practice, user: user, specific_date: practice.start_date)

        same_date_params = update_params.merge(
          start_date: practice.start_date.to_s,
          end_date: practice.end_date.to_s
        )

        expect {
          put "/practices/#{practice.id}", same_date_params
        }.not_to change(PracticeAvailability, :count)
      end

      it 'handles invalid date format' do
        put "/practices/#{practice.id}", update_params.merge(start_date: 'invalid-date')
        expect(last_response.body).to include('Invalid date format')
      end

      it 'handles end date before start date' do
        put "/practices/#{practice.id}", update_params.merge(
          start_date: '2024-01-15',      # Monday
          end_date: '2024-01-10'         # Previous Wednesday
        )
        expect(last_response.status).to eq(200)
        expect(last_response.body).to include('End date must be after or equal to start date')
      end
    end

    context 'when logged in as band owner' do
      let(:owner) { create(:user) }
      let(:owned_band) { create(:band, owner: owner) }
      let(:owned_practice) { create(:practice, band: owned_band) }

      before do
        # Owner is already a user of the band via the band factory
        post '/test_auth', params: { user_id: owner.id, band_id: owned_band.id }
      end

      it 'allows updating' do
        put "/practices/#{owned_practice.id}", update_params

        owned_practice.reload
        expect(owned_practice.title).to eq('Updated Practice')
      end
    end

    context 'when logged in as regular band member' do
      include_context 'logged in user'

      let(:other_user) { create(:user) }
      let(:other_practice) { create(:practice, band: band, created_by_user: other_user) }

      it 'does not allow updating' do
        original_title = other_practice.title

        put "/practices/#{other_practice.id}", update_params

        other_practice.reload
        expect(other_practice.title).to eq(original_title)
        expect(last_response).to be_redirect
        expect(last_response.location).to include("/practices/#{other_practice.id}")
      end
    end

    context 'when not logged in' do
      it 'redirects to login' do
        put "/practices/#{practice.id}", update_params
        expect(last_response).to be_redirect
        expect(last_response.location).to include('/login')
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
        # Owner is already a user of the band via the band factory
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