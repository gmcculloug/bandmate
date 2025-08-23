class AddNotesToVenues < ActiveRecord::Migration[7.0]
  def change
    add_column :venues, :notes, :text
  end
end
