class AddTimeFieldsToPracticeAvailabilities < ActiveRecord::Migration[8.0]
  def change
    add_column :practice_availabilities, :suggested_start_time, :time
    add_column :practice_availabilities, :suggested_end_time, :time
  end
end
