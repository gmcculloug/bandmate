require 'spec_helper'

RSpec.describe GoogleCalendarService do
  let(:band) { create(:band, google_calendar_enabled: true, google_calendar_id: 'test_calendar_id') }
  let(:venue) { create(:venue, band: band) }
  let(:gig) { create(:gig, band: band, venue: venue, name: 'Test Gig', performance_date: Date.current + 1.day, start_time: '20:00', end_time: '22:00') }
  let(:service) { described_class.new(band) }
  let(:mock_calendar_service) { instance_double(Google::Apis::CalendarV3::CalendarService) }

  before do
    allow(Google::Apis::CalendarV3::CalendarService).to receive(:new).and_return(mock_calendar_service)
    allow(mock_calendar_service).to receive(:authorization=)

    # Mock the Google Auth credentials creation to avoid requiring real credentials
    mock_credentials = double('credentials')
    allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds).and_return(mock_credentials)
  end

  describe '#initialize' do
    it 'sets up the service with the band and Google Calendar service' do
      expect(service.instance_variable_get(:@band)).to eq(band)
      expect(service.instance_variable_get(:@service)).to eq(mock_calendar_service)
    end
  end

  describe '#sync_gig_to_calendar' do
    context 'when Google Calendar is not enabled' do
      let(:band) { create(:band, google_calendar_enabled: false) }

      it 'returns false' do
        expect(service.sync_gig_to_calendar(gig)).to be false
      end
    end

    context 'when calendar ID is not present' do
      let(:band) { create(:band, google_calendar_enabled: true, google_calendar_id: 'test_id') }

      before do
        band.update_column(:google_calendar_id, nil)  # Bypass validation
      end

      it 'returns false' do
        expect(service.sync_gig_to_calendar(gig)).to be false
      end
    end

    context 'when Google Calendar is properly configured' do
      context 'when gig does not exist in Google Calendar' do
        before do
          allow(service).to receive(:find_existing_event).with(gig).and_return(nil)
        end

        it 'creates a new event' do
          mock_event = double('event', id: 'new_event_id')
          expect(service).to receive(:create_event).with(gig).and_return(mock_event)
          expect(service.sync_gig_to_calendar(gig)).to be true
        end
      end

      context 'when gig already exists in Google Calendar' do
        let(:existing_event) { double('event', id: 'existing_event_id') }

        before do
          allow(service).to receive(:find_existing_event).with(gig).and_return(existing_event)
        end

        it 'updates the existing event' do
          expect(service).to receive(:update_event).with(gig, existing_event.id)
          expect(service.sync_gig_to_calendar(gig)).to be true
        end
      end

      context 'when an error occurs' do
        before do
          allow(service).to receive(:find_existing_event).and_raise(StandardError.new('API Error'))
        end

        it 'returns false' do
          expect(service.sync_gig_to_calendar(gig)).to be false
        end
      end
    end
  end

  describe '#remove_gig_from_calendar' do
    context 'when Google Calendar is not enabled' do
      let(:band) { create(:band, google_calendar_enabled: false) }

      it 'returns false' do
        expect(service.remove_gig_from_calendar(gig)).to be false
      end
    end

    context 'when gig exists in Google Calendar' do
      let(:existing_event) { double('event', id: 'existing_event_id') }

      before do
        allow(service).to receive(:find_existing_event).with(gig).and_return(existing_event)
        create(:google_calendar_event, band: band, gig: gig, google_event_id: 'existing_event_id')
      end

      it 'deletes the event from Google Calendar and removes tracking record' do
        expect(mock_calendar_service).to receive(:delete_event).with(band.google_calendar_id, existing_event.id)

        result = nil
        expect { result = service.remove_gig_from_calendar(gig) }.to change { GoogleCalendarEvent.count }.by(-1)
        expect(result).to be true
      end
    end

    context 'when gig does not exist in Google Calendar' do
      before do
        allow(service).to receive(:find_existing_event).with(gig).and_return(nil)
      end

      it 'returns true without making API calls' do
        expect(mock_calendar_service).not_to receive(:delete_event)
        expect(service.remove_gig_from_calendar(gig)).to be true
      end
    end

    context 'when an error occurs' do
      before do
        allow(service).to receive(:find_existing_event).and_raise(StandardError.new('API Error'))
      end

      it 'returns false' do
        expect(service.remove_gig_from_calendar(gig)).to be false
      end
    end
  end

  describe '#sync_all_gigs' do
    context 'when Google Calendar is not enabled' do
      let(:band) { create(:band, google_calendar_enabled: false) }

      it 'returns error result' do
        result = service.sync_all_gigs
        expect(result[:success]).to be false
        expect(result[:synced_count]).to eq(0)
        expect(result[:total_count]).to eq(0)
        expect(result[:errors]).to include('Google Calendar not enabled')
      end
    end

    context 'when Google Calendar is enabled' do
      let!(:gig1) { create(:gig, band: band) }
      let!(:gig2) { create(:gig, band: band) }

      before do
        allow(service).to receive(:sync_gig_to_calendar).and_return(true)
      end

      it 'syncs all gigs and returns success result' do
        expect(service).to receive(:sync_gig_to_calendar).with(gig1).and_return(true)
        expect(service).to receive(:sync_gig_to_calendar).with(gig2).and_return(true)

        result = service.sync_all_gigs
        expect(result[:success]).to be true
        expect(result[:synced_count]).to eq(2)
        expect(result[:total_count]).to eq(2)
        expect(result[:errors]).to be_empty
      end

      it 'handles partial failures' do
        expect(service).to receive(:sync_gig_to_calendar).with(gig1).and_return(true)
        expect(service).to receive(:sync_gig_to_calendar).with(gig2).and_return(false)

        result = service.sync_all_gigs
        expect(result[:success]).to be false
        expect(result[:synced_count]).to eq(1)
        expect(result[:total_count]).to eq(2)
        expect(result[:errors]).to include("Failed to sync gig: #{gig2.name}")
      end
    end
  end

  describe '#test_connection' do
    context 'when Google Calendar is not enabled' do
      let(:band) { create(:band, google_calendar_enabled: false) }

      it 'returns error result' do
        result = service.test_connection
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Google Calendar not enabled')
      end
    end

    context 'when calendar ID is not provided' do
      let(:band) { create(:band, google_calendar_enabled: true, google_calendar_id: 'test_id') }

      before do
        band.update_column(:google_calendar_id, nil)  # Bypass validation
      end

      it 'returns error result' do
        result = service.test_connection
        expect(result[:success]).to be false
        expect(result[:error]).to eq('No calendar ID provided')
      end
    end

    context 'when connection is successful' do
      let(:mock_calendar) { double('calendar', summary: 'Test Calendar') }

      before do
        allow(mock_calendar_service).to receive(:get_calendar).with(band.google_calendar_id).and_return(mock_calendar)
      end

      it 'returns success result with calendar name' do
        result = service.test_connection
        expect(result[:success]).to be true
        expect(result[:calendar_name]).to eq('Test Calendar')
      end
    end

    context 'when connection fails' do
      before do
        allow(mock_calendar_service).to receive(:get_calendar).and_raise(StandardError.new('API Error'))
      end

      it 'returns error result' do
        result = service.test_connection
        expect(result[:success]).to be false
        expect(result[:error]).to eq('API Error')
      end
    end
  end

  describe 'private methods' do
    describe '#find_existing_event' do
      context 'when Google Calendar event exists in database' do
        let!(:google_event) { create(:google_calendar_event, band: band, gig: gig, google_event_id: 'test_event_id') }
        let(:mock_event) { double('event') }

        before do
          allow(mock_calendar_service).to receive(:get_event).with(band.google_calendar_id, 'test_event_id').and_return(mock_event)
        end

        it 'returns the Google Calendar event' do
          result = service.send(:find_existing_event, gig)
          expect(result).to eq(mock_event)
        end
      end

      context 'when Google Calendar event exists in database but not in Google Calendar' do
        let!(:google_event) { create(:google_calendar_event, band: band, gig: gig, google_event_id: 'test_event_id') }

        before do
          allow(mock_calendar_service).to receive(:get_event).and_raise(StandardError)
        end

        it 'destroys the database record and returns nil' do
          expect { service.send(:find_existing_event, gig) }.to change { GoogleCalendarEvent.count }.by(-1)
          result = service.send(:find_existing_event, gig)
          expect(result).to be_nil
        end
      end

      context 'when no Google Calendar event exists' do
        it 'returns nil' do
          result = service.send(:find_existing_event, gig)
          expect(result).to be_nil
        end
      end
    end

    describe '#build_event_from_gig' do
      it 'builds a Google Calendar event from gig data' do
        event = service.send(:build_event_from_gig, gig)

        expect(event).to be_a(Google::Apis::CalendarV3::Event)
        expect(event.summary).to eq("#{gig.name} - #{band.name}")
        expect(event.location).to eq("#{venue.name}, #{venue.location}")
        expect(event.start.date).to eq(gig.performance_date.to_s)
        expect(event.end.date).to eq((gig.performance_date + 1.day).to_s)
      end

      it 'includes notes in description when present' do
        gig.update!(notes: 'Special notes for this gig')
        event = service.send(:build_event_from_gig, gig)

        expect(event.description).to include('Special notes for this gig')
      end
    end

    describe '#build_datetime' do
      it 'combines date and time correctly' do
        date = Date.current
        time = '20:00'
        result = service.send(:build_datetime, date, time)

        expect(result).to be_a(Time)
        expect(result.hour).to eq(20)
        expect(result.min).to eq(0)
        expect(result.to_date).to eq(date)
      end

      it 'handles nil time gracefully' do
        date = Date.current
        result = service.send(:build_datetime, date, nil)

        expect(result).to be_a(Time)
        expect(result.to_date).to eq(date)
      end

      it 'handles invalid time gracefully' do
        date = Date.current
        result = service.send(:build_datetime, date, 'invalid_time')

        expect(result).to be_a(Time)
        expect(result.to_date).to eq(date)
      end
    end
  end
end