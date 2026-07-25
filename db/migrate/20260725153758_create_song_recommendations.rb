class CreateSongRecommendations < ActiveRecord::Migration[7.0]
  def change
    create_table :song_recommendations do |t|
      t.references :band, null: false, foreign_key: true
      t.string :title, null: false
      t.string :artist, null: false
      t.text :notes
      t.string :status, null: false, default: 'pending'
      t.string :ip_address, null: false
      t.timestamps
    end
    add_index :song_recommendations, :status
    add_index :song_recommendations, [:band_id, :status]
    add_index :song_recommendations, [:ip_address, :created_at]
  end
end
