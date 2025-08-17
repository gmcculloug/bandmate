class CreateUserBands < ActiveRecord::Migration[8.0]
  def change
    create_table :user_bands do |t|
      t.references :user, null: false, foreign_key: true
      t.references :band, null: false, foreign_key: true
      t.timestamps null: false
    end
    
    add_index :user_bands, [:user_id, :band_id], unique: true
  end
end
