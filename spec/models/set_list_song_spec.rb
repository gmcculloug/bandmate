require 'spec_helper'

RSpec.describe SetListSong, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      set_list_song = build(:set_list_song)
      expect(set_list_song).to be_valid
    end

    it 'is invalid without a position' do
      set_list_song = build(:set_list_song, position: nil)
      expect(set_list_song).not_to be_valid
      expect(set_list_song.errors[:position]).to include("can't be blank")
    end

    it 'is invalid with a position of zero' do
      set_list_song = build(:set_list_song, position: 0)
      expect(set_list_song).not_to be_valid
      expect(set_list_song.errors[:position]).to include('must be greater than 0')
    end

    it 'is invalid with a negative position' do
      set_list_song = build(:set_list_song, position: -1)
      expect(set_list_song).not_to be_valid
      expect(set_list_song.errors[:position]).to include('must be greater than 0')
    end

    it 'is valid with a positive position' do
      set_list_song = build(:set_list_song, position: 1)
      expect(set_list_song).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to a set list' do
      set_list = create(:set_list)
      set_list_song = create(:set_list_song, set_list: set_list)
      
      expect(set_list_song.set_list).to eq(set_list)
    end

    it 'belongs to a song' do
      song = create(:song)
      set_list_song = create(:set_list_song, song: song)
      
      expect(set_list_song.song).to eq(song)
    end
  end

  describe 'position management' do
    it 'can be reordered' do
      set_list = create(:set_list)
      song1 = create(:song)
      song2 = create(:song)
      song3 = create(:song)
      
      sls1 = create(:set_list_song, set_list: set_list, song: song1, position: 1)
      sls2 = create(:set_list_song, set_list: set_list, song: song2, position: 2)
      sls3 = create(:set_list_song, set_list: set_list, song: song3, position: 3)
      
      # Reorder: song3, song1, song2
      sls3.update(position: 1)
      sls1.update(position: 2)
      sls2.update(position: 3)
      
      expect(sls3.reload.position).to eq(1)
      expect(sls1.reload.position).to eq(2)
      expect(sls2.reload.position).to eq(3)
    end
  end
end 