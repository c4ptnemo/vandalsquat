class CreateTrustedDevices < ActiveRecord::Migration[8.1]
  def change
    create_table :trusted_devices do |t|
      t.timestamps
    end
  end
end
