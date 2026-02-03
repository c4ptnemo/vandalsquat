class AddAddressToEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :entries, :address, :string
  end
end
