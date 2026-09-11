class CreateVendors < ActiveRecord::Migration[8.1]
  def change
    create_table :vendors do |t|
      t.string :oui, null: false
      t.string :name, null: false
      t.string :source, null: false, default: "user"
      t.timestamps
    end
    add_index :vendors, :oui, unique: true
    add_check_constraint :vendors, "source IN ('seed', 'user')", name: "vendor_source"
  end
end
