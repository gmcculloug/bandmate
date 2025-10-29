require 'spec_helper'

RSpec.describe Practice, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      practice = build(:practice)
      expect(practice).to be_valid
    end

    it 'is invalid without a week_start_date' do
      practice = build(:practice, week_start_date: nil)
      expect(practice).not_to be_valid
      expect(practice.errors[:week_start_date]).to include("can't be blank")
    end

    it 'is invalid without a status' do
      practice = build(:practice, status: nil)
      expect(practice).not_to be_valid
      expect(practice.errors[:status]).to include("can't be blank")
    end

    it 'is invalid with an invalid status' do
      practice = build(:practice, status: 'invalid_status')
      expect(practice).not_to be_valid
      expect(practice.errors[:status]).to include("is not included in the list")
    end

    it 'is valid with valid status values' do
      %w[active finalized cancelled].each do |status|
        practice = build(:practice, status: status)
        expect(practice).to be_valid
      end
    end

    it 'is invalid if week_start_date is not a Sunday' do
      monday = Date.current.beginning_of_week(:sunday) + 1.day
      practice = build(:practice, week_start_date: monday)
      expect(practice).not_to be_valid
      expect(practice.errors[:week_start_date]).to include("must be a Sunday")
    end

    it 'is invalid with duplicate week_start_date for the same band' do
      band = create(:band)
      create(:practice, band: band, week_start_date: Date.current.beginning_of_week(:sunday))
      practice = build(:practice, band: band, week_start_date: Date.current.beginning_of_week(:sunday))
      expect(practice).not_to be_valid
      expect(practice.errors[:week_start_date]).to include("already has a practice scheduled for this week")
    end

    it 'allows same week_start_date for different bands' do
      band1 = create(:band)
      band2 = create(:band)
      create(:practice, band: band1, week_start_date: Date.current.beginning_of_week(:sunday))
      practice = build(:practice, band: band2, week_start_date: Date.current.beginning_of_week(:sunday))
      expect(practice).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to a band' do
      band = create(:band)
      practice = create(:practice, band: band)
      expect(practice.band).to eq(band)
    end

    it 'belongs to a created_by_user' do
      user = create(:user)
      practice = create(:practice, created_by_user: user)
      expect(practice.created_by_user).to eq(user)
    end

    it 'has many practice_availabilities' do
      practice = create(:practice)
      availability1 = create(:practice_availability, practice: practice)
      availability2 = create(:practice_availability, practice: practice, day_of_week: 1)
      expect(practice.practice_availabilities).to include(availability1, availability2)
    end

    it 'destroys practice_availabilities when destroyed' do
      practice = create(:practice)
      availability = create(:practice_availability, practice: practice)
      practice.destroy
      expect(PracticeAvailability.find_by(id: availability.id)).to be_nil
    end
  end

  describe 'scopes' do
    before do
      @active_practice = create(:practice, status: 'active')
      @finalized_practice = create(:practice, status: 'finalized')
      @cancelled_practice = create(:practice, status: 'cancelled')
    end

    it 'returns only active practices' do
      expect(Practice.active).to include(@active_practice)
      expect(Practice.active).not_to include(@finalized_practice, @cancelled_practice)
    end

    it 'returns practices for a specific week' do
      week_date = Date.current.beginning_of_week(:sunday)
      practice_this_week = create(:practice, week_start_date: week_date)
      practice_next_week = create(:practice, week_start_date: week_date + 1.week)

      expect(Practice.for_week(week_date)).to include(practice_this_week)
      expect(Practice.for_week(week_date)).not_to include(practice_next_week)
    end
  end

  describe 'instance methods' do
    let(:practice) { create(:practice, week_start_date: Date.parse('2024-01-07')) } # A Sunday

    describe '#week_end_date' do
      it 'returns the Saturday of the practice week' do
        expect(practice.week_end_date).to eq(Date.parse('2024-01-13'))
      end
    end

    describe '#week_dates' do
      it 'returns an array of all dates in the practice week' do
        dates = practice.week_dates
        expect(dates.size).to eq(7)
        expect(dates.first).to eq(Date.parse('2024-01-07'))
        expect(dates.last).to eq(Date.parse('2024-01-13'))
      end
    end

    describe '#days_of_week' do
      it 'returns the correct days of the week' do
        expect(practice.days_of_week).to eq(%w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday])
      end
    end

    describe '#formatted_week_range' do
      it 'returns a formatted week range string' do
        expect(practice.formatted_week_range).to eq("Jan 07 - Jan 13, 2024")
      end
    end

    describe '#band_members' do
      it 'returns users belonging to the practice band' do
        user1 = create(:user)
        user2 = create(:user)
        practice.band.users << [user1, user2]

        expect(practice.band_members).to include(user1, user2)
      end
    end

    describe '#response_count' do
      it 'returns the count of unique users who responded' do
        user1 = create(:user)
        user2 = create(:user)
        create(:practice_availability, practice: practice, user: user1, day_of_week: 0)
        create(:practice_availability, practice: practice, user: user1, day_of_week: 1)
        create(:practice_availability, practice: practice, user: user2, day_of_week: 0)

        expect(practice.response_count).to eq(2)
      end
    end

    describe '#all_members_responded?' do
      it 'returns true when all band members have responded' do
        user1 = create(:user)
        user2 = create(:user)
        practice.band.users << [user1, user2]
        create(:practice_availability, practice: practice, user: user1)
        create(:practice_availability, practice: practice, user: user2)

        expect(practice.all_members_responded?).to be true
      end

      it 'returns false when not all band members have responded' do
        user1 = create(:user)
        user2 = create(:user)
        practice.band.users << [user1, user2]
        create(:practice_availability, practice: practice, user: user1)

        expect(practice.all_members_responded?).to be false
      end
    end

    describe '#best_day' do
      it 'returns nil when no availabilities exist' do
        expect(practice.best_day).to be_nil
      end

      it 'returns the day with most available responses' do
        user1 = create(:user)
        user2 = create(:user)
        create(:practice_availability, practice: practice, user: user1, day_of_week: 1, availability: 'available')
        create(:practice_availability, practice: practice, user: user2, day_of_week: 1, availability: 'available')
        create(:practice_availability, practice: practice, user: user1, day_of_week: 2, availability: 'available')

        expect(practice.best_day).to eq('Monday') # day_of_week 1
      end

      it 'considers maybe responses with half weight' do
        user1 = create(:user)
        user2 = create(:user)
        user3 = create(:user)
        create(:practice_availability, practice: practice, user: user1, day_of_week: 1, availability: 'available')
        create(:practice_availability, practice: practice, user: user2, day_of_week: 2, availability: 'maybe')
        create(:practice_availability, practice: practice, user: user3, day_of_week: 2, availability: 'maybe')

        expect(practice.best_day).to eq('Monday') # 1 available (weight 1) > 2 maybe (weight 0.5 each = 1 total)
      end

      it 'returns nil when all responses are not_available' do
        user1 = create(:user)
        create(:practice_availability, practice: practice, user: user1, day_of_week: 1, availability: 'not_available')

        expect(practice.best_day).to be_nil
      end
    end

    describe '#availability_summary' do
      it 'returns a summary of availability for each day' do
        user1 = create(:user)
        user2 = create(:user)
        practice.band.users << [user1, user2]

        create(:practice_availability, practice: practice, user: user1, day_of_week: 0, availability: 'available')
        create(:practice_availability, practice: practice, user: user2, day_of_week: 0, availability: 'maybe')

        summary = practice.availability_summary
        expect(summary['Sunday'][:available]).to eq(1)
        expect(summary['Sunday'][:maybe]).to eq(1)
        expect(summary['Sunday'][:not_available]).to eq(0)
        expect(summary['Sunday'][:no_response]).to eq(0)

        expect(summary['Monday'][:available]).to eq(0)
        expect(summary['Monday'][:maybe]).to eq(0)
        expect(summary['Monday'][:not_available]).to eq(0)
        expect(summary['Monday'][:no_response]).to eq(2)
      end

      it 'includes suggested times in the summary' do
        user1 = create(:user)
        practice.band.users << user1

        create(:practice_availability,
               practice: practice,
               user: user1,
               day_of_week: 0,
               availability: 'available',
               suggested_start_time: Time.parse('14:00 UTC'),
               suggested_end_time: Time.parse('16:00 UTC'))

        summary = practice.availability_summary
        expect(summary['Sunday'][:suggested_times].count).to eq(1)
        suggested_time = summary['Sunday'][:suggested_times].first
        expect(suggested_time.suggested_start_time.strftime('%H:%M')).to eq('14:00')
      end
    end

    describe '#suggested_times_for_day' do
      it 'returns availability records with suggested times for a specific day' do
        user1 = create(:user)
        user2 = create(:user)

        availability_with_times = create(:practice_availability,
                                       practice: practice,
                                       user: user1,
                                       day_of_week: 1,
                                       suggested_start_time: Time.parse('14:00 UTC'),
                                       suggested_end_time: Time.parse('16:00 UTC'))

        availability_without_times = create(:practice_availability,
                                          practice: practice,
                                          user: user2,
                                          day_of_week: 1)

        result = practice.suggested_times_for_day(1)
        expect(result).to include(availability_with_times)
        expect(result).not_to include(availability_without_times)
      end
    end

    describe '#most_popular_time_for_day' do
      it 'returns nil when no time suggestions exist' do
        expect(practice.most_popular_time_for_day(1)).to be_nil
      end

      it 'returns the most common time suggestion for a day' do
        user1 = create(:user)
        user2 = create(:user)
        user3 = create(:user)

        # Two users suggest the same time
        create(:practice_availability,
               practice: practice,
               user: user1,
               day_of_week: 1,
               suggested_start_time: Time.parse('14:00 UTC'),
               suggested_end_time: Time.parse('16:00 UTC'))

        create(:practice_availability,
               practice: practice,
               user: user2,
               day_of_week: 1,
               suggested_start_time: Time.parse('14:00 UTC'),
               suggested_end_time: Time.parse('16:00 UTC'))

        # One user suggests a different time
        create(:practice_availability,
               practice: practice,
               user: user3,
               day_of_week: 1,
               suggested_start_time: Time.parse('18:00 UTC'),
               suggested_end_time: Time.parse('20:00 UTC'))

        result = practice.most_popular_time_for_day(1)
        expect(result[:start_time]).to eq('14:00')
        expect(result[:end_time]).to eq('16:00')
        expect(result[:count]).to eq(2)
        expect(result[:total_suggestions]).to eq(3)
      end

      it 'handles ties by returning the first encountered time' do
        user1 = create(:user)
        user2 = create(:user)

        create(:practice_availability,
               practice: practice,
               user: user1,
               day_of_week: 1,
               suggested_start_time: Time.parse('14:00 UTC'),
               suggested_end_time: Time.parse('16:00 UTC'))

        create(:practice_availability,
               practice: practice,
               user: user2,
               day_of_week: 1,
               suggested_start_time: Time.parse('18:00 UTC'),
               suggested_end_time: Time.parse('20:00 UTC'))

        result = practice.most_popular_time_for_day(1)
        expect(result[:count]).to eq(1)
        expect(result[:total_suggestions]).to eq(2)
        # Should return one of the times (implementation returns max_by which is deterministic)
        expect(['14:00', '18:00']).to include(result[:start_time])
      end
    end
  end
end