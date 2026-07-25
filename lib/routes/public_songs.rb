require 'sinatra/base'
require 'uri'

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

  # GET /band/:slug/songs - Public HTML songs view
  get '/band/:slug/songs' do
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

  # POST /band/:slug/songs/recommend - Public song recommendation submission
  post '/band/:slug/songs/recommend' do
    band = Band.find_by(slug: params[:slug])

    if band.nil? || !band.public_songs_enabled?
      return erb :public_songs_not_found, layout: :public_layout
    end

    # Honeypot: hidden field only bots fill in. Pretend success, never persist.
    if params[:website].to_s.strip != ''
      redirect "/band/#{band.slug}/songs?success=#{URI.encode_www_form_component('Thanks for your recommendation!')}"
    end

    if SongRecommendation.rate_limited?(request.ip) || SongRecommendation.pending_limit_reached?(band)
      redirect "/band/#{band.slug}/songs?error=#{URI.encode_www_form_component('Unable to accept recommendations right now. Please try again later.')}"
    end

    rec = SongRecommendation.new(
      band: band,
      title: params[:title],
      artist: params[:artist],
      notes: params[:notes],
      ip_address: request.ip
    )

    if rec.save
      redirect "/band/#{band.slug}/songs?success=#{URI.encode_www_form_component('Thanks for your recommendation!')}"
    else
      @band = band
      @view_by = params[:by] == 'artist' ? 'artist' : 'title'
      songs = Song.active.ready_for_band(band)
      @songs = if @view_by == 'artist'
                 songs.order(Arel.sql('LOWER(artist), LOWER(title)'))
               else
                 songs.order(Arel.sql('LOWER(title)'))
               end
      @recommend_errors = rec.errors.full_messages
      erb :public_songs, layout: :public_layout
    end
  end
end
