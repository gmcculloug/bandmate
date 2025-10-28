require 'spec_helper'

RSpec.describe PracticeAvailability, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      availability = build(:practice_availability)
      expect(availability).to be_valid
    end

    it 'is invalid without a day_of_week' do
      availability = build(:practice_availability, day_of_week: nil)
      expect(availability).not_to be_valid
      expect(availability.errors[:day_of_week]).to include("can't be blank")
    end

    it 'is invalid without an availability' do
      availability = build(:practice_availability, availability: nil)
      expect(availability).not_to be_valid
      expect(availability.errors[:availability]).to include("can't be blank")
    end

    it 'is invalid with an invalid day_of_week' do
      availability = build(:practice_availability, day_of_week: 7)
      expect(availability).not_to be_valid
      expect(availability.errors[:day_of_week]).to include("is not included in the list")
    end

    it 'is valid with valid day_of_week values' do
      (0..6).each do |day|
        availability = build(:practice_availability, day_of_week: day)
        expect(availability).to be_valid
      end
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

    it 'is invalid with duplicate day_of_week for same practice and user' do
      practice = create(:practice)
      user = create(:user)
      create(:practice_availability, practice: practice, user: user, day_of_week: 1)
      availability = build(:practice_availability, practice: practice, user: user, day_of_week: 1)
      expect(availability).not_to be_valid
      expect(availability.errors[:day_of_week]).to include("already has availability set for this day")
    end

    it 'allows same day_of_week for different practices' do
      practice1 = create(:practice)
      practice2 = create(:practice)
      user = create(:user)
      create(:practice_availability, practice: practice1, user: user, day_of_week: 1)
      availability = build(:practice_availability, practice: practice2, user: user, day_of_week: 1)
      expect(availability).to be_valid
    end

    it 'allows same day_of_week for different users' do
      practice = create(:practice)
      user1 = create(:user)
      user2 = create(:user)
      create(:practice_availability, practice: practice, user: user1, day_of_week: 1)
      availability = build(:practice_availability, practice: practice, user: user2, day_of_week: 1)
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
      @available = create(:practice_availability, practice: @practice, availability: 'available')
      @maybe = create(:practice_availability, practice: @practice, availability: 'maybe', day_of_week: 1)
      @not_available = create(:practice_availability, practice: @practice, availability: 'not_available', day_of_week: 2)
    end

    it 'returns only available responses' do
      expect(PracticeAvailability.available).to include(@available)
      expect(PracticeAvailability.available).not_to include(@maybe, @not_available)
    end

    it 'returns only maybe responses' do
      expect(PracticeAvailability.maybe).to include(@maybe)
      expect(PracticeAvailability.maybe).not_to include(@available, @not_available)
    end

    it 'returns only not_available responses' do
      expect(PracticeAvailability.not_available).to include(@not_available)
      expect(PracticeAvailability.not_available).not_to include(@available, @maybe)
    end

    it 'returns responses for a specific day' do
      expect(PracticeAvailability.for_day(0)).to include(@available)
      expect(PracticeAvailability.for_day(1)).to include(@maybe)
      expect(PracticeAvailability.for_day(2)).to include(@not_available)
      expect(PracticeAvailability.for_day(3)).not_to include(@available, @maybe, @not_available)
    end
  end

  describe 'instance methods' do
    describe '#day_name' do
      it 'returns the correct day name for each day_of_week' do
        days = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]
        days.each_with_index do |day_name, index|
          availability = build(:practice_availability, day_of_week: index)
          expect(availability.day_name).to eq(day_name)
        end
      end
    end

    describe '#availability_class' do
      it 'returns correct CSS class for each availability' do
        expect(build(:practice_availability, availability: 'available').availability_class).to eq('success')
        expect(build(:practice_availability, availability: 'maybe').availability_class).to eq('warning')
        expect(build(:practice_availability, availability: 'not_available').availability_class).to eq('danger')
      end
    end

    describe '#availability_display' do
      it 'returns correct display text for each availability' do
        expect(build(:practice_availability, availability: 'available').availability_display).to eq('Available')
        expect(build(:practice_availability, availability: 'maybe').availability_display).to eq('Maybe')
        expect(build(:practice_availability, availability: 'not_available').availability_display).to eq('Not Available')
      end
    end

    describe '#availability_icon' do
      it 'returns correct icon for each availability' do
        expect(build(:practice_availability, availability: 'available').availability_icon).to eq('✓')
        expect(build(:practice_availability, availability: 'maybe').availability_icon).to eq('?')
        expect(build(:practice_availability, availability: 'not_available').availability_icon).to eq('✗')
      end
    end

    describe '#has_suggested_times?' do
      it 'returns true when both start and end times are present' do
        availability = build(:practice_availability,
                           suggested_start_time: Time.parse('14:00'),
                           suggested_end_time: Time.parse('16:00'))
        expect(availability.has_suggested_times?).to be true
      end

      it 'returns false when start time is missing' do
        availability = build(:practice_availability,
                           suggested_start_time: nil,
                           suggested_end_time: Time.parse('16:00'))
        expect(availability.has_suggested_times?).to be false
      end

      it 'returns false when end time is missing' do
        availability = build(:practice_availability,
                           suggested_start_time: Time.parse('14:00'),
                           suggested_end_time: nil)
        expect(availability.has_suggested_times?).to be false
      end

      it 'returns false when both times are missing' do
        availability = build(:practice_availability,
                           suggested_start_time: nil,
                           suggested_end_time: nil)
        expect(availability.has_suggested_times?).to be false
      end
    end

    describe '#suggested_time_range' do
      it 'returns formatted time range when both times are present' do
        availability = build(:practice_availability,
                           suggested_start_time: Time.parse('14:00'),
                           suggested_end_time: Time.parse('16:00'))
        expect(availability.suggested_time_range).to eq('02:00 PM - 04:00 PM')
      end

      it 'returns nil when times are not present' do
        availability = build(:practice_availability,
                           suggested_start_time: nil,
                           suggested_end_time: nil)
        expect(availability.suggested_time_range).to be_nil
      end
    end

    describe '#suggested_duration_hours' do
      it 'calculates duration correctly for normal time range' do
        availability = build(:practice_availability,
                           suggested_start_time: Time.parse('14:00'),
                           suggested_end_time: Time.parse('16:30'))
        expect(availability.suggested_duration_hours).to eq(2.5)
      end

      it 'calculates duration correctly for overnight sessions' do
        availability = build(:practice_availability,
                           suggested_start_time: Time.parse('23:00'),
                           suggested_end_time: Time.parse('01:00'))
        expect(availability.suggested_duration_hours).to eq(2.0)
      end

      it 'returns nil when times are not present' do
        availability = build(:practice_availability,
                           suggested_start_time: nil,
                           suggested_end_time: nil)
        expect(availability.suggested_duration_hours).to be_nil
      end
    end
  end
end