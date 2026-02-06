class AddUserToTrustedDevices < ActiveRecord::Migration[8.1]
  def change
    add_reference :trusted_devices, :user, null: false, foreign_key: true
  end
end
