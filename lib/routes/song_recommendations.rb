require 'sinatra/base'
require 'uri'

module Routes
end

class Routes::SongRecommendations < Sinatra::Base
  configure do
    set :views, File.join(File.dirname(__FILE__), '..', '..', 'views')
  end

  helpers ApplicationHelpers

  # ============================================================================
  # SONG RECOMMENDATION REVIEW ROUTES
  # ============================================================================

  get '/song_recommendations' do
    require_login
    ensure_band_context

    @recommendations = SongRecommendation.where(band: current_band, status: 'pending').order(created_at: :desc)

    erb :song_recommendations
  end

  post '/song_recommendations/:id/approve' do
    require_login
    ensure_band_context

    rec = SongRecommendation.where(band: current_band).find(params[:id])

    song_notes = "Recommended via public song list"
    song_notes += ": #{rec.notes}" if rec.notes.present?

    song = Song.create!(title: rec.title, artist: rec.artist, key: 'C', duration: '0:00', notes: song_notes)
    SongBand.find_or_create_by_song_and_band(song, current_band)
    rec.update!(status: 'approved')

    redirect "/songs?success=#{URI.encode_www_form_component('Song added - please fill in key/tempo/duration')}"
  end

  post '/song_recommendations/:id/reject' do
    require_login
    ensure_band_context

    rec = SongRecommendation.where(band: current_band).find(params[:id])
    rec.update!(status: 'rejected')

    redirect "/song_recommendations?success=#{URI.encode_www_form_component('Recommendation rejected')}"
  end
end
