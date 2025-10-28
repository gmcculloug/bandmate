class CreatePracticeScheduling < ActiveRecord::Migration[8.0]
  def change
    create_table :practices do |t|
      t.references :band, null: false, foreign_key: true
      t.references :created_by_user, null: false, foreign_key: { to_table: :users }
      t.date :week_start_date, null: false
      t.string :title
      t.text :description
      t.string :status, default: 'active'
      t.timestamps
    end

    create_table :practice_availabilities do |t|
      t.references :practice, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :day_of_week, null: false
      t.string :availability, null: false
      t.text :notes
      t.timestamps
    end

    add_index :practices, [:band_id, :week_start_date]
    add_index :practices, :week_start_date
    add_index :practices, :status

    add_index :practice_availabilities, [:practice_id, :user_id, :day_of_week],
              unique: true, name: 'index_practice_availabilities_unique'
    add_index :practice_availabilities, :availability
  end
end
