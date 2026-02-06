class AddUsernameAndTwoFactorToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :username, :string
    add_index :users, :username, unique: true
    
    change_column_null :users, :email, true
    
    add_column :users, :otp_secret, :string
    add_column :users, :otp_enabled, :boolean, default: false, null: false
    add_column :users, :otp_backup_codes, :text
  end
end