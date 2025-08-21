require_relative '../spec_helper'

RSpec.describe BlackoutDate, type: :model do
  let(:user) { create(:user) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      blackout_date = BlackoutDate.new(
        user: user,
        blackout_date: Date.current
      )
      expect(blackout_date).to be_valid
    end

    it 'requires a blackout_date' do
      blackout_date = BlackoutDate.new(user: user)
      expect(blackout_date).not_to be_valid
      expect(blackout_date.errors[:blackout_date]).to include("can't be blank")
    end

    it 'requires a user' do
      blackout_date = BlackoutDate.new(blackout_date: Date.current)
      expect(blackout_date).not_to be_valid
    end

    it 'prevents duplicate blackout dates for the same user' do
      date = Date.current
      BlackoutDate.create!(user: user, blackout_date: date)
      
      duplicate = BlackoutDate.new(user: user, blackout_date: date)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include("has already been taken")
    end

    it 'allows different users to have blackout dates on the same date' do
      other_user = create(:user, username: 'otheruser')
      date = Date.current
      
      BlackoutDate.create!(user: user, blackout_date: date)
      blackout_date = BlackoutDate.new(user: other_user, blackout_date: date)
      
      expect(blackout_date).to be_valid
    end

    it 'does not allow blackout dates in the past' do
      past_date = 1.day.ago.to_date
      blackout_date = BlackoutDate.new(user: user, blackout_date: past_date)
      
      expect(blackout_date).not_to be_valid
      expect(blackout_date.errors[:blackout_date]).to include("cannot be in the past")
    end

    it 'allows blackout dates for today' do
      today = Date.current
      blackout_date = BlackoutDate.new(user: user, blackout_date: today)
      
      expect(blackout_date).to be_valid
    end

    it 'allows blackout dates in the future' do
      future_date = 1.day.from_now.to_date
      blackout_date = BlackoutDate.new(user: user, blackout_date: future_date)
      
      expect(blackout_date).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to a user' do
      blackout_date = BlackoutDate.new
      expect(blackout_date).to respond_to(:user)
    end
  end

  describe 'scopes' do
    before do
      @current_date = Date.current
      @future_date_1 = 1.week.from_now.to_date
      @future_date_2 = 2.weeks.from_now.to_date
      
      create(:blackout_date, user: user, blackout_date: @current_date)
      create(:blackout_date, user: user, blackout_date: @future_date_1)
      create(:blackout_date, user: user, blackout_date: @future_date_2)
    end

    describe '.for_date_range' do
      it 'returns blackout dates within the specified range' do
        start_date = @current_date
        end_date = @future_date_1
        
        blackouts = BlackoutDate.for_date_range(start_date, end_date)
        
        expect(blackouts.count).to eq(2)
        expect(blackouts.map(&:blackout_date)).to contain_exactly(@current_date, @future_date_1)
      end

      it 'excludes dates outside the range' do
        start_date = @current_date
        end_date = @current_date
        
        blackouts = BlackoutDate.for_date_range(start_date, end_date)
        
        expect(blackouts.count).to eq(1)
        expect(blackouts.first.blackout_date).to eq(@current_date)
      end
    end
  end
end