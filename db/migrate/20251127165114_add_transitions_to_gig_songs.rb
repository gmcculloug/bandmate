class AddTransitionsToGigSongs < ActiveRecord::Migration[8.1]
  def change
    add_column :gig_songs, :has_transition, :boolean, default: false
    add_column :gig_songs, :transition_type, :string
    add_column :gig_songs, :transition_notes, :text
    add_column :gig_songs, :transition_timing, :integer # seconds
  end
end
