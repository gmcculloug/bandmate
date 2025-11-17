class ModifyPracticeDatesForFlexibility < ActiveRecord::Migration[8.1]
  def change
    # Rename week_start_date to start_date in practices table
    rename_column :practices, :week_start_date, :start_date

    # Add a specific_date column to practice_availabilities to replace day_of_week
    add_column :practice_availabilities, :specific_date, :date

    # Remove the old day_of_week index if it exists
    remove_index :practice_availabilities, [:practice_id, :user_id, :day_of_week] if index_exists?(:practice_availabilities, [:practice_id, :user_id, :day_of_week])

    # Add new unique index for specific_date
    add_index :practice_availabilities, [:practice_id, :user_id, :specific_date], unique: true, name: 'index_practice_availabilities_on_practice_user_date'
  end

  def down
    # Reverse the changes
    remove_index :practice_availabilities, name: 'index_practice_availabilities_on_practice_user_date' if index_exists?(:practice_availabilities, name: 'index_practice_availabilities_on_practice_user_date')
    remove_column :practice_availabilities, :specific_date
    add_index :practice_availabilities, [:practice_id, :user_id, :day_of_week], unique: true if !index_exists?(:practice_availabilities, [:practice_id, :user_id, :day_of_week])
    rename_column :practices, :start_date, :week_start_date
  end
end
