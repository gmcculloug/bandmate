class RenameSetListsToGigs < ActiveRecord::Migration[8.0]
  def change
    rename_table :set_lists, :gigs
    rename_table :set_list_songs, :gig_songs
    
    rename_column :gig_songs, :set_list_id, :gig_id
  end
end
