require_relative '../spec_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      user = User.new(username: 'testuser', password: 'password123')
      expect(user).to be_valid
    end

    it 'requires a username' do
      user = User.new(password: 'password123')
      expect(user).not_to be_valid
      expect(user.errors[:username]).to include("can't be blank")
    end

    it 'requires a unique username' do
      User.create!(username: 'testuser', password: 'password123')
      user = User.new(username: 'testuser', password: 'password456')
      expect(user).not_to be_valid
      expect(user.errors[:username]).to include("has already been taken")
    end

    it 'requires a password of at least 6 characters' do
      user = User.new(username: 'testuser', password: '12345')
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("is too short (minimum is 6 characters)")
    end
  end

  describe 'associations' do
    it 'has many bands through user_bands' do
      user = User.create!(username: 'testuser', password: 'password123')
      band1 = Band.create!(name: 'Test Band 1')
      band2 = Band.create!(name: 'Test Band 2')
      
      user.bands << band1
      user.bands << band2
      
      expect(user.bands).to include(band1, band2)
      expect(user.bands.count).to eq(2)
    end
  end

  describe 'password hashing' do
    it 'hashes the password using bcrypt' do
      user = User.create!(username: 'testuser', password: 'password123')
      expect(user.password_digest).not_to eq('password123')
      expect(user.authenticate('password123')).to eq(user)
      expect(user.authenticate('wrongpassword')).to be_falsey
    end
  end
end