class AddSetNumberToGigSongs < ActiveRecord::Migration[8.0]
  def change
    add_column :gig_songs, :set_number, :integer, null: false, default: 1
    add_index :gig_songs, :set_number
  end
end
