require 'spec_helper'

RSpec.describe GigSong, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      gig_song = build(:gig_song)
      expect(gig_song).to be_valid
    end

    it 'requires a gig' do
      gig_song = build(:gig_song, gig: nil)
      expect(gig_song).not_to be_valid
      expect(gig_song.errors[:gig]).to include("can't be blank")
    end

    it 'requires a song' do
      gig_song = build(:gig_song, song: nil)
      expect(gig_song).not_to be_valid
      expect(gig_song.errors[:song]).to include("can't be blank")
    end

    it 'requires a position' do
      gig_song = build(:gig_song, position: nil)
      expect(gig_song).not_to be_valid
      expect(gig_song.errors[:position]).to include("can't be blank")
    end

    it 'requires position to be greater than 0' do
      gig_song = build(:gig_song, position: 0)
      expect(gig_song).not_to be_valid
      expect(gig_song.errors[:position]).to include("must be greater than 0")
    end

    it 'requires position to be unique within a gig' do
      gig = create(:gig)
      create(:gig_song, gig: gig, position: 1)
      
      duplicate_gig_song = build(:gig_song, gig: gig, position: 1)
      expect(duplicate_gig_song).not_to be_valid
      expect(duplicate_gig_song.errors[:position]).to include("has already been taken")
    end

    it 'allows same position in different gigs' do
      gig1 = create(:gig)
      gig2 = create(:gig)
      
      gig_song1 = create(:gig_song, gig: gig1, position: 1)
      gig_song2 = build(:gig_song, gig: gig2, position: 1)
      
      expect(gig_song1).to be_valid
      expect(gig_song2).to be_valid
    end

    it 'requires a set number' do
      gig_song = build(:gig_song, set_number: nil)
      expect(gig_song).not_to be_valid
      expect(gig_song.errors[:set_number]).to include("can't be blank")
    end

    it 'requires set number to be greater than 0' do
      gig_song = build(:gig_song, set_number: 0)
      expect(gig_song).not_to be_valid
      expect(gig_song.errors[:set_number]).to include("must be greater than 0")
    end

    it 'requires set number to be less than or equal to 3' do
      gig_song = build(:gig_song, set_number: 4)
      expect(gig_song).not_to be_valid
      expect(gig_song.errors[:set_number]).to include("must be less than or equal to 3")
    end

    it 'allows set number 1, 2, and 3' do
      [1, 2, 3].each do |set_num|
        gig_song = build(:gig_song, set_number: set_num)
        expect(gig_song).to be_valid
      end
    end
  end

  describe 'associations' do
    it 'belongs to a gig' do
      gig_song = create(:gig_song)
      expect(gig_song.gig).to be_present
      expect(gig_song.gig).to be_a(Gig)
    end

    it 'belongs to a song' do
      gig_song = create(:gig_song)
      expect(gig_song.song).to be_present
      expect(gig_song.song).to be_a(Song)
    end
  end

  describe 'destruction' do
    it 'can be destroyed' do
      gig_song = create(:gig_song)
      expect { gig_song.destroy }.to change(GigSong, :count).by(-1)
    end

    it 'does not destroy associated gig' do
      gig_song = create(:gig_song)
      gig = gig_song.gig
      
      gig_song.destroy
      expect(Gig.find(gig.id)).to be_present
    end

    it 'does not destroy associated song' do
      gig_song = create(:gig_song)
      song = gig_song.song
      
      gig_song.destroy
      expect(Song.find(song.id)).to be_present
    end
  end

  describe 'position management' do
    it 'can be reordered within a gig' do
      gig = create(:gig)
      song1 = create(:song)
      song2 = create(:song)

      gig_song1 = create(:gig_song, gig: gig, song: song1, position: 1)
      gig_song2 = create(:gig_song, gig: gig, song: song2, position: 2)

      # Swap positions using transaction to avoid uniqueness constraint conflict
      ActiveRecord::Base.transaction do
        gig_song1.update_column(:position, -1)  # temp position
        gig_song2.update_column(:position, 1)
        gig_song1.update_column(:position, 2)
      end

      expect(gig_song1.reload.position).to eq(2)
      expect(gig_song2.reload.position).to eq(1)
    end
  end
end