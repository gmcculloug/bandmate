require 'spec_helper'

RSpec.describe GoogleCalendarEvent, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      google_event = build(:google_calendar_event)
      expect(google_event).to be_valid
    end

    it 'requires a band' do
      google_event = build(:google_calendar_event, band: nil)
      expect(google_event).not_to be_valid
      expect(google_event.errors[:band]).to include("can't be blank")
    end

    it 'requires a gig' do
      google_event = build(:google_calendar_event, gig: nil)
      expect(google_event).not_to be_valid
      expect(google_event.errors[:gig]).to include("can't be blank")
    end

    it 'requires a google event id' do
      google_event = build(:google_calendar_event, google_event_id: nil)
      expect(google_event).not_to be_valid
      expect(google_event.errors[:google_event_id]).to include("can't be blank")
    end

    it 'requires google event id to be unique within a band' do
      band = create(:band)
      gig1 = create(:gig, band: band)
      gig2 = create(:gig, band: band)
      
      create(:google_calendar_event, band: band, gig: gig1, google_event_id: 'event_123')
      
      duplicate_event = build(:google_calendar_event, band: band, gig: gig2, google_event_id: 'event_123')
      expect(duplicate_event).not_to be_valid
      expect(duplicate_event.errors[:google_event_id]).to include("has already been taken")
    end

    it 'allows same google event id for different bands' do
      band1 = create(:band)
      band2 = create(:band)
      gig1 = create(:gig, band: band1)
      gig2 = create(:gig, band: band2)
      
      event1 = create(:google_calendar_event, band: band1, gig: gig1, google_event_id: 'event_123')
      event2 = build(:google_calendar_event, band: band2, gig: gig2, google_event_id: 'event_123')
      
      expect(event1).to be_valid
      expect(event2).to be_valid
    end

    it 'requires last synced at' do
      google_event = build(:google_calendar_event, last_synced_at: nil)
      expect(google_event).not_to be_valid
      expect(google_event.errors[:last_synced_at]).to include("can't be blank")
    end
  end

  describe 'associations' do
    it 'belongs to a band' do
      google_event = create(:google_calendar_event)
      expect(google_event.band).to be_present
      expect(google_event.band).to be_a(Band)
    end

    it 'belongs to a gig' do
      google_event = create(:google_calendar_event)
      expect(google_event.gig).to be_present
      expect(google_event.gig).to be_a(Gig)
    end
  end

  describe 'scopes' do
    let(:band) { create(:band) }
    let(:gig) { create(:gig, band: band) }
    let!(:recent_event) { create(:google_calendar_event, band: band, gig: gig, last_synced_at: 30.minutes.ago) }
    let!(:old_event) { create(:google_calendar_event, band: band, gig: gig, last_synced_at: 2.hours.ago) }

    describe '.recently_synced' do
      it 'returns events synced within the last hour' do
        expect(GoogleCalendarEvent.recently_synced).to include(recent_event)
        expect(GoogleCalendarEvent.recently_synced).not_to include(old_event)
      end
    end

    describe '.needs_sync' do
      it 'returns events that need syncing' do
        expect(GoogleCalendarEvent.needs_sync).to include(old_event)
        expect(GoogleCalendarEvent.needs_sync).not_to include(recent_event)
      end
    end

    describe '.for_band' do
      let(:other_band) { create(:band) }
      let(:other_gig) { create(:gig, band: other_band) }
      let!(:other_event) { create(:google_calendar_event, band: other_band, gig: other_gig) }

      it 'returns events for the specified band' do
        expect(GoogleCalendarEvent.for_band(band)).to include(recent_event, old_event)
        expect(GoogleCalendarEvent.for_band(band)).not_to include(other_event)
      end
    end

    describe '.for_gig' do
      let(:other_gig) { create(:gig, band: band) }
      let!(:other_event) { create(:google_calendar_event, band: band, gig: other_gig) }

      it 'returns events for the specified gig' do
        expect(GoogleCalendarEvent.for_gig(gig)).to include(recent_event, old_event)
        expect(GoogleCalendarEvent.for_gig(gig)).not_to include(other_event)
      end
    end
  end

  describe 'destruction' do
    it 'can be destroyed' do
      google_event = create(:google_calendar_event)
      expect { google_event.destroy }.to change(GoogleCalendarEvent, :count).by(-1)
    end

    it 'does not destroy associated band' do
      google_event = create(:google_calendar_event)
      band = google_event.band
      
      google_event.destroy
      expect(Band.find(band.id)).to be_present
    end

    it 'does not destroy associated gig' do
      google_event = create(:google_calendar_event)
      gig = google_event.gig
      
      google_event.destroy
      expect(Gig.find(gig.id)).to be_present
    end
  end

  describe 'factory' do
    it 'creates valid google calendar event' do
      google_event = create(:google_calendar_event)
      expect(google_event).to be_persisted
      expect(google_event.google_event_id).to be_present
      expect(google_event.last_synced_at).to be_present
      expect(google_event.band).to be_present
      expect(google_event.gig).to be_present
    end
  end
end