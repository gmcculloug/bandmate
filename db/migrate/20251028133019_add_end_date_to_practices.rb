class AddEndDateToPractices < ActiveRecord::Migration[8.0]
  def change
    add_column :practices, :end_date, :date

    # Update existing practices to have end_date = week_start_date + 6 days
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE practices
          SET end_date = week_start_date + INTERVAL '6 days'
          WHERE end_date IS NULL;
        SQL
      end
    end
  end
end
