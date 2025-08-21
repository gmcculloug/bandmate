require 'spec_helper'

RSpec.describe GigSong, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      gig_song = build(:gig_song)
      expect(gig_song).to be_valid
    end

    it 'is invalid without a position' do
      gig_song = build(:gig_song, position: nil)
      expect(gig_song).not_to be_valid
      expect(gig_song.errors[:position]).to include("can't be blank")
    end

    it 'is invalid with a position of zero' do
      gig_song = build(:gig_song, position: 0)
      expect(gig_song).not_to be_valid
      expect(gig_song.errors[:position]).to include('must be greater than 0')
    end

    it 'is invalid with a negative position' do
      gig_song = build(:gig_song, position: -1)
      expect(gig_song).not_to be_valid
      expect(gig_song.errors[:position]).to include('must be greater than 0')
    end

    it 'is valid with a positive position' do
      gig_song = build(:gig_song, position: 1)
      expect(gig_song).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to a gig' do
      gig = create(:gig)
      gig_song = create(:gig_song, gig: gig)
      
      expect(gig_song.gig).to eq(gig)
    end

    it 'belongs to a song' do
      song = create(:song)
      gig_song = create(:gig_song, song: song)
      
      expect(gig_song.song).to eq(song)
    end
  end

  describe 'position management' do
    it 'can be reordered' do
      gig = create(:gig)
      song1 = create(:song)
      song2 = create(:song)
      song3 = create(:song)
      
      sls1 = create(:gig_song, gig: gig, song: song1, position: 1)
      sls2 = create(:gig_song, gig: gig, song: song2, position: 2)
      sls3 = create(:gig_song, gig: gig, song: song3, position: 3)
      
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