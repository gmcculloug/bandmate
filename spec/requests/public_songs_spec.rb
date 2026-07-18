require_relative '../spec_helper'

RSpec.describe 'Public Songs Routes', type: :request do
  let(:band) { create(:band, public_songs_enabled: true) }
  let(:disabled_band) { create(:band, name: 'Private Band', public_songs_enabled: false) }

  def add_song(band, title:, artist:, practicing: false)
    song = create(:song, title: title, artist: artist)
    band.songs << song
    song.toggle_practice_for_band!(band) if practicing
    song
  end

  describe 'GET /repertoire/:slug' do
    context 'when public songs is enabled' do
      it 'returns the public songs page' do
        get "/repertoire/#{band.slug}"

        expect(last_response).to be_ok
      end

      it 'displays the band name' do
        band.update!(show_band_name: true)

        get "/repertoire/#{band.slug}"

        expect(last_response.body).to include(band.name)
      end

      it 'displays ready songs' do
        add_song(band, title: 'Ready Song', artist: 'Ready Artist')

        get "/repertoire/#{band.slug}"

        expect(last_response.body).to include('Ready Song')
        expect(last_response.body).to include('Ready Artist')
      end

      it 'excludes songs still being practiced' do
        add_song(band, title: 'Practicing Song', artist: 'Practicing Artist', practicing: true)

        get "/repertoire/#{band.slug}"

        expect(last_response.body).not_to include('Practicing Song')
      end

      it 'excludes archived songs' do
        song = add_song(band, title: 'Archived Song', artist: 'Archived Artist')
        song.archive!

        get "/repertoire/#{band.slug}"

        expect(last_response.body).not_to include('Archived Song')
      end

      it 'shows empty state when band has no ready songs' do
        get "/repertoire/#{band.slug}"

        expect(last_response).to be_ok
        expect(last_response.body).to include('No songs to show yet')
      end

      it 'lists songs alphabetically by title by default' do
        add_song(band, title: 'Zebra Song', artist: 'Artist A')
        add_song(band, title: 'Apple Song', artist: 'Artist B')

        get "/repertoire/#{band.slug}"

        body = last_response.body
        expect(body.index('Apple Song')).to be < body.index('Zebra Song')
      end

      it 'lists songs grouped alphabetically by artist when requested' do
        add_song(band, title: 'Song One', artist: 'Zebra Artist')
        add_song(band, title: 'Song Two', artist: 'Apple Artist')

        get "/repertoire/#{band.slug}?by=artist"

        body = last_response.body
        expect(body.index('Apple Artist')).to be < body.index('Zebra Artist')
      end

      it 'does not display a letter heading above song groups' do
        add_song(band, title: 'Apple Song', artist: 'Artist A')

        get "/repertoire/#{band.slug}"

        expect(last_response.body).not_to include('letter-group')
      end

      it 'combines songs starting with the same letter into a single card' do
        add_song(band, title: 'Apple Song', artist: 'Artist A')
        add_song(band, title: 'Avocado Song', artist: 'Artist B')

        get "/repertoire/#{band.slug}"

        body = last_response.body
        cards = body.split('<div class="song-card">')
        matching_card = cards.find { |c| c.include?('Apple Song') }
        expect(matching_card).to include('Avocado Song')
      end

      it 'splits songs with different starting letters into separate cards' do
        add_song(band, title: 'Apple Song', artist: 'Artist A')
        add_song(band, title: 'Banana Song', artist: 'Artist B')

        get "/repertoire/#{band.slug}"

        body = last_response.body
        expect(body.scan('<div class="song-card">').count).to eq(2)
      end

      it 'combines artists sharing a first letter into a single card in artist view' do
        add_song(band, title: 'Song One', artist: 'Apple Artist')
        add_song(band, title: 'Song Two', artist: 'Avocado Artist')

        get "/repertoire/#{band.slug}?by=artist"

        body = last_response.body
        expect(body.scan('<div class="song-card">').count).to eq(1)
      end

      it 'shows the letter badge only once per card, not per song' do
        add_song(band, title: 'Apple Song', artist: 'Artist A')
        add_song(band, title: 'Avocado Song', artist: 'Artist B')

        get "/repertoire/#{band.slug}"

        body = last_response.body
        expect(body.scan('class="song-badge"').count).to eq(1)
        expect(body).to include('>A<')
      end

      it 'links to the public schedule page when it is enabled' do
        band.update!(public_schedule_enabled: true)

        get "/repertoire/#{band.slug}"

        expect(last_response.body).to include("/schedule/#{band.slug}")
      end

      it 'does not link to the public schedule page when it is disabled' do
        band.update!(public_schedule_enabled: false)

        get "/repertoire/#{band.slug}"

        expect(last_response.body).not_to include("/schedule/#{band.slug}")
      end
    end

    context 'when public songs is disabled' do
      it 'returns 200 with not found page (not a 404 for security)' do
        get "/repertoire/#{disabled_band.slug}"

        expect(last_response.status).to eq(200)
        expect(last_response.body).to include('Songs Not Found')
      end

      it 'does not expose any band information' do
        add_song(disabled_band, title: 'Secret Song', artist: 'Secret Artist')

        get "/repertoire/#{disabled_band.slug}"

        expect(last_response.body).not_to include('Secret Song')
      end
    end

    context 'when band does not exist' do
      it 'returns not found page' do
        get '/repertoire/no-such-band'

        expect(last_response.status).to eq(200)
        expect(last_response.body).to include('Songs Not Found')
      end
    end
  end

  describe 'Security - No Authentication Required' do
    it 'does not require authentication for public songs page' do
      clear_cookies

      get "/repertoire/#{band.slug}"

      expect(last_response).to be_ok
    end

    it 'does not require Band Huddle session' do
      get "/repertoire/#{band.slug}"

      expect(last_response).to be_ok
      expect(last_response.body).not_to include('Login')
    end
  end
end
