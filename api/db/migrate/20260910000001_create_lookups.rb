class CreateLookups < ActiveRecord::Migration[8.1]
  def change
    create_table :lookups do |t|
      t.string :ip
      t.string :mac, null: false
      t.string :vendor
      t.string :status, null: false, default: "unknown"
      t.timestamps
    end
    add_index :lookups, [ :created_at, :id ]
    add_check_constraint :lookups, "status IN ('resolved', 'unknown', 'failed')", name: "lookup_status"
  end
end
