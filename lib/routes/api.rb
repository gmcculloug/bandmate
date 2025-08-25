require 'sinatra/base'
require 'net/http'
require 'uri'
require 'json'

module Routes
end

class Routes::Api < Sinatra::Base
  configure do
    set :views, File.join(File.dirname(__FILE__), '..', '..', 'views')
  end
  
  helpers ApplicationHelpers
  
  # ============================================================================
  # API ROUTES
  # ============================================================================

  get '/api/songs' do
    require_login
    content_type :json
    
    if current_band
      songs = filter_by_current_band(Song).order(:title)
    else
      songs = []
    end
    songs.map { |song| { id: song.id, title: song.title, artist: song.artist } }.to_json
  end

  get '/api/lookup_song' do
    require_login
    content_type :json
    
    title = params[:title]
    artist = params[:artist] || ''
    
    if title.blank?
      return { error: 'Title is required' }.to_json
    end
    
    begin
      # First try the mock database for demo purposes
      mock_data = get_mock_song_data(title, artist)
      if mock_data[:found]
        return {
          success: true,
          data: mock_data
        }.to_json
      end
      
      # If not in mock data, try songbpm.com
      # Construct search query for songbpm.com
      query = "#{title} #{artist}".strip
      search_url = "https://songbpm.com/#{URI.encode_www_form_component(title.downcase.gsub(/\s+/, '-'))}"
      
      # Set up HTTP request with proper headers
      uri = URI(search_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = 'Mozilla/5.0 (compatible; Bandmate/1.0)'
      
      response = http.request(request)
      
      if response.code == '200'
        # Parse the HTML response to extract song data
        html = response.body
        song_data = parse_songbpm_response(html, title, artist)
        
        if song_data[:found]
          {
            success: true,
            data: song_data
          }.to_json
        else
          {
            success: false,
            error: 'Song not found on songbpm.com'
          }.to_json
        end
      else
        {
          success: false,
          error: 'Failed to fetch data from songbpm.com'
        }.to_json
      end
    rescue => e
      {
        success: false,
        error: "Lookup failed: #{e.message}"
      }.to_json
    end
  end

  private

  def get_mock_song_data(title, artist)
    # Mock database of popular songs for demonstration
    # In a real implementation, this could be a local database or multiple API sources
    mock_songs = {
      'billie jean' => {
        artist: 'Michael Jackson',
        key: 'F#/Gb',
        tempo: 117,
        duration: '4:54'
      },
      'bohemian rhapsody' => {
        artist: 'Queen',
        key: 'A#/Bb',
        tempo: 72,
        duration: '5:55'
      },
      'hotel california' => {
        artist: 'Eagles',
        key: 'B',
        tempo: 75,
        duration: '6:30'
      },
      'stairway to heaven' => {
        artist: 'Led Zeppelin',
        key: 'A',
        tempo: 82,
        duration: '8:02'
      },
      'sweet child o mine' => {
        artist: 'Guns N\' Roses',
        key: 'D',
        tempo: 125,
        duration: '5:03'
      },
      'wonderwall' => {
        artist: 'Oasis',
        key: 'F#/Gb',
        tempo: 87,
        duration: '4:18'
      },
      'hey jude' => {
        artist: 'The Beatles',
        key: 'F',
        tempo: 75,
        duration: '7:11'
      },
      'imagine' => {
        artist: 'John Lennon',
        key: 'C',
        tempo: 76,
        duration: '3:03'
      },
      'smells like teen spirit' => {
        artist: 'Nirvana',
        key: 'F',
        tempo: 117,
        duration: '5:01'
      },
      'purple rain' => {
        artist: 'Prince',
        key: 'A#/Bb',
        tempo: 110,
        duration: '8:41'
      }
    }
    
    # Normalize title for lookup
    normalized_title = title.downcase.strip
    
    # Look for exact match or partial match
    song_data = mock_songs[normalized_title]
    
    if song_data
      # If artist is provided and doesn't match, don't use this data
      if artist.present? && !artist.downcase.include?(song_data[:artist].downcase.split.first.downcase)
        return { found: false }
      end
      
      {
        found: true,
        artist: song_data[:artist],
        key: song_data[:key],
        tempo: song_data[:tempo],
        duration: song_data[:duration]
      }
    else
      { found: false }
    end
  end

  def parse_songbpm_response(html, title, artist)
    # Simple HTML parsing to extract song information
    # This looks for common patterns in songbpm.com HTML structure
    
    begin
      # Look for BPM information
      bpm_match = html.match(/(\d+)\s*BPM/i)
      tempo = bpm_match ? bpm_match[1].to_i : nil
      
      # Look for key information
      key_match = html.match(/Key[:\s]*([A-G][#♯♭b]?\s*(?:major|minor|maj|min)?)/i)
      key = key_match ? normalize_key(key_match[1].strip) : nil
      
      # Look for duration information
      duration_match = html.match(/(\d{1,2}):(\d{2})/i)
      duration = duration_match ? "#{duration_match[1]}:#{duration_match[2]}" : nil
      
      # Extract artist name from the page if not provided
      if artist.blank?
        artist_match = html.match(/<h2[^>]*>([^<]+)<\/h2>/i) || 
                       html.match(/by\s+([^<\n]+)/i) ||
                       html.match(/artist[:\s]*([^<\n]+)/i)
        artist = artist_match ? artist_match[1].strip : nil
      end
      
      # Check if we found any useful data
      found = tempo || key || duration || artist
      
      {
        found: !!found,
        artist: artist,
        key: key,
        tempo: tempo,
        duration: duration
      }
    rescue => e
      {
        found: false,
        error: "Parsing error: #{e.message}"
      }
    end
  end

  def normalize_key(key_string)
    # Normalize key format to match our application's format
    key_string = key_string.gsub(/♯/, '#').gsub(/♭/, 'b')
    
    # Remove major/minor designations since our app only stores the root key
    key_string = key_string.gsub(/\s*(major|maj|minor|min|m)\s*/i, '').strip
    
    # Map common variations to our dropdown format
    key_mappings = {
      'Db' => 'C#/Db',
      'C#' => 'C#/Db',
      'Eb' => 'D#/Eb',
      'D#' => 'D#/Eb',
      'Gb' => 'F#/Gb',
      'F#' => 'F#/Gb',
      'Ab' => 'G#/Ab',
      'G#' => 'G#/Ab',
      'Bb' => 'A#/Bb',
      'A#' => 'A#/Bb'
    }
    
    key_mappings[key_string] || key_string
  end
end