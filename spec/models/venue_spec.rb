require 'spec_helper'

RSpec.describe Venue, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      venue = build(:venue)
      expect(venue).to be_valid
    end

    it 'is invalid without a name' do
      venue = build(:venue, name: nil)
      expect(venue).not_to be_valid
      expect(venue.errors[:name]).to include("can't be blank")
    end

    it 'is invalid without a location' do
      venue = build(:venue, location: nil)
      expect(venue).not_to be_valid
      expect(venue.errors[:location]).to include("can't be blank")
    end

    it 'is invalid without a contact name' do
      venue = build(:venue, contact_name: nil)
      expect(venue).not_to be_valid
      expect(venue.errors[:contact_name]).to include("can't be blank")
    end

    it 'is invalid without a phone number' do
      venue = build(:venue, phone_number: nil)
      expect(venue).not_to be_valid
      expect(venue.errors[:phone_number]).to include("can't be blank")
    end
  end

  describe 'associations' do
    it 'belongs to a band' do
      band = create(:band)
      venue = create(:venue, band: band)
      
      expect(venue.band).to eq(band)
    end

    it 'can exist without a band (optional association)' do
      venue = build(:venue, band: nil)
      expect(venue).to be_valid
    end

    it 'has many gigs' do
      venue = create(:venue)
      gig1 = create(:gig, venue: venue)
      gig2 = create(:gig, venue: venue)
      
      expect(venue.gigs).to include(gig1, gig2)
    end
  end

  describe 'scopes' do
    it 'orders by name' do
      venue_c = create(:venue, name: 'C Venue')
      venue_a = create(:venue, name: 'A Venue')
      venue_b = create(:venue, name: 'B Venue')
      
      expect(Venue.order(:name)).to eq([venue_a, venue_b, venue_c])
    end
  end

  describe 'destruction' do
    it 'can be destroyed when it has no associated records' do
      venue = create(:venue)
      expect { venue.destroy }.to change(Venue, :count).by(-1)
    end

    it 'can be destroyed when it has gigs' do
      venue = create(:venue)
      gig = create(:gig, venue: venue)
      gig.destroy  # Clean up the set list first due to foreign key constraint
      expect { venue.destroy }.to change(Venue, :count).by(-1)
    end
  end
end 