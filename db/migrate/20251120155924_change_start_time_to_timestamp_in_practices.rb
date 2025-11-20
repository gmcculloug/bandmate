class ChangeStartTimeToTimestampInPractices < ActiveRecord::Migration[8.1]
  def up
    # Add a new temporary timestamp column
    add_column :practices, :start_time_temp, :timestamp, null: true

    # Copy time values to new column as today + time (for existing data)
    execute <<-SQL
      UPDATE practices
      SET start_time_temp = (CURRENT_DATE + start_time)::timestamp
      WHERE start_time IS NOT NULL;
    SQL

    # Drop the old column
    remove_column :practices, :start_time

    # Rename the new column
    rename_column :practices, :start_time_temp, :start_time
  end

  def down
    # Add temporary time column
    add_column :practices, :start_time_temp, :time, null: true

    # Extract time from timestamp
    execute <<-SQL
      UPDATE practices
      SET start_time_temp = start_time::time
      WHERE start_time IS NOT NULL;
    SQL

    # Drop timestamp column and rename time column
    remove_column :practices, :start_time
    rename_column :practices, :start_time_temp, :start_time
  end
end
