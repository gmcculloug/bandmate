FactoryBot.define do
  factory :user do
    sequence(:username) { |n| "user#{n}" }
    password { "password123" }
    email { Faker::Internet.email }
  end

  factory :user_band do
    association :user
    association :band
  end

  factory :band do
    sequence(:name) { |n| "Band #{n}" }
    notes { Faker::Lorem.paragraph }
    association :owner, factory: :user
  end

  factory :song_catalog do
    sequence(:title) { |n| "Song Catalog #{n}" }
    artist { Faker::Music.band }
    key { ['C', 'G', 'D', 'A', 'E', 'B', 'F#', 'C#', 'F', 'Bb', 'Eb', 'Ab'].sample }
    tempo { rand(60..180) }
    duration { "#{rand(2..5)}:#{rand(10..59)}" }
    genre { ['Rock', 'Pop', 'Jazz', 'Blues', 'Country'].sample }
    notes { Faker::Lorem.paragraph }
  end

  factory :song do
    sequence(:title) { |n| "Song #{n}" }
    artist { Faker::Music.band }
    key { ['C', 'G', 'D', 'A', 'E', 'B', 'F#', 'C#', 'F', 'Bb', 'Eb', 'Ab'].sample }
    tempo { rand(60..180) }
    duration { "#{rand(2..5)}:#{rand(10..59)}" }
    notes { Faker::Lorem.paragraph }
  end

  factory :venue do
    sequence(:name) { |n| "Venue #{n}" }
    location { Faker::Address.full_address }
    contact_name { Faker::Name.name }
    phone_number { Faker::PhoneNumber.phone_number }
    website { Faker::Internet.url }
    
    association :band
  end

  factory :gig do
    sequence(:name) { |n| "Gig #{n}" }
    performance_date { Date.current + rand(1..30).days }
    start_time { "20:00" }
    end_time { "22:00" }
    notes { Faker::Lorem.paragraph }
    
    association :band
    association :venue
  end

  factory :gig_song do
    association :gig
    association :song
    sequence(:position) { |n| n }
  end

  factory :blackout_date do
    association :user
    blackout_date { Date.current + rand(0..30).days }
    reason { ['Vacation', 'Personal', 'Work', nil].sample }
  end

  factory :google_calendar_event do
    sequence(:google_event_id) { |n| "google_event_#{n}" }
    last_synced_at { Time.current }

    association :band
    association :gig
  end

  factory :practice do
    association :band
    association :created_by_user, factory: :user
    week_start_date { Date.current.beginning_of_week(:sunday) }
    title { "Weekly Practice" }
    description { "Let's practice our upcoming setlist" }
    status { "active" }
  end

  factory :practice_availability do
    association :practice
    association :user
    day_of_week { 0 }
    availability { 'available' }
    notes { "Available in the evening" }
  end
end 