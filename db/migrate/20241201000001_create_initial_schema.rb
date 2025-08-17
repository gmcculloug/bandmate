class CreateInitialSchema < ActiveRecord::Migration[8.0]
  def change
    create_table :bands do |t|
      t.string :name, null: false
      t.text :notes
      t.timestamps
    end

    create_table :songs do |t|
      t.string :title, null: false
      t.string :artist, null: false
      t.string :key, null: false
      t.string :original_key
      t.integer :tempo
      t.string :genre
      t.string :url
      t.text :notes
      t.string :duration
      t.integer :year
      t.string :album
      t.timestamps
    end

    create_table :bands_songs, id: false do |t|
      t.references :band, null: false, foreign_key: true
      t.references :song, null: false, foreign_key: true
      t.timestamps
    end

    create_table :venues do |t|
      t.string :name, null: false
      t.string :location, null: false
      t.string :contact_name, null: false
      t.string :phone_number, null: false
      t.string :website
      t.timestamps
    end

    create_table :set_lists do |t|
      t.string :name, null: false
      t.text :notes
      t.references :band, null: false, foreign_key: true
      t.references :venue, foreign_key: true
      t.date :performance_date
      t.time :start_time
      t.time :end_time
      t.timestamps
    end

    create_table :set_list_songs do |t|
      t.references :set_list, null: false, foreign_key: true
      t.references :song, null: false, foreign_key: true
      t.integer :position, null: false
      t.timestamps
    end

    # Add indexes for better performance
    add_index :bands, :name, unique: true
    add_index :songs, :title
    add_index :songs, :artist
    add_index :venues, :name
    add_index :set_lists, :name
    add_index :set_list_songs, :position
    add_index :bands_songs, [:band_id, :song_id], unique: true
  end
end 