class AddPracticeStateToSongsBands < ActiveRecord::Migration[8.1]
  def change
    add_column :songs_bands, :practice_state, :boolean, default: false, null: false
    add_column :songs_bands, :practice_state_updated_at, :timestamp, null: true

    add_index :songs_bands, :practice_state
    add_index :songs_bands, [:band_id, :practice_state]
  end
end