class AddBandIdToVenues < ActiveRecord::Migration[8.0]
  def change
    add_reference :venues, :band, null: true, foreign_key: true
  end
end
