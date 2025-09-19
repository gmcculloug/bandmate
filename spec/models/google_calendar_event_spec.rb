require 'spec_helper'

RSpec.describe GoogleCalendarEvent, type: :model do
  describe 'associations' do
    it 'belongs to band' do
      expect(described_class.reflect_on_association(:band).macro).to eq(:belongs_to)
    end

    it 'belongs to gig' do
      expect(described_class.reflect_on_association(:gig).macro).to eq(:belongs_to)
    end
  end

  describe 'validations' do
    let(:band) { create(:band) }
    let(:gig) { create(:gig, band: band) }

    it 'validates presence of google_event_id' do
      event = build(:google_calendar_event, google_event_id: nil)
      expect(event).not_to be_valid
      expect(event.errors[:google_event_id]).to include("can't be blank")
    end

    it 'validates presence of band' do
      event = build(:google_calendar_event, band: nil)
      expect(event).not_to be_valid
      expect(event.errors[:band]).to include("can't be blank")
    end

    it 'validates presence of gig' do
      event = build(:google_calendar_event, gig: nil)
      expect(event).not_to be_valid
      expect(event.errors[:gig]).to include("can't be blank")
    end

    it 'validates uniqueness of google_event_id scoped to band_id' do
      existing_event = create(:google_calendar_event, band: band, gig: gig)
      new_gig = create(:gig, band: band)

      duplicate_event = build(:google_calendar_event,
        google_event_id: existing_event.google_event_id,
        band: band,
        gig: new_gig
      )

      expect(duplicate_event).not_to be_valid
      expect(duplicate_event.errors[:google_event_id]).to include("has already been taken")
    end

    it 'allows same google_event_id for different bands' do
      other_band = create(:band)
      other_gig = create(:gig, band: other_band)

      existing_event = create(:google_calendar_event, band: band, gig: gig)

      duplicate_event = build(:google_calendar_event,
        google_event_id: existing_event.google_event_id,
        band: other_band,
        gig: other_gig
      )

      expect(duplicate_event).to be_valid
    end
  end

  describe 'scopes' do
    let(:band) { create(:band) }
    let(:gig1) { create(:gig, band: band) }
    let(:gig2) { create(:gig, band: band) }

    describe '.recently_synced' do
      it 'returns events synced within the last hour' do
        recent_event = create(:google_calendar_event,
          band: band,
          gig: gig1,
          last_synced_at: 30.minutes.ago
        )
        old_event = create(:google_calendar_event,
          band: band,
          gig: gig2,
          last_synced_at: 2.hours.ago
        )

        expect(GoogleCalendarEvent.recently_synced).to include(recent_event)
        expect(GoogleCalendarEvent.recently_synced).not_to include(old_event)
      end
    end

    describe '.needs_sync' do
      it 'returns events that need syncing (older than 1 hour)' do
        recent_event = create(:google_calendar_event,
          band: band,
          gig: gig1,
          last_synced_at: 30.minutes.ago
        )
        old_event = create(:google_calendar_event,
          band: band,
          gig: gig2,
          last_synced_at: 2.hours.ago
        )

        expect(GoogleCalendarEvent.needs_sync).to include(old_event)
        expect(GoogleCalendarEvent.needs_sync).not_to include(recent_event)
      end
    end
  end

  describe 'factory' do
    it 'creates a valid google calendar event' do
      event = create(:google_calendar_event)
      expect(event).to be_valid
      expect(event.google_event_id).to be_present
      expect(event.band).to be_present
      expect(event.gig).to be_present
    end
  end
end