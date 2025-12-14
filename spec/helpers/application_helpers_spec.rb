require 'spec_helper'

RSpec.describe ApplicationHelpers, type: :helper do
  # Mock the Sinatra app context
  let(:app) { Sinatra::Application }
  
  before do
    # Include the helper module in the test context
    self.extend(ApplicationHelpers)
  end

  describe '#gigs_for_date' do
    let(:date) { Date.current + 1.day }
    let(:current_band_gigs) { [] }
    let(:other_band_gigs) { [] }
    let(:band_huddle_conflicts) { [] }
    let(:blackout_dates) { [] }

    it 'returns empty hash when no gigs or blackouts' do
      result = gigs_for_date(date, 
        current_band_gigs: current_band_gigs,
        other_band_gigs: other_band_gigs,
        band_huddle_conflicts: band_huddle_conflicts,
        blackout_dates: blackout_dates
      )
      
      expect(result).to eq({})
    end

    it 'includes current band gigs for the date' do
      gig1 = double('gig', performance_date: date, name: 'Gig 1')
      gig2 = double('gig', performance_date: date + 1.day, name: 'Gig 2')
      
      result = gigs_for_date(date, 
        current_band_gigs: [gig1, gig2],
        other_band_gigs: other_band_gigs,
        band_huddle_conflicts: band_huddle_conflicts,
        blackout_dates: blackout_dates
      )
      
      expect(result[:current]).to include(gig1)
      expect(result[:current]).not_to include(gig2)
    end

    it 'includes other band gigs for the date' do
      gig1 = double('gig', performance_date: date, name: 'Other Gig 1')
      gig2 = double('gig', performance_date: date + 1.day, name: 'Other Gig 2')
      
      result = gigs_for_date(date, 
        current_band_gigs: current_band_gigs,
        other_band_gigs: [gig1, gig2],
        band_huddle_conflicts: band_huddle_conflicts,
        blackout_dates: blackout_dates
      )
      
      expect(result[:other]).to include(gig1)
      expect(result[:other]).not_to include(gig2)
    end

    it 'includes band huddle conflicts for the date' do
      conflict1 = double('gig', performance_date: date, name: 'Conflict 1')
      conflict2 = double('gig', performance_date: date + 1.day, name: 'Conflict 2')
      
      result = gigs_for_date(date, 
        current_band_gigs: current_band_gigs,
        other_band_gigs: other_band_gigs,
        band_huddle_conflicts: [conflict1, conflict2],
        blackout_dates: blackout_dates
      )
      
      expect(result[:conflicts]).to include(conflict1)
      expect(result[:conflicts]).not_to include(conflict2)
    end

    it 'includes blackout dates for the date' do
      blackout1 = double('blackout', blackout_date: date, reason: 'Holiday')
      blackout2 = double('blackout', blackout_date: date + 1.day, reason: 'Work')
      
      result = gigs_for_date(date, 
        current_band_gigs: current_band_gigs,
        other_band_gigs: other_band_gigs,
        band_huddle_conflicts: band_huddle_conflicts,
        blackout_dates: [blackout1, blackout2]
      )
      
      expect(result[:blackouts]).to include(blackout1)
      expect(result[:blackouts]).not_to include(blackout2)
    end

    it 'handles multiple types of events for the same date' do
      current_gig = double('gig', performance_date: date, name: 'Current Gig')
      other_gig = double('gig', performance_date: date, name: 'Other Gig')
      conflict = double('gig', performance_date: date, name: 'Conflict')
      blackout = double('blackout', blackout_date: date, reason: 'Holiday')
      
      result = gigs_for_date(date, 
        current_band_gigs: [current_gig],
        other_band_gigs: [other_gig],
        band_huddle_conflicts: [conflict],
        blackout_dates: [blackout]
      )
      
      expect(result[:current]).to include(current_gig)
      expect(result[:other]).to include(other_gig)
      expect(result[:conflicts]).to include(conflict)
      expect(result[:blackouts]).to include(blackout)
    end
  end

  describe '#gigs_for_date_legacy' do
    let(:date) { Date.current + 1.day }
    
    before do
      @current_band_gigs = []
      @other_band_gigs = []
      @band_huddle_conflicts = []
      @blackout_dates = []
    end

    it 'uses instance variables when available' do
      gig = double('gig', performance_date: date, name: 'Legacy Gig')
      @current_band_gigs = [gig]
      
      result = gigs_for_date_legacy(date)
      
      expect(result[:current]).to include(gig)
    end

    it 'handles nil instance variables' do
      @current_band_gigs = nil
      @other_band_gigs = nil
      @band_huddle_conflicts = nil
      @blackout_dates = nil
      
      result = gigs_for_date_legacy(date)
      
      expect(result).to eq({})
    end
  end

  describe '#calendar_days_for_month' do
    it 'returns all days for a month including padding days' do
      days = calendar_days_for_month(2024, 1) # January 2024
      
      # January 2024 starts on Monday (1), so we need Sunday (0) from previous month
      expect(days.first).to eq(Date.new(2023, 12, 31)) # Sunday
      expect(days.last).to eq(Date.new(2024, 2, 3)) # Saturday
      expect(days.length).to eq(35) # 5 weeks
    end

    it 'handles February in a leap year' do
      days = calendar_days_for_month(2024, 2) # February 2024 (leap year)
      
      # February 2024 starts on Thursday (4)
      expect(days.first).to eq(Date.new(2024, 1, 28)) # Sunday
      expect(days.last).to eq(Date.new(2024, 3, 2)) # Saturday
    end

    it 'handles December correctly' do
      days = calendar_days_for_month(2024, 12) # December 2024
      
      # December 2024 starts on Sunday (0)
      expect(days.first).to eq(Date.new(2024, 12, 1)) # Sunday
      expect(days.last).to eq(Date.new(2025, 1, 4)) # Saturday
    end
  end

  describe '#month_name' do
    it 'returns the correct month name' do
      expect(month_name(1)).to eq('January')
      expect(month_name(6)).to eq('June')
      expect(month_name(12)).to eq('December')
    end
  end

  describe '#prev_month_link' do
    it 'returns correct link for non-January months' do
      expect(prev_month_link(2024, 6)).to eq('/calendar?year=2024&month=5')
    end

    it 'returns correct link for January' do
      expect(prev_month_link(2024, 1)).to eq('/calendar?year=2023&month=12')
    end
  end

  describe '#next_month_link' do
    it 'returns correct link for non-December months' do
      expect(next_month_link(2024, 6)).to eq('/calendar?year=2024&month=7')
    end

    it 'returns correct link for December' do
      expect(next_month_link(2024, 12)).to eq('/calendar?year=2025&month=1')
    end
  end
end