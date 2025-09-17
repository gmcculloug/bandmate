class AddGoogleCalendarToBands < ActiveRecord::Migration[8.0]
  def change
    add_column :bands, :google_calendar_id, :string
    add_column :bands, :google_calendar_enabled, :boolean, default: false
    add_column :bands, :google_calendar_sync_token, :string
    
    add_index :bands, :google_calendar_id
    add_index :bands, :google_calendar_enabled
  end
end