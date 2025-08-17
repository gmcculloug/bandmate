class AddLastSelectedBandIdToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :last_selected_band_id, :integer
    add_index :users, :last_selected_band_id
    add_foreign_key :users, :bands, column: :last_selected_band_id
  end
end
