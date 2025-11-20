class AddStartTimeAndDurationToPractices < ActiveRecord::Migration[8.1]
  def change
    add_column :practices, :start_time, :time, null: true
    add_column :practices, :duration, :integer, null: true, comment: "Duration in minutes"
  end
end
