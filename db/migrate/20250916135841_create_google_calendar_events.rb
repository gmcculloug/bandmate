class CreateGoogleCalendarEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :google_calendar_events do |t|
      t.references :band, null: false, foreign_key: true
      t.references :gig, null: false, foreign_key: true
      t.string :google_event_id, null: false
      t.timestamp :last_synced_at, default: -> { 'CURRENT_TIMESTAMP' }
      t.timestamps
    end

    add_index :google_calendar_events, [:band_id, :google_event_id], unique: true
    add_index :google_calendar_events, :google_event_id
    add_index :google_calendar_events, :last_synced_at
  end
end