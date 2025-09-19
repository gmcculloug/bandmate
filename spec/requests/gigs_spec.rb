require 'spec_helper'

RSpec.describe 'Gigs API', type: :request do
  let(:user) { create(:user) }
  let(:band) { create(:band, owner: user) }
  
  before do
    create(:user_band, user: user, band: band)
  end
  describe 'GET /gigs' do
    it 'returns a list of all gigs' do
      login_as(user, band)
      gig1 = create(:gig, name: 'Gig A', band: band)
      gig2 = create(:gig, name: 'Gig B', band: band)
      
      get '/gigs'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Gig A')
      expect(last_response.body).to include('Gig B')
    end

    it 'displays upcoming gigs in chronological order' do
      login_as(user, band)
      # Create gigs with specific dates to test ordering
      gig_later = create(:gig, name: 'Later Gig', band: band, performance_date: Date.current + 3.days)
      gig_sooner = create(:gig, name: 'Sooner Gig', band: band, performance_date: Date.current + 1.day)
      gig_middle = create(:gig, name: 'Middle Gig', band: band, performance_date: Date.current + 2.days)
      
      get '/gigs'
      
      expect(last_response).to be_ok
      body = last_response.body
      sooner_index = body.index('Sooner Gig')
      middle_index = body.index('Middle Gig')
      later_index = body.index('Later Gig')
      
      # Should appear in chronological order: sooner, then middle, then later
      expect(sooner_index).to be < middle_index
      expect(middle_index).to be < later_index
    end
  end

  describe 'GET /gigs/new' do
    it 'displays the new gig form' do
      login_as(user, band)
      venue = create(:venue, band: band)
      
      get '/gigs/new'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('New Gig')
      expect(last_response.body).to include('name')
      expect(last_response.body).to include(band.name)
      expect(last_response.body).to include(venue.name)
    end
  end

  describe 'POST /gigs' do
    it 'creates a new gig with valid attributes' do
      login_as(user, band)
      venue = create(:venue, band: band)
      gig_params = {
        name: 'New Gig',
        band_id: band.id,
        venue_id: venue.id,
        performance_date: '2024-12-25',
        start_time: '20:00',
        end_time: '22:00',
        notes: 'A great gig'
      }
      
      expect {
        post '/gigs', gig_params
      }.to change(Gig, :count).by(1)
      
      expect(last_response).to be_redirect
      follow_redirect!
      expect(last_response.body).to include('New Gig')
    end

    it 'creates a gig without optional venue' do
      login_as(user, band)
      gig_params = {
        name: 'Gig No Venue',
        band_id: band.id,
        performance_date: '2024-12-25'
      }
      
      expect {
        post '/gigs', gig_params
      }.to change(Gig, :count).by(1)
      
      expect(last_response).to be_redirect
    end

    it 'displays errors for invalid attributes' do
      login_as(user, band)
      gig_params = {
        name: '',
        band_id: ''
      }
      
      expect {
        post '/gigs', gig_params
      }.not_to change(Gig, :count)
      
      expect(last_response).to be_ok
      expect(last_response.body).to include("can't be blank")
    end

    it 'displays errors when performance_date is missing' do
      login_as(user, band)
      gig_params = {
        name: 'Test Gig',
        band_id: band.id,
        performance_date: ''
      }
      
      expect {
        post '/gigs', gig_params
      }.not_to change(Gig, :count)
      
      expect(last_response).to be_ok
      expect(last_response.body).to include("Performance date can't be blank")
    end
  end

  describe 'GET /gigs/:id' do
    it 'displays a specific gig' do
      login_as(user, band)
      gig = create(:gig, name: 'Test Gig', notes: 'Test notes', band: band)
      
      get "/gigs/#{gig.id}"
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Test Gig')
      expect(last_response.body).to include('Test notes')
    end

    it 'shows available songs for the band on manage songs page' do
      login_as(user, band)
      gig = create(:gig, band: band)
      song1 = create(:song, bands: [band])
      song2 = create(:song, bands: [band])
      
      get "/gigs/#{gig.id}/manage_songs"
      
      expect(last_response).to be_ok
      expect(last_response.body).to include(song1.title)
      expect(last_response.body).to include(song2.title)
    end

    it 'separates songs in gig from available songs' do
      login_as(user, band)
      gig = create(:gig, band: band)
      song1 = create(:song, bands: [band])
      song2 = create(:song, bands: [band])
      
      # Add song1 to the gig
      create(:gig_song, gig: gig, song: song1)
      
      # Check gig show page shows song1 (in gig)
      get "/gigs/#{gig.id}"
      expect(last_response).to be_ok
      expect(last_response.body).to include(song1.title)
      
      # Check manage songs page shows both songs (for management purposes)
      get "/gigs/#{gig.id}/manage_songs"
      expect(last_response).to be_ok
      expect(last_response.body).to include(song2.title) # Available to add
      expect(last_response.body).to include(song1.title) # Already in gig, shown for management
    end

    it 'returns 404 for non-existent gig' do
      login_as(user, band)
      expect { get '/gigs/999' }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'GET /gigs/:id/edit' do
    it 'displays the edit form for a gig' do
      login_as(user, band)
      gig = create(:gig, name: 'Edit Gig', band: band)
      
      get "/gigs/#{gig.id}/edit"
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Edit Gig')
      expect(last_response.body).to include('method="POST"')
      expect(last_response.body).to include('_method" value="PUT"')
    end

    it 'returns 404 for non-existent gig' do
      login_as(user, band)
      expect { get '/gigs/999/edit' }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'PUT /gigs/:id' do
    it 'updates a gig with valid attributes' do
      login_as(user, band)
      gig = create(:gig, name: 'Old Name', notes: 'Old notes', band: band)
      update_params = {
        name: 'New Name',
        notes: 'New notes',
        performance_date: '2024-12-25'
      }
      
      put "/gigs/#{gig.id}", update_params
      
      expect(last_response).to be_redirect
      follow_redirect!
      expect(last_response.body).to include('New Name')
      expect(last_response.body).to include('New notes')
    end

    it 'displays errors for invalid attributes' do
      login_as(user, band)
      gig = create(:gig, name: 'Valid Name', band: band)
      update_params = { name: '', band_id: gig.band.id }
      
      put "/gigs/#{gig.id}", update_params
      
      expect(last_response).to be_ok
      expect(last_response.body).to include("can't be blank")
    end

    it 'returns 404 for non-existent gig' do
      login_as(user, band)
      expect { put '/gigs/999', name: 'New Name' }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'DELETE /gigs/:id' do
    it 'deletes a gig' do
      login_as(user, band)
      gig = create(:gig, name: 'Delete Gig', band: band)
      
      expect {
        delete "/gigs/#{gig.id}"
      }.to change(Gig, :count).by(-1)
      
      expect(last_response).to be_redirect
      expect(last_response.location).to end_with('/gigs')
    end

    it 'returns 404 for non-existent gig' do
      login_as(user, band)
      expect { delete '/gigs/999' }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'POST /gigs/:id/songs' do
    it 'adds a song to the gig' do
      login_as(user, band)
      gig = create(:gig, band: band)
      song = create(:song, bands: [band])
      
      expect {
        post "/gigs/#{gig.id}/songs", song_id: song.id
      }.to change(GigSong, :count).by(1)
      
      expect(last_response).to be_redirect
      follow_redirect!
      expect(last_response.body).to include(song.title)
    end

    it 'assigns the correct position to the new song' do
      login_as(user, band)
      gig = create(:gig, band: band)
      song1 = create(:song, bands: [band])
      song2 = create(:song, bands: [band])
      
      # Add first song
      post "/gigs/#{gig.id}/songs", song_id: song1.id
      # Add second song
      post "/gigs/#{gig.id}/songs", song_id: song2.id
      
      gig.reload
      expect(gig.gig_songs.find_by(song: song1).position).to eq(1)
      expect(gig.gig_songs.find_by(song: song2).position).to eq(2)
    end
  end

  describe 'DELETE /gigs/:gig_id/songs/:song_id' do
    it 'removes a song from the gig' do
      login_as(user, band)
      gig = create(:gig, band: band)
      song = create(:song, bands: [band])
      gig_song = create(:gig_song, gig: gig, song: song)
      
      expect {
        delete "/gigs/#{gig.id}/songs/#{song.id}"
      }.to change(GigSong, :count).by(-1)
      
      expect(last_response).to be_redirect
    end

    it 'reorders remaining songs after removal' do
      login_as(user, band)
      gig = create(:gig, band: band)
      song1 = create(:song, bands: [band])
      song2 = create(:song, bands: [band])
      song3 = create(:song, bands: [band])
      
      sls1 = create(:gig_song, gig: gig, song: song1, position: 1)
      sls2 = create(:gig_song, gig: gig, song: song2, position: 2)
      sls3 = create(:gig_song, gig: gig, song: song3, position: 3)
      
      # Remove song2
      delete "/gigs/#{gig.id}/songs/#{song2.id}"
      
      expect(sls1.reload.position).to eq(1)
      expect(sls3.reload.position).to eq(2)
    end
  end

  describe 'GET /gigs/:id/print' do
    it 'displays the print view for a gig' do
      login_as(user, band)
      gig = create(:gig, name: 'Print Gig', band: band)
      
      get "/gigs/#{gig.id}/print"
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Print Gig')
      expect(last_response.body).not_to include('layout') # Should not use layout
    end
  end

  describe 'POST /gigs/:id/reorder' do
    it 'reorders songs in the gig' do
      login_as(user, band)
      gig = create(:gig, band: band)
      song1 = create(:song, bands: [band])
      song2 = create(:song, bands: [band])
      song3 = create(:song, bands: [band])
      
      sls1 = create(:gig_song, gig: gig, song: song1, position: 1)
      sls2 = create(:gig_song, gig: gig, song: song2, position: 2)
      sls3 = create(:gig_song, gig: gig, song: song3, position: 3)
      
      # Reorder: song3, song1, song2
      post "/gigs/#{gig.id}/reorder", song_order: [song3.id, song1.id, song2.id]
      
      expect(last_response).to be_ok
      expect(JSON.parse(last_response.body)['success']).to be true
      
      expect(sls3.reload.position).to eq(1)
      expect(sls1.reload.position).to eq(2)
      expect(sls2.reload.position).to eq(3)
    end
  end

  describe 'POST /gigs/:id/copy' do
    it 'copies a gig with all its songs' do
      login_as(user, band)
      gig = create(:gig, name: 'Original Gig', notes: 'Original notes', band: band)
      song1 = create(:song, bands: [band])
      song2 = create(:song, bands: [band])
      
      create(:gig_song, gig: gig, song: song1, position: 1)
      create(:gig_song, gig: gig, song: song2, position: 2)
      
      expect {
        post "/gigs/#{gig.id}/copy"
      }.to change(Gig, :count).by(1)
      
      expect(last_response).to be_redirect
      
      new_gig = Gig.last
      expect(new_gig.name).to eq("Copy - Original Gig")
      expect(new_gig.notes).to eq("Original notes")
      expect(new_gig.band).to eq(gig.band)
      expect(new_gig.songs.count).to eq(2)
      expect(new_gig.songs).to include(song1, song2)
    end
  end

  describe 'Google Calendar Integration' do
    let(:google_calendar_band) { create(:band, owner: user, google_calendar_enabled: true, google_calendar_id: 'test_calendar_id') }
    let(:venue) { create(:venue, band: google_calendar_band) }

    before do
      create(:user_band, user: user, band: google_calendar_band)
    end

    describe 'POST /gigs with Google Calendar enabled' do
      it 'syncs gig to Google Calendar when creating a new gig' do
        login_as(user, google_calendar_band)

        expect_any_instance_of(Band).to receive(:sync_gig_to_google_calendar).and_return(true)

        gig_params = {
          name: 'New Calendar Gig',
          band_id: google_calendar_band.id,
          venue_id: venue.id,
          performance_date: '2024-12-25',
          start_time: '20:00',
          end_time: '22:00'
        }

        expect {
          post '/gigs', gig_params
        }.to change(Gig, :count).by(1)

        expect(last_response).to be_redirect
      end

      it 'creates gig even if Google Calendar sync fails' do
        login_as(user, google_calendar_band)

        expect_any_instance_of(Band).to receive(:sync_gig_to_google_calendar).and_return(false)

        gig_params = {
          name: 'New Calendar Gig',
          band_id: google_calendar_band.id,
          venue_id: venue.id,
          performance_date: '2024-12-25'
        }

        expect {
          post '/gigs', gig_params
        }.to change(Gig, :count).by(1)

        expect(last_response).to be_redirect
      end

      it 'does not sync when Google Calendar is disabled' do
        disabled_band = create(:band, owner: user, google_calendar_enabled: false)
        create(:user_band, user: user, band: disabled_band)
        disabled_venue = create(:venue, band: disabled_band)
        login_as(user, disabled_band)

        expect_any_instance_of(Band).not_to receive(:sync_gig_to_google_calendar)

        gig_params = {
          name: 'New Gig',
          band_id: disabled_band.id,
          venue_id: disabled_venue.id,
          performance_date: '2024-12-25'
        }

        expect {
          post '/gigs', gig_params
        }.to change(Gig, :count).by(1)
      end
    end

    describe 'PUT /gigs/:id with Google Calendar enabled' do
      it 'syncs gig updates to Google Calendar' do
        login_as(user, google_calendar_band)
        gig = create(:gig, band: google_calendar_band, venue: venue)

        expect_any_instance_of(Band).to receive(:sync_gig_to_google_calendar).and_return(true)

        put "/gigs/#{gig.id}", {
          name: 'Updated Gig Name',
          performance_date: gig.performance_date.to_s,
          venue_id: venue.id
        }

        expect(last_response).to be_redirect
        expect(gig.reload.name).to eq('Updated Gig Name')
      end

      it 'updates gig even if Google Calendar sync fails' do
        login_as(user, google_calendar_band)
        gig = create(:gig, band: google_calendar_band, venue: venue)

        expect_any_instance_of(Band).to receive(:sync_gig_to_google_calendar).and_return(false)

        put "/gigs/#{gig.id}", {
          name: 'Updated Gig Name',
          performance_date: gig.performance_date.to_s,
          venue_id: venue.id
        }

        expect(last_response).to be_redirect
        expect(gig.reload.name).to eq('Updated Gig Name')
      end
    end

    describe 'DELETE /gigs/:id with Google Calendar enabled' do
      it 'removes gig from Google Calendar when deleting' do
        login_as(user, google_calendar_band)
        gig = create(:gig, band: google_calendar_band, venue: venue)

        expect_any_instance_of(Band).to receive(:remove_gig_from_google_calendar).and_return(true)

        expect {
          delete "/gigs/#{gig.id}"
        }.to change(Gig, :count).by(-1)

        expect(last_response).to be_redirect
      end

      it 'deletes gig even if Google Calendar removal fails' do
        login_as(user, google_calendar_band)
        gig = create(:gig, band: google_calendar_band, venue: venue)

        expect_any_instance_of(Band).to receive(:remove_gig_from_google_calendar).and_return(false)

        expect {
          delete "/gigs/#{gig.id}"
        }.to change(Gig, :count).by(-1)

        expect(last_response).to be_redirect
      end
    end
  end
end 