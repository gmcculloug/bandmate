class AddTimezoneToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :timezone, :string, null: true, default: 'UTC'
    add_index :users, :timezone
  end
end
