require 'spec_helper'

RSpec.describe PracticeAvailability, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      availability = build(:practice_availability)
      expect(availability).to be_valid
    end

    it 'is invalid without a specific_date' do
      availability = build(:practice_availability, specific_date: nil)
      expect(availability).not_to be_valid
      expect(availability.errors[:specific_date]).to include("can't be blank")
    end

    it 'is invalid without an availability' do
      availability = build(:practice_availability, availability: nil)
      expect(availability).not_to be_valid
      expect(availability.errors[:availability]).to include("can't be blank")
    end

    it 'is invalid with an invalid availability value' do
      availability = build(:practice_availability, availability: 'invalid')
      expect(availability).not_to be_valid
      expect(availability.errors[:availability]).to include("is not included in the list")
    end

    it 'is valid with valid availability values' do
      %w[available maybe not_available].each do |availability_value|
        availability = build(:practice_availability, availability: availability_value)
        expect(availability).to be_valid
      end
    end

    it 'is invalid with duplicate specific_date for same practice and user' do
      practice = create(:practice)
      user = create(:user)
      date = Date.current
      create(:practice_availability, practice: practice, user: user, specific_date: date)
      availability = build(:practice_availability, practice: practice, user: user, specific_date: date)
      expect(availability).not_to be_valid
      expect(availability.errors[:specific_date]).to include("already has availability set for this date")
    end

    it 'allows same specific_date for different practices' do
      practice1 = create(:practice)
      practice2 = create(:practice)
      user = create(:user)
      date = Date.current
      create(:practice_availability, practice: practice1, user: user, specific_date: date)
      availability = build(:practice_availability, practice: practice2, user: user, specific_date: date)
      expect(availability).to be_valid
    end

    it 'allows same specific_date for different users' do
      practice = create(:practice)
      user1 = create(:user)
      user2 = create(:user)
      date = Date.current
      create(:practice_availability, practice: practice, user: user1, specific_date: date)
      availability = build(:practice_availability, practice: practice, user: user2, specific_date: date)
      expect(availability).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to a practice' do
      practice = create(:practice)
      availability = create(:practice_availability, practice: practice)
      expect(availability.practice).to eq(practice)
    end

    it 'belongs to a user' do
      user = create(:user)
      availability = create(:practice_availability, user: user)
      expect(availability.user).to eq(user)
    end
  end

  describe 'scopes' do
    before do
      @practice = create(:practice)
      @available = create(:practice_availability, practice: @practice, availability: 'available', specific_date: Date.current)
      @maybe = create(:practice_availability, practice: @practice, availability: 'maybe', specific_date: Date.current + 1.day)
      @not_available = create(:practice_availability, practice: @practice, availability: 'not_available', specific_date: Date.current + 2.days)
    end

    it 'returns only available responses' do
      expect(PracticeAvailability.available).to include(@available)
      expect(PracticeAvailability.available).not_to include(@maybe)
      expect(PracticeAvailability.available).not_to include(@not_available)
    end

    it 'returns only maybe responses' do
      expect(PracticeAvailability.maybe).to include(@maybe)
      expect(PracticeAvailability.maybe).not_to include(@available)
      expect(PracticeAvailability.maybe).not_to include(@not_available)
    end

    it 'returns only not_available responses' do
      expect(PracticeAvailability.not_available).to include(@not_available)
      expect(PracticeAvailability.not_available).not_to include(@available)
      expect(PracticeAvailability.not_available).not_to include(@maybe)
    end

    it 'returns responses for a specific date' do
      target_date = Date.current + 1.day
      expect(PracticeAvailability.for_date(target_date)).to include(@maybe)
      expect(PracticeAvailability.for_date(target_date)).not_to include(@available)
      expect(PracticeAvailability.for_date(target_date)).not_to include(@not_available)
    end
  end

  describe 'instance methods' do
    describe '#day_name' do
      it 'returns the correct day name for the specific_date' do
        availability = create(:practice_availability, specific_date: Date.parse('2023-10-15')) # Sunday
        expect(availability.day_name).to eq('Sunday')

        availability = create(:practice_availability, specific_date: Date.parse('2023-10-16')) # Monday
        expect(availability.day_name).to eq('Monday')

        availability = create(:practice_availability, specific_date: Date.parse('2023-10-17')) # Tuesday
        expect(availability.day_name).to eq('Tuesday')
      end
    end

    describe '#formatted_date' do
      it 'returns formatted date string' do
        availability = create(:practice_availability, specific_date: Date.parse('2023-10-15'))
        expect(availability.formatted_date).to eq('October 15, 2023')
      end
    end

    describe '#availability_class' do
      it 'returns correct CSS class for each availability' do
        available = create(:practice_availability, availability: 'available')
        expect(available.availability_class).to eq('success')

        maybe = create(:practice_availability, availability: 'maybe')
        expect(maybe.availability_class).to eq('warning')

        not_available = create(:practice_availability, availability: 'not_available')
        expect(not_available.availability_class).to eq('danger')
      end
    end

    describe '#availability_display' do
      it 'returns correct display text for each availability' do
        available = create(:practice_availability, availability: 'available')
        expect(available.availability_display).to eq('Available')

        maybe = create(:practice_availability, availability: 'maybe')
        expect(maybe.availability_display).to eq('Maybe')

        not_available = create(:practice_availability, availability: 'not_available')
        expect(not_available.availability_display).to eq('Not Available')
      end
    end

    describe '#availability_icon' do
      it 'returns correct icon for each availability' do
        available = create(:practice_availability, availability: 'available')
        expect(available.availability_icon).to eq('✓')

        maybe = create(:practice_availability, availability: 'maybe')
        expect(maybe.availability_icon).to eq('?')

        not_available = create(:practice_availability, availability: 'not_available')
        expect(not_available.availability_icon).to eq('✗')
      end
    end

    describe '#has_suggested_times?' do
      it 'returns true when both start and end times are present' do
        availability = create(:practice_availability,
                              suggested_start_time: Time.parse('2000-01-01 19:00:00'),
                              suggested_end_time: Time.parse('2000-01-01 21:00:00'))
        expect(availability.has_suggested_times?).to be true
      end

      it 'returns false when start time is missing' do
        availability = create(:practice_availability,
                              suggested_start_time: nil,
                              suggested_end_time: Time.parse('2000-01-01 21:00:00'))
        expect(availability.has_suggested_times?).to be false
      end

      it 'returns false when end time is missing' do
        availability = create(:practice_availability,
                              suggested_start_time: Time.parse('2000-01-01 19:00:00'),
                              suggested_end_time: nil)
        expect(availability.has_suggested_times?).to be false
      end

      it 'returns false when both times are missing' do
        availability = create(:practice_availability,
                              suggested_start_time: nil,
                              suggested_end_time: nil)
        expect(availability.has_suggested_times?).to be false
      end
    end

    describe '#suggested_time_range' do
      it 'returns formatted time range when both times are present' do
        availability = create(:practice_availability,
                              suggested_start_time: Time.parse('2000-01-01 19:00:00'),
                              suggested_end_time: Time.parse('2000-01-01 21:00:00'))

        # Verify the method returns a time range string with the expected format
        result = availability.suggested_time_range
        expect(result).to match(/\d{2}:\d{2} [AP]M - \d{2}:\d{2} [AP]M/)
        expect(result).not_to be_nil
      end

      it 'returns nil when times are not present' do
        availability = create(:practice_availability,
                              suggested_start_time: nil,
                              suggested_end_time: nil)
        expect(availability.suggested_time_range).to be_nil
      end
    end

    describe '#suggested_duration_hours' do
      it 'calculates duration correctly for normal time range' do
        availability = create(:practice_availability,
                              suggested_start_time: Time.parse('2000-01-01 19:00:00'),
                              suggested_end_time: Time.parse('2000-01-01 21:00:00'))
        expect(availability.suggested_duration_hours).to eq(2.0)
      end

      it 'calculates duration correctly for overnight sessions' do
        availability = create(:practice_availability,
                              suggested_start_time: Time.parse('2000-01-01 23:00:00'),
                              suggested_end_time: Time.parse('2000-01-01 01:00:00'))
        expect(availability.suggested_duration_hours).to eq(2.0)
      end

      it 'returns nil when times are not present' do
        availability = create(:practice_availability,
                              suggested_start_time: nil,
                              suggested_end_time: nil)
        expect(availability.suggested_duration_hours).to be_nil
      end
    end
  end
end