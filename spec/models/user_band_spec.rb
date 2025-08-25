require_relative '../spec_helper'

RSpec.describe UserBand, type: :model do
  describe 'associations' do
    it 'belongs to a user' do
      user = create(:user)
      band = create(:band)
      user_band = UserBand.create!(user: user, band: band)
      
      expect(user_band.user).to eq(user)
    end

    it 'belongs to a band' do
      user = create(:user)
      band = create(:band)
      user_band = UserBand.create!(user: user, band: band)
      
      expect(user_band.band).to eq(band)
    end

    it 'requires a user association' do
      band = create(:band)
      user_band = UserBand.new(band: band)
      
      expect { user_band.save! }.to raise_error(ActiveRecord::NotNullViolation)
    end

    it 'requires a band association' do
      user = create(:user)
      user_band = UserBand.new(user: user)
      
      expect { user_band.save! }.to raise_error(ActiveRecord::NotNullViolation)
    end
  end

  describe 'join table functionality' do
    it 'creates the many-to-many relationship between users and bands' do
      user1 = create(:user)
      user2 = create(:user)
      band = create(:band)
      
      UserBand.create!(user: user1, band: band)
      UserBand.create!(user: user2, band: band)
      
      expect(band.users).to include(user1, user2)
      expect(user1.bands).to include(band)
      expect(user2.bands).to include(band)
    end

    it 'allows a user to be in multiple bands' do
      user = create(:user)
      band1 = create(:band)
      band2 = create(:band)
      
      UserBand.create!(user: user, band: band1)
      UserBand.create!(user: user, band: band2)
      
      expect(user.bands).to include(band1, band2)
      expect(user.bands.count).to eq(2)
    end

    it 'allows a band to have multiple users' do
      user1 = create(:user)
      user2 = create(:user)
      band = create(:band)
      
      UserBand.create!(user: user1, band: band)
      UserBand.create!(user: user2, band: band)
      
      expect(band.users).to include(user1, user2)
      expect(band.users.count).to eq(2)
    end
  end

  describe 'destruction' do
    it 'can be destroyed to remove user from band' do
      user = create(:user)
      band = create(:band)
      user.bands << band
      
      expect(user.bands).to include(band)
      expect(band.users).to include(user)
      
      # Remove using association methods instead of direct UserBand.destroy
      user.bands.delete(band)
      
      user.reload
      band.reload
      
      expect(user.bands).not_to include(band)
      expect(band.users).not_to include(user)
    end

    it 'does not destroy user or band when association is removed' do
      user = create(:user)
      band = create(:band)
      user.bands << band
      
      user.bands.delete(band)
      
      expect(User.find(user.id)).to eq(user)
      expect(Band.find(band.id)).to eq(band)
    end
  end
end