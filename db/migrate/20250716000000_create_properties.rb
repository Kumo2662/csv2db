class CreateProperties < ActiveRecord::Migration[7.0]
  def change
    create_table :properties do |t|
      t.string :name, null: false
      t.string :address
      t.string :room_number
      t.integer :rent
      t.float :area
      t.integer :building_type

      t.timestamps
    end
  end
end
