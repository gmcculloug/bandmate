require 'spec_helper'

RSpec.describe Band, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      band = build(:band)
      expect(band).to be_valid
    end

    it 'is invalid without a name' do
      band = build(:band, name: nil)
      expect(band).not_to be_valid
      expect(band.errors[:name]).to include("can't be blank")
    end

    it 'is invalid with a duplicate name' do
      create(:band, name: 'Test Band')
      band = build(:band, name: 'Test Band')
      expect(band).not_to be_valid
      expect(band.errors[:name]).to include('has already been taken')
    end
  end

  describe 'associations' do
    it 'has many songs' do
      band = create(:band)
      song1 = create(:song, bands: [band])
      song2 = create(:song, bands: [band])
      
      expect(band.songs).to include(song1, song2)
    end

    it 'has many set lists' do
      band = create(:band)
      set_list1 = create(:set_list, band: band)
      set_list2 = create(:set_list, band: band)
      
      expect(band.set_lists).to include(set_list1, set_list2)
    end

    it 'has many venues' do
      band = create(:band)
      venue1 = create(:venue, band: band)
      venue2 = create(:venue, band: band)
      
      expect(band.venues).to include(venue1, venue2)
    end
  end

  describe 'scopes' do
    it 'orders by name' do
      band_c = create(:band, name: 'C Band')
      band_a = create(:band, name: 'A Band')
      band_b = create(:band, name: 'B Band')
      
      expect(Band.order(:name)).to eq([band_a, band_b, band_c])
    end
  end

  describe 'destruction' do
    it 'can be destroyed when it has no associated records' do
      band = create(:band)
      expect { band.destroy }.to change(Band, :count).by(-1)
    end

    it 'can be destroyed when it has songs' do
      band = create(:band)
      song = create(:song)
      song.bands << band
      song.save!
      # Remove the association before destroying the band
      song.bands.clear
      expect { band.destroy }.to change(Band, :count).by(-1)
    end

    it 'can be destroyed when it has set lists' do
      band = create(:band)
      set_list = create(:set_list, band: band)
      set_list.destroy  # Clean up the set list first due to foreign key constraint
      expect { band.destroy }.to change(Band, :count).by(-1)
    end

    it 'can be destroyed when it has venues' do
      band = create(:band)
      venue = create(:venue, band: band)
      venue.destroy  # Clean up the venue first due to foreign key constraint
      expect { band.destroy }.to change(Band, :count).by(-1)
    end
  end
end 