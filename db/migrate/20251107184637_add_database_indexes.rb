class AddDatabaseIndexes < ActiveRecord::Migration[8.1]
  def change
    # Performance date queries
    add_index :gigs, :performance_date unless index_exists?(:gigs, :performance_date)

    # Composite indexes for common query patterns
    add_index :gig_songs, [:gig_id, :set_number, :position] unless index_exists?(:gig_songs, [:gig_id, :set_number, :position])
    add_index :gigs, [:band_id, :performance_date] unless index_exists?(:gigs, [:band_id, :performance_date])
    add_index :venues, [:band_id, :name] unless index_exists?(:venues, [:band_id, :name])
    add_index :user_bands, [:user_id, :role] unless index_exists?(:user_bands, [:user_id, :role])
    add_index :user_bands, [:band_id, :role] unless index_exists?(:user_bands, [:band_id, :role])
  end
end
