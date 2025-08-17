require 'spec_helper'

RSpec.describe SetList, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      set_list = build(:set_list)
      expect(set_list).to be_valid
    end

    it 'is invalid without a name' do
      set_list = build(:set_list, name: nil)
      expect(set_list).not_to be_valid
      expect(set_list.errors[:name]).to include("can't be blank")
    end

    it 'is invalid without a band' do
      set_list = build(:set_list, band: nil)
      expect(set_list).not_to be_valid
      expect(set_list.errors[:band]).to include("can't be blank")
    end

    it 'is valid without a venue' do
      set_list = build(:set_list, venue: nil)
      expect(set_list).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to a band' do
      band = create(:band)
      set_list = create(:set_list, band: band)
      
      expect(set_list.band).to eq(band)
    end

    it 'belongs to a venue optionally' do
      venue = create(:venue)
      set_list = create(:set_list, venue: venue)
      
      expect(set_list.venue).to eq(venue)
    end

    it 'has many set list songs' do
      set_list = create(:set_list)
      set_list_song1 = create(:set_list_song, set_list: set_list)
      set_list_song2 = create(:set_list_song, set_list: set_list)
      
      expect(set_list.set_list_songs).to include(set_list_song1, set_list_song2)
    end

    it 'has many songs through set list songs' do
      set_list = create(:set_list)
      song1 = create(:song)
      song2 = create(:song)
      
      create(:set_list_song, set_list: set_list, song: song1)
      create(:set_list_song, set_list: set_list, song: song2)
      
      expect(set_list.songs).to include(song1, song2)
    end
  end

  describe 'scopes' do
    it 'orders by name' do
      set_list_c = create(:set_list, name: 'C Set List')
      set_list_a = create(:set_list, name: 'A Set List')
      set_list_b = create(:set_list, name: 'B Set List')
      
      expect(SetList.order(:name)).to eq([set_list_a, set_list_b, set_list_c])
    end
  end

  describe 'song management' do
    it 'can add songs to the set list' do
      set_list = create(:set_list)
      song = create(:song)
      
      set_list_song = SetListSong.create!(
        set_list: set_list,
        song: song,
        position: 1
      )
      
      expect(set_list.songs).to include(song)
      expect(set_list.set_list_songs).to include(set_list_song)
    end

    it 'can remove songs from the set list' do
      set_list = create(:set_list)
      song = create(:song)
      set_list_song = create(:set_list_song, set_list: set_list, song: song)
      
      set_list_song.destroy
      
      expect(set_list.reload.songs).not_to include(song)
    end

    it 'reorders songs when a song is removed' do
      set_list = create(:set_list)
      song1 = create(:song)
      song2 = create(:song)
      song3 = create(:song)
      
      sls1 = create(:set_list_song, set_list: set_list, song: song1, position: 1)
      sls2 = create(:set_list_song, set_list: set_list, song: song2, position: 2)
      sls3 = create(:set_list_song, set_list: set_list, song: song3, position: 3)
      
      # Remove song2
      sls2.destroy
      
      # Reorder remaining songs
      set_list.set_list_songs.order(:position).each_with_index do |sls, index|
        sls.update(position: index + 1)
      end
      
      expect(sls1.reload.position).to eq(1)
      expect(sls3.reload.position).to eq(2)
    end
  end

  describe 'copying' do
    it 'can be copied with a new name' do
      original_set_list = create(:set_list, name: 'Original Set List')
      song1 = create(:song)
      song2 = create(:song)
      
      create(:set_list_song, set_list: original_set_list, song: song1, position: 1)
      create(:set_list_song, set_list: original_set_list, song: song2, position: 2)
      
      new_name = "Copy - #{original_set_list.name}"
      new_set_list = SetList.create!(
        name: new_name,
        notes: original_set_list.notes,
        band: original_set_list.band
      )
      
      # Copy all songs with their positions
      original_set_list.set_list_songs.includes(:song).order(:position).each do |set_list_song|
        SetListSong.create!(
          set_list_id: new_set_list.id,
          song_id: set_list_song.song_id,
          position: set_list_song.position
        )
      end
      
      expect(new_set_list.name).to eq("Copy - Original Set List")
      expect(new_set_list.band).to eq(original_set_list.band)
      expect(new_set_list.songs.count).to eq(2)
      expect(new_set_list.songs).to include(song1, song2)
    end
  end

  describe 'destruction' do
    it 'destroys associated set list songs when destroyed' do
      set_list = create(:set_list)
      set_list_song = create(:set_list_song, set_list: set_list)
      
      expect { set_list.destroy }.to change(SetListSong, :count).by(-1)
    end
  end
end 