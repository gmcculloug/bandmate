FactoryBot.define do
  factory :band do
    sequence(:name) { |n| "Band #{n}" }
    notes { Faker::Lorem.paragraph }
  end

  factory :song do
    sequence(:title) { |n| "Song #{n}" }
    artist { Faker::Music.band }
    key { ['C', 'G', 'D', 'A', 'E', 'B', 'F#', 'C#', 'F', 'Bb', 'Eb', 'Ab'].sample }
    tempo { rand(60..180) }
    notes { Faker::Lorem.paragraph }
    
    after(:build) do |song|
      # Create a band if none exists, or associate with existing band
      band = Band.first || create(:band)
      song.bands << band
    end
  end

  factory :venue do
    sequence(:name) { |n| "Venue #{n}" }
    location { Faker::Address.full_address }
    contact_name { Faker::Name.name }
    phone_number { Faker::PhoneNumber.phone_number }
    website { Faker::Internet.url }
  end

  factory :set_list do
    sequence(:name) { |n| "Set List #{n}" }
    performance_date { Date.current + rand(1..30).days }
    start_time { "20:00" }
    end_time { "22:00" }
    notes { Faker::Lorem.paragraph }
    
    association :band
    association :venue
  end

  factory :set_list_song do
    association :set_list
    association :song
    sequence(:position) { |n| n }
  end
end 