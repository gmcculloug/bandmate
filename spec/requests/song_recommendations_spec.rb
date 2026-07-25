require_relative '../spec_helper'

RSpec.describe 'Song Recommendations Review Routes', type: :request do
  let(:owner) { create(:user) }
  let(:band) { create(:band, owner: owner) }
  let(:other_band) { create(:band) }

  describe 'GET /song_recommendations' do
    it 'requires login' do
      get '/song_recommendations'

      expect(last_response.status).to eq(302)
      expect(last_response.location).to include('/login')
    end

    it 'lists pending recommendations for the current band only' do
      login_as(owner, band)
      mine = create(:song_recommendation, band: band, title: 'My Song')
      create(:song_recommendation, band: other_band, title: 'Not Mine')

      get '/song_recommendations'

      expect(last_response).to be_ok
      expect(last_response.body).to include('My Song')
      expect(last_response.body).not_to include('Not Mine')
    end

    it 'escapes recommendation content in the rendered page' do
      login_as(owner, band)
      create(:song_recommendation, band: band, title: '<script>alert(1)</script>', notes: '<b>bold</b>')

      get '/song_recommendations'

      expect(last_response.body).not_to include('<script>alert(1)</script>')
      expect(last_response.body).to include('&lt;script&gt;')
    end
  end

  describe 'POST /song_recommendations/:id/approve' do
    it 'requires login' do
      rec = create(:song_recommendation, band: band)

      post "/song_recommendations/#{rec.id}/approve"

      expect(last_response.status).to eq(302)
      expect(last_response.location).to include('/login')
    end

    it 'creates a Song linked to the current band and marks the recommendation approved' do
      login_as(owner, band)
      rec = create(:song_recommendation, band: band, title: 'Approved Song', artist: 'Cool Artist')

      post "/song_recommendations/#{rec.id}/approve"

      expect(last_response.status).to eq(302)
      song = Song.find_by(title: 'Approved Song', artist: 'Cool Artist')
      expect(song).to be_present
      expect(band.songs.reload).to include(song)
      expect(rec.reload.status).to eq('approved')
    end

    it 'does not allow approving a recommendation belonging to another band' do
      login_as(owner, band)
      rec = create(:song_recommendation, band: other_band, title: 'Other Band Song')

      expect {
        post "/song_recommendations/#{rec.id}/approve"
      }.to raise_error(ActiveRecord::RecordNotFound)

      expect(rec.reload.status).to eq('pending')
      expect(Song.find_by(title: 'Other Band Song')).to be_nil
    end
  end

  describe 'POST /song_recommendations/:id/reject' do
    it 'marks the recommendation rejected without creating a Song' do
      login_as(owner, band)
      rec = create(:song_recommendation, band: band, title: 'Rejected Song')

      post "/song_recommendations/#{rec.id}/reject"

      expect(last_response.status).to eq(302)
      expect(rec.reload.status).to eq('rejected')
      expect(Song.find_by(title: 'Rejected Song')).to be_nil
    end

    it 'does not allow rejecting a recommendation belonging to another band' do
      login_as(owner, band)
      rec = create(:song_recommendation, band: other_band)

      expect {
        post "/song_recommendations/#{rec.id}/reject"
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
