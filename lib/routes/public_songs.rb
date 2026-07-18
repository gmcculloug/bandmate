require 'sinatra/base'

module Routes
end

class Routes::PublicSongs < Sinatra::Base
  configure do
    set :views, File.join(File.dirname(__FILE__), '..', '..', 'views')
  end

  helpers ApplicationHelpers

  # ============================================================================
  # PUBLIC SONGS ROUTES
  # No authentication required - these are public endpoints
  # ============================================================================

  # GET /repertoire/:slug - Public HTML songs view
  get '/repertoire/:slug' do
    band = Band.find_by(slug: params[:slug])

    if band.nil? || !band.public_songs_enabled?
      return erb :public_songs_not_found, layout: :public_layout
    end

    @band = band
    @view_by = params[:by] == 'artist' ? 'artist' : 'title'

    songs = Song.active.ready_for_band(band)
    @songs = if @view_by == 'artist'
               songs.order(Arel.sql('LOWER(artist), LOWER(title)'))
             else
               songs.order(Arel.sql('LOWER(title)'))
             end

    erb :public_songs, layout: :public_layout
  end
end
