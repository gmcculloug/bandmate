require_relative '../spec_helper'

RSpec.describe GlobalSong, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      global_song = GlobalSong.new(
        title: 'Test Song',
        artist: 'Test Artist', 
        key: 'C'
      )
      expect(global_song).to be_valid
    end

    it 'is invalid without a title' do
      global_song = GlobalSong.new(
        artist: 'Test Artist',
        key: 'C'
      )
      expect(global_song).not_to be_valid
      expect(global_song.errors[:title]).to include("can't be blank")
    end

    it 'is invalid without an artist' do
      global_song = GlobalSong.new(
        title: 'Test Song',
        key: 'C'
      )
      expect(global_song).not_to be_valid
      expect(global_song.errors[:artist]).to include("can't be blank")
    end

    it 'is invalid without a key' do
      global_song = GlobalSong.new(
        title: 'Test Song',
        artist: 'Test Artist'
      )
      expect(global_song).not_to be_valid
      expect(global_song.errors[:key]).to include("can't be blank")
    end

    it 'validates tempo is positive when present' do
      global_song = GlobalSong.new(
        title: 'Test Song',
        artist: 'Test Artist',
        key: 'C',
        tempo: -10
      )
      expect(global_song).not_to be_valid
      expect(global_song.errors[:tempo]).to include("must be greater than 0")
    end

    it 'allows nil tempo' do
      global_song = GlobalSong.new(
        title: 'Test Song',
        artist: 'Test Artist',
        key: 'C',
        tempo: nil
      )
      expect(global_song).to be_valid
    end

    it 'allows positive tempo' do
      global_song = GlobalSong.new(
        title: 'Test Song',
        artist: 'Test Artist',
        key: 'C',
        tempo: 120
      )
      expect(global_song).to be_valid
    end
  end

  describe 'associations' do
    it 'has many songs' do
      global_song = GlobalSong.create!(
        title: 'Test Song',
        artist: 'Test Artist',
        key: 'C'
      )
      
      song1 = Song.create!(
        title: 'Test Song',
        artist: 'Test Artist', 
        key: 'C',
        global_song: global_song
      )
      
      song2 = Song.create!(
        title: 'Test Song',
        artist: 'Test Artist',
        key: 'C', 
        global_song: global_song
      )

      expect(global_song.songs).to include(song1, song2)
      expect(global_song.songs.count).to eq(2)
    end
  end

  describe 'scopes' do
    let!(:song1) do
      GlobalSong.create!(
        title: 'Hotel California',
        artist: 'Eagles',
        key: 'Bm'
      )
    end
    
    let!(:song2) do
      GlobalSong.create!(
        title: 'Stairway to Heaven',
        artist: 'Led Zeppelin',
        key: 'Am'
      )
    end
    
    let!(:song3) do
      GlobalSong.create!(
        title: 'Wonderwall',
        artist: 'Oasis',
        key: 'Em'
      )
    end

    describe '.search' do
      it 'finds songs by title' do
        results = GlobalSong.search('hotel')
        expect(results).to include(song1)
        expect(results).not_to include(song2, song3)
      end

      it 'finds songs by artist' do
        results = GlobalSong.search('eagles')
        expect(results).to include(song1)
        expect(results).not_to include(song2, song3)
      end

      it 'is case insensitive' do
        results = GlobalSong.search('HOTEL')
        expect(results).to include(song1)
        
        results = GlobalSong.search('EAGLES')
        expect(results).to include(song1)
      end

      it 'finds multiple results' do
        results = GlobalSong.search('e') # matches Eagles, Led Zeppelin, and Oasis
        expect(results.count).to eq(3) # All songs match the letter 'e'
        expect(results).to include(song1, song2, song3)
      end

      it 'returns empty when no matches' do
        results = GlobalSong.search('nonexistent')
        expect(results).to be_empty
      end

      it 'returns all songs when query is blank' do
        results = GlobalSong.search('')
        expect(results.count).to eq(3)
        expect(results.to_a).to match_array([song1, song2, song3])
      end

      it 'returns all songs when query is nil' do
        results = GlobalSong.search(nil)
        expect(results.count).to eq(3)
        expect(results.to_a).to match_array([song1, song2, song3])
      end
    end
  end
end