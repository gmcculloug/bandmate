class AddOwnerToBands < ActiveRecord::Migration[7.0]
  def change
    add_reference :bands, :owner, null: true, foreign_key: { to_table: :users }
  end
end
