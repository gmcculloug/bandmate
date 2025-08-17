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

ActiveRecord::Schema[8.0].define(version: 2025_08_17_225240) do
  create_table "bands", force: :cascade do |t|
    t.string "name", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_bands_on_name", unique: true
  end

  create_table "bands_songs", id: false, force: :cascade do |t|
    t.integer "band_id", null: false
    t.integer "song_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["band_id", "song_id"], name: "index_bands_songs_on_band_id_and_song_id", unique: true
    t.index ["band_id"], name: "index_bands_songs_on_band_id"
    t.index ["song_id"], name: "index_bands_songs_on_song_id"
  end

  create_table "global_songs", force: :cascade do |t|
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
    t.text "lyrics"
    t.index ["artist"], name: "index_global_songs_on_artist"
    t.index ["title", "artist"], name: "index_global_songs_on_title_and_artist"
    t.index ["title"], name: "index_global_songs_on_title"
  end

  create_table "set_list_songs", force: :cascade do |t|
    t.integer "set_list_id", null: false
    t.integer "song_id", null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_set_list_songs_on_position"
    t.index ["set_list_id"], name: "index_set_list_songs_on_set_list_id"
    t.index ["song_id"], name: "index_set_list_songs_on_song_id"
  end

  create_table "set_lists", force: :cascade do |t|
    t.string "name", null: false
    t.text "notes"
    t.integer "band_id", null: false
    t.integer "venue_id"
    t.date "performance_date"
    t.time "start_time"
    t.time "end_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["band_id"], name: "index_set_lists_on_band_id"
    t.index ["name"], name: "index_set_lists_on_name"
    t.index ["venue_id"], name: "index_set_lists_on_venue_id"
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
    t.integer "global_song_id"
    t.text "lyrics"
    t.index ["artist"], name: "index_songs_on_artist"
    t.index ["global_song_id"], name: "index_songs_on_global_song_id"
    t.index ["title"], name: "index_songs_on_title"
  end

  create_table "user_bands", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "band_id", null: false
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
    t.index ["name"], name: "index_venues_on_name"
  end

  add_foreign_key "bands_songs", "bands"
  add_foreign_key "bands_songs", "songs"
  add_foreign_key "set_list_songs", "set_lists"
  add_foreign_key "set_list_songs", "songs"
  add_foreign_key "set_lists", "bands"
  add_foreign_key "set_lists", "venues"
  add_foreign_key "songs", "global_songs"
  add_foreign_key "user_bands", "bands"
  add_foreign_key "user_bands", "users"
  add_foreign_key "users", "bands", column: "last_selected_band_id"
end
