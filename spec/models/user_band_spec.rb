require 'spec_helper'

RSpec.describe UserBand, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      user_band = build(:user_band)
      expect(user_band).to be_valid
    end

    it 'requires a user' do
      user_band = build(:user_band, user: nil)
      expect(user_band).not_to be_valid
      expect(user_band.errors[:user]).to include("can't be blank")
    end

    it 'requires a band' do
      user_band = build(:user_band, band: nil)
      expect(user_band).not_to be_valid
      expect(user_band.errors[:band]).to include("can't be blank")
    end

    it 'requires unique user-band combination' do
      user = create(:user)
      band = create(:band)
      create(:user_band, user: user, band: band)
      
      duplicate_user_band = build(:user_band, user: user, band: band)
      expect(duplicate_user_band).not_to be_valid
      expect(duplicate_user_band.errors[:user_id]).to include("has already been taken")
    end

    it 'allows same user with different bands' do
      user = create(:user)
      band1 = create(:band)
      band2 = create(:band)
      
      user_band1 = create(:user_band, user: user, band: band1)
      user_band2 = build(:user_band, user: user, band: band2)
      
      expect(user_band1).to be_valid
      expect(user_band2).to be_valid
    end

    it 'allows same band with different users' do
      user1 = create(:user)
      user2 = create(:user)
      band = create(:band)
      
      user_band1 = create(:user_band, user: user1, band: band)
      user_band2 = build(:user_band, user: user2, band: band)
      
      expect(user_band1).to be_valid
      expect(user_band2).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to a user' do
      user_band = create(:user_band)
      expect(user_band.user).to be_present
      expect(user_band.user).to be_a(User)
    end

    it 'belongs to a band' do
      user_band = create(:user_band)
      expect(user_band.band).to be_present
      expect(user_band.band).to be_a(Band)
    end
  end

  describe 'destruction' do
    it 'can be destroyed' do
      user_band = create(:user_band)
      expect { user_band.destroy }.to change(UserBand, :count).by(-1)
    end

    it 'does not destroy associated user' do
      user_band = create(:user_band)
      user = user_band.user
      
      user_band.destroy
      expect(User.find(user.id)).to be_present
    end

    it 'does not destroy associated band' do
      user_band = create(:user_band)
      band = user_band.band
      
      user_band.destroy
      expect(Band.find(band.id)).to be_present
    end
  end
end