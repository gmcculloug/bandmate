class CreateBlackoutDates < ActiveRecord::Migration[8.0]
  def change
    create_table :blackout_dates do |t|
      t.references :user, null: false, foreign_key: true
      t.date :blackout_date, null: false
      t.string :reason
      t.timestamps
    end
    
    add_index :blackout_dates, [:user_id, :blackout_date], unique: true
    add_index :blackout_dates, :blackout_date
  end
end
