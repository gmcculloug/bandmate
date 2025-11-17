class RemoveDayOfWeekFromPracticeAvailabilities < ActiveRecord::Migration[8.1]
  def change
    # Remove the obsolete day_of_week column since we now use specific_date
    remove_column :practice_availabilities, :day_of_week, :integer
  end
end
