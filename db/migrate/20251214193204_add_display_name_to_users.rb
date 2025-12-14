class AddDisplayNameToUsers < ActiveRecord::Migration[8.1]
  def change
    # Add display_name column to users table
    add_column :users, :display_name, :string

    # Populate existing users with default display_name values
    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE users SET display_name = CASE
            WHEN oauth_username IS NOT NULL AND oauth_username != '' THEN oauth_username
            WHEN oauth_email IS NOT NULL AND oauth_email != '' THEN
              SPLIT_PART(oauth_email, '@', 1)
            WHEN email IS NOT NULL AND email != '' THEN
              SPLIT_PART(email, '@', 1)
            ELSE username
          END
          WHERE display_name IS NULL;
        SQL
      end
    end
  end
end
