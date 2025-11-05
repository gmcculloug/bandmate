class AddRoleToUserBands < ActiveRecord::Migration[8.0]
  def up
    # Add role column with default 'member'
    add_column :user_bands, :role, :string, default: 'member', null: false
    
    # Add index on role for performance
    add_index :user_bands, :role
    
    # Migrate existing data: set all existing records to 'member'
    execute "UPDATE user_bands SET role = 'member' WHERE role IS NULL"
    
    # For each band with an owner_id, find the corresponding user_band record and set role to 'owner'
    Band.where.not(owner_id: nil).find_each do |band|
      user_band = UserBand.find_by(band_id: band.id, user_id: band.owner_id)
      if user_band
        user_band.update_column(:role, 'owner')
      else
        # Edge case: band has owner_id but no matching user_band - create one
        UserBand.create!(
          band_id: band.id,
          user_id: band.owner_id,
          role: 'owner'
        )
      end
    end
  end
  
  def down
    remove_index :user_bands, :role
    remove_column :user_bands, :role
  end
end

