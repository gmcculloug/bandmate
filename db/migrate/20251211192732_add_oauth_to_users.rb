class AddOauthToUsers < ActiveRecord::Migration[8.1]
  def change
    # Add OAuth fields to users table
    add_column :users, :oauth_provider, :string
    add_column :users, :oauth_uid, :string
    add_column :users, :oauth_email, :string
    add_column :users, :oauth_username, :string

    # Add unique index on provider + uid combination
    add_index :users, [:oauth_provider, :oauth_uid], unique: true

    # Allow null password_digest for OAuth-only users
    change_column_null :users, :password_digest, true
  end
end
