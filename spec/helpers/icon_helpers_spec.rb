require 'spec_helper'
require_relative '../../lib/helpers/icon_helpers'

RSpec.describe IconHelpers do
  let(:test_class) { Class.new { include IconHelpers } }
  let(:helper) { test_class.new }

  describe '#icon' do
    it 'returns the correct SVG for known icons' do
      expect(helper.icon(:home)).to include('<svg')
      expect(helper.icon(:home)).to include('path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"')
    end

    it 'returns empty string for unknown icons' do
      expect(helper.icon(:unknown_icon)).to eq('')
    end

    it 'accepts string keys' do
      expect(helper.icon('gigs')).to include('<svg')
      expect(helper.icon('gigs')).to include('path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"')
    end

    it 'returns correct icons for all defined icon types' do
      expected_icons = [:home, :gigs, :songs, :venues, :calendar, :practices, :bands, :profile, :song_catalog, :add, :edit]

      expected_icons.each do |icon_name|
        result = helper.icon(icon_name)
        expect(result).to include('<svg'), "Expected #{icon_name} to return SVG content"
        expect(result).to include('viewBox="0 0 24 24"'), "Expected #{icon_name} to have correct viewBox"
      end
    end
  end

  describe '#breadcrumb_icon' do
    it 'returns icon content for breadcrumbs' do
      expect(helper.breadcrumb_icon(:gigs)).to include('<svg')
      expect(helper.breadcrumb_icon(:gigs)).to include('margin-right: 6px')
    end

    it 'returns empty string for unknown icons' do
      expect(helper.breadcrumb_icon(:unknown)).to eq('')
    end
  end

  describe 'ICONS constant' do
    it 'contains all expected icon definitions' do
      expect(IconHelpers::ICONS).to be_a(Hash)
      expect(IconHelpers::ICONS).to be_frozen

      # Verify core icons exist
      core_icons = [:home, :gigs, :songs, :venues, :calendar, :practices, :bands, :profile]
      core_icons.each do |icon|
        expect(IconHelpers::ICONS).to have_key(icon), "Expected ICONS to contain #{icon}"
      end
    end

    it 'all icon values are valid SVG strings' do
      IconHelpers::ICONS.each do |name, svg|
        expect(svg).to include('<svg'), "Expected #{name} to contain SVG tag"
        expect(svg).to include('</svg>'), "Expected #{name} to close SVG tag"
        expect(svg).to include('viewBox="0 0 24 24"'), "Expected #{name} to have standard viewBox"
      end
    end
  end
end