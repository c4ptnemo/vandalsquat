class AddDeviceMetadataToTrustedDevices < ActiveRecord::Migration[8.1]
  def change
    add_column :trusted_devices, :user_agent, :string
    add_column :trusted_devices, :ip_address, :string
    add_column :trusted_devices, :last_used_at, :datetime
  end
end
