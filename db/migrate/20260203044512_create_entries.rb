class CreateEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :entries do |t|
      t.references :user, null: false, foreign_key: true
      t.string :writer_name
      t.text :notes
      t.date :found_on
      t.float :latitude
      t.float :longitude

      t.timestamps
    end
  end
end
