# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_10_28_133019) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "bands", force: :cascade do |t|
    t.string "name", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "owner_id"
    t.string "google_calendar_id"
    t.boolean "google_calendar_enabled", default: false
    t.string "google_calendar_sync_token"
    t.index ["google_calendar_enabled"], name: "index_bands_on_google_calendar_enabled"
    t.index ["google_calendar_id"], name: "index_bands_on_google_calendar_id"
    t.index ["name"], name: "index_bands_on_name", unique: true
    t.index ["owner_id"], name: "index_bands_on_owner_id"
  end

  create_table "blackout_dates", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.date "blackout_date", null: false
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["blackout_date"], name: "index_blackout_dates_on_blackout_date"
    t.index ["user_id", "blackout_date"], name: "index_blackout_dates_on_user_id_and_blackout_date", unique: true
    t.index ["user_id"], name: "index_blackout_dates_on_user_id"
  end

  create_table "gig_songs", force: :cascade do |t|
    t.integer "gig_id", null: false
    t.integer "song_id", null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "set_number", default: 1, null: false
    t.index ["gig_id"], name: "index_gig_songs_on_gig_id"
    t.index ["position"], name: "index_gig_songs_on_position"
    t.index ["set_number"], name: "index_gig_songs_on_set_number"
    t.index ["song_id"], name: "index_gig_songs_on_song_id"
  end

  create_table "gigs", force: :cascade do |t|
    t.string "name", null: false
    t.text "notes"
    t.integer "band_id", null: false
    t.integer "venue_id"
    t.date "performance_date"
    t.time "start_time"
    t.time "end_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["band_id"], name: "index_gigs_on_band_id"
    t.index ["name"], name: "index_gigs_on_name"
    t.index ["venue_id"], name: "index_gigs_on_venue_id"
  end

  create_table "google_calendar_events", force: :cascade do |t|
    t.bigint "band_id", null: false
    t.bigint "gig_id", null: false
    t.string "google_event_id", null: false
    t.datetime "last_synced_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["band_id", "google_event_id"], name: "index_google_calendar_events_on_band_id_and_google_event_id", unique: true
    t.index ["band_id"], name: "index_google_calendar_events_on_band_id"
    t.index ["gig_id"], name: "index_google_calendar_events_on_gig_id"
    t.index ["google_event_id"], name: "index_google_calendar_events_on_google_event_id"
    t.index ["last_synced_at"], name: "index_google_calendar_events_on_last_synced_at"
  end

  create_table "practice_availabilities", force: :cascade do |t|
    t.bigint "practice_id", null: false
    t.bigint "user_id", null: false
    t.integer "day_of_week", null: false
    t.string "availability", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.time "suggested_start_time"
    t.time "suggested_end_time"
    t.index ["availability"], name: "index_practice_availabilities_on_availability"
    t.index ["practice_id", "user_id", "day_of_week"], name: "index_practice_availabilities_unique", unique: true
    t.index ["practice_id"], name: "index_practice_availabilities_on_practice_id"
    t.index ["user_id"], name: "index_practice_availabilities_on_user_id"
  end

  create_table "practices", force: :cascade do |t|
    t.bigint "band_id", null: false
    t.bigint "created_by_user_id", null: false
    t.date "week_start_date", null: false
    t.string "title"
    t.text "description"
    t.string "status", default: "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "end_date"
    t.index ["band_id", "week_start_date"], name: "index_practices_on_band_id_and_week_start_date"
    t.index ["band_id"], name: "index_practices_on_band_id"
    t.index ["created_by_user_id"], name: "index_practices_on_created_by_user_id"
    t.index ["status"], name: "index_practices_on_status"
    t.index ["week_start_date"], name: "index_practices_on_week_start_date"
  end

  create_table "sessions", force: :cascade do |t|
    t.string "session_id", null: false
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "song_catalogs", force: :cascade do |t|
    t.string "title", null: false
    t.string "artist", null: false
    t.string "key", null: false
    t.string "original_key"
    t.integer "tempo"
    t.string "genre"
    t.string "url"
    t.text "notes"
    t.string "duration"
    t.integer "year"
    t.string "album"
    t.text "lyrics"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "archived", default: false, null: false
    t.datetime "archived_at"
    t.index ["archived"], name: "index_song_catalogs_on_archived"
    t.index ["archived_at"], name: "index_song_catalogs_on_archived_at"
    t.index ["artist"], name: "index_song_catalogs_on_artist"
    t.index ["key"], name: "index_song_catalogs_on_key"
    t.index ["title"], name: "index_song_catalogs_on_title"
  end

  create_table "songs", force: :cascade do |t|
    t.string "title", null: false
    t.string "artist", null: false
    t.string "key", null: false
    t.string "original_key"
    t.integer "tempo"
    t.string "genre"
    t.string "url"
    t.text "notes"
    t.string "duration"
    t.integer "year"
    t.string "album"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "song_catalog_id"
    t.text "lyrics"
    t.boolean "archived", default: false, null: false
    t.datetime "archived_at", precision: nil
    t.index ["archived"], name: "index_songs_on_archived"
    t.index ["archived_at"], name: "index_songs_on_archived_at"
    t.index ["artist"], name: "index_songs_on_artist"
    t.index ["song_catalog_id"], name: "index_songs_on_song_catalog_id"
    t.index ["title"], name: "index_songs_on_title"
  end

  create_table "songs_bands", id: false, force: :cascade do |t|
    t.bigint "song_id", null: false
    t.bigint "band_id", null: false
    t.index ["band_id"], name: "index_songs_bands_on_band_id"
    t.index ["song_id", "band_id"], name: "index_songs_bands_on_song_id_and_band_id", unique: true
    t.index ["song_id"], name: "index_songs_bands_on_song_id"
  end

  create_table "user_bands", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "band_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["band_id"], name: "index_user_bands_on_band_id"
    t.index ["user_id", "band_id"], name: "index_user_bands_on_user_id_and_band_id", unique: true
    t.index ["user_id"], name: "index_user_bands_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "username", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "last_selected_band_id"
    t.string "email"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["last_selected_band_id"], name: "index_users_on_last_selected_band_id"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "venues", force: :cascade do |t|
    t.string "name", null: false
    t.string "location", null: false
    t.string "contact_name", null: false
    t.string "phone_number", null: false
    t.string "website"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "band_id"
    t.text "notes"
    t.boolean "archived", default: false, null: false
    t.datetime "archived_at", precision: nil
    t.index ["archived"], name: "index_venues_on_archived"
    t.index ["archived_at"], name: "index_venues_on_archived_at"
    t.index ["band_id"], name: "index_venues_on_band_id"
    t.index ["name"], name: "index_venues_on_name"
  end

  add_foreign_key "bands", "users", column: "owner_id"
  add_foreign_key "blackout_dates", "users"
  add_foreign_key "gig_songs", "gigs"
  add_foreign_key "gig_songs", "songs"
  add_foreign_key "gigs", "bands"
  add_foreign_key "gigs", "venues"
  add_foreign_key "google_calendar_events", "bands"
  add_foreign_key "google_calendar_events", "gigs"
  add_foreign_key "practice_availabilities", "practices"
  add_foreign_key "practice_availabilities", "users"
  add_foreign_key "practices", "bands"
  add_foreign_key "practices", "users", column: "created_by_user_id"
  add_foreign_key "songs", "song_catalogs"
  add_foreign_key "songs_bands", "bands"
  add_foreign_key "songs_bands", "songs"
  add_foreign_key "user_bands", "bands"
  add_foreign_key "user_bands", "users"
  add_foreign_key "users", "bands", column: "last_selected_band_id"
  add_foreign_key "venues", "bands"
end
