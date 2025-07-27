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

ActiveRecord::Schema[8.0].define(version: 2024_12_01_000001) do
  create_table "bands", force: :cascade do |t|
    t.string "name", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "bands_songs", force: :cascade do |t|
    t.integer "band_id", null: false
    t.integer "song_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["band_id"], name: "index_bands_songs_on_band_id"
    t.index ["song_id"], name: "index_bands_songs_on_song_id"
  end

  create_table "set_list_songs", force: :cascade do |t|
    t.integer "set_list_id", null: false
    t.integer "song_id", null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
  end

  create_table "venues", force: :cascade do |t|
    t.string "name", null: false
    t.string "location", null: false
    t.string "contact_name", null: false
    t.string "phone_number", null: false
    t.string "website"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end
end
