require_relative '../spec_helper'
require 'ostruct'

# Helper class to test ApplicationHelpers module
class TestApp
  include ApplicationHelpers
  
  attr_accessor :session, :settings
  
  def initialize
    @session = {}
    @settings = OpenStruct.new(test: false)
    def @settings.test?
      test
    end
  end
  
  def redirect(path)
    # Mock redirect for testing
    @redirect_path = path
  end
  
  def redirected_to
    @redirect_path
  end
end

RSpec.describe ApplicationHelpers, type: :helper do
  let(:helper) { TestApp.new }
  let(:user) { create(:user) }
  let(:band) { create(:band) }

  describe '#current_user' do
    context 'in non-test mode' do
      it 'returns nil when no user is logged in' do
        expect(helper.current_user).to be_nil
      end

      it 'returns the user when session has user_id' do
        helper.session[:user_id] = user.id
        expect(helper.current_user).to eq(user)
      end

      it 'memoizes the current user' do
        helper.session[:user_id] = user.id
        first_call = helper.current_user
        second_call = helper.current_user
        expect(first_call).to eq(second_call)
        expect(first_call.object_id).to eq(second_call.object_id)
      end
    end

    context 'in test mode' do
      before { helper.settings.test = true }

      it 'uses test session when available' do
        helper.instance_variable_set(:@test_session, { user_id: user.id })
        expect(helper.current_user).to eq(user)
      end

      it 'falls back to regular session when test session is not available' do
        helper.session[:user_id] = user.id
        expect(helper.current_user).to eq(user)
      end
    end
  end

  describe '#logged_in?' do
    it 'returns true when user is logged in' do
      helper.session[:user_id] = user.id
      expect(helper.logged_in?).to be true
    end

    it 'returns false when no user is logged in' do
      expect(helper.logged_in?).to be false
    end
  end

  describe '#require_login' do
    it 'redirects to login when not logged in' do
      helper.require_login
      expect(helper.redirected_to).to eq('/login')
    end

    it 'does not redirect when logged in' do
      helper.session[:user_id] = user.id
      helper.require_login
      expect(helper.redirected_to).to be_nil
    end
  end

  describe '#current_band' do
    let!(:user_band) { create(:user_band, user: user, band: band) }

    context 'when user is logged in' do
      before { helper.session[:user_id] = user.id }

      it 'returns the band when session has band_id and user has access' do
        helper.session[:band_id] = band.id
        expect(helper.current_band).to eq(band)
      end

      it 'returns nil when user does not have access to the band' do
        other_band = create(:band)
        helper.session[:band_id] = other_band.id
        expect(helper.current_band).to be_nil
      end

      it 'returns nil when no band_id in session' do
        expect(helper.current_band).to be_nil
      end
    end

    context 'when user is not logged in' do
      it 'returns nil even with band_id in session' do
        helper.session[:band_id] = band.id
        expect(helper.current_band).to be_nil
      end
    end

    context 'in test mode' do
      before do
        helper.settings.test = true
        helper.session[:user_id] = user.id
      end

      it 'uses test session when available' do
        helper.instance_variable_set(:@test_session, { band_id: band.id })
        expect(helper.current_band).to eq(band)
      end
    end
  end

  describe '#user_bands' do
    let!(:user_band1) { create(:user_band, user: user, band: band) }
    let!(:user_band2) { create(:user_band, user: user, band: create(:band, name: 'Another Band')) }

    it 'returns user bands ordered by name when logged in' do
      helper.session[:user_id] = user.id
      bands = helper.user_bands
      expect(bands).to include(band)
      expect(bands.count).to eq(2)
    end

    it 'returns empty relation when not logged in' do
      bands = helper.user_bands
      expect(bands).to be_empty
      expect(bands).to be_a(ActiveRecord::Relation)
    end
  end

  describe '#filter_by_current_band' do
    let!(:user_band) { create(:user_band, user: user, band: band) }
    let!(:song) { create(:song) }
    let!(:gig) { create(:gig, band: band) }
    let!(:venue) { create(:venue, band: band) }

    before do
      helper.session[:user_id] = user.id
      helper.session[:band_id] = band.id
      band.songs << song
    end

    it 'filters songs by current band' do
      filtered = helper.filter_by_current_band(Song.all)
      expect(filtered).to include(song)
    end

    it 'filters gigs by current band' do
      filtered = helper.filter_by_current_band(Gig.all)
      expect(filtered).to include(gig)
    end

    it 'filters venues by current band' do
      filtered = helper.filter_by_current_band(Venue.all)
      expect(filtered).to include(venue)
    end

    it 'returns empty when no current band' do
      helper.session[:band_id] = nil
      filtered = helper.filter_by_current_band(Song.all)
      expect(filtered).to be_empty
    end

    it 'returns original collection for unsupported types' do
      filtered = helper.filter_by_current_band(User.all)
      expect(filtered).to eq(User.all)
    end
  end

  describe 'calendar helpers' do
    describe '#calendar_days_for_month' do
      it 'returns all days for a calendar month view' do
        # Test January 2024 (starts on Monday)
        days = helper.calendar_days_for_month(2024, 1)
        
        # Should include days from previous month to fill the week
        expect(days.first).to eq(Date.new(2023, 12, 31)) # Sunday before Jan 1
        expect(days.last).to eq(Date.new(2024, 2, 3))    # Saturday after Jan 31
        expect(days.count).to eq(35) # 5 weeks
      end

      it 'handles December correctly' do
        days = helper.calendar_days_for_month(2024, 12)
        expect(days).to include(Date.new(2024, 12, 1))
        expect(days).to include(Date.new(2024, 12, 31))
      end
    end

    describe '#month_name' do
      it 'returns correct month names' do
        expect(helper.month_name(1)).to eq('January')
        expect(helper.month_name(6)).to eq('June')
        expect(helper.month_name(12)).to eq('December')
      end
    end

    describe '#prev_month_link' do
      it 'handles regular months' do
        link = helper.prev_month_link(2024, 6)
        expect(link).to eq('/calendar?year=2024&month=5')
      end

      it 'handles January (goes to previous year)' do
        link = helper.prev_month_link(2024, 1)
        expect(link).to eq('/calendar?year=2023&month=12')
      end
    end

    describe '#next_month_link' do
      it 'handles regular months' do
        link = helper.next_month_link(2024, 6)
        expect(link).to eq('/calendar?year=2024&month=7')
      end

      it 'handles December (goes to next year)' do
        link = helper.next_month_link(2024, 12)
        expect(link).to eq('/calendar?year=2025&month=1')
      end
    end

    describe '#gigs_for_date' do
      let(:date) { Date.current }
      let(:gig1) { create(:gig, performance_date: date, band: band) }
      let(:gig2) { create(:gig, performance_date: date) }
      let(:blackout) { create(:blackout_date, blackout_date: date, user: user) }

      before do
        # Mock instance variables that would be set by calendar route
        helper.instance_variable_set(:@current_band_gigs, [gig1])
        helper.instance_variable_set(:@other_band_gigs, [])
        helper.instance_variable_set(:@bandmate_conflicts, [gig2])
        helper.instance_variable_set(:@blackout_dates, [blackout])
      end

      it 'organizes gigs by type for a given date' do
        result = helper.gigs_for_date(date)
        
        expect(result[:current]).to include(gig1)
        expect(result[:conflicts]).to include(gig2)
        expect(result[:blackouts]).to include(blackout)
      end

      it 'returns empty hash for date with no events' do
        future_date = Date.current + 100.days
        result = helper.gigs_for_date(future_date)
        expect(result).to be_empty
      end
    end
  end
end