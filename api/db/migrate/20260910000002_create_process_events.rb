class CreateProcessEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :process_events do |t|
      t.string :event_id, null: false
      t.string :process_name, null: false
      t.bigint :pid, null: false
      t.datetime :occurred_at, null: false, precision: 6
      t.timestamps
    end
    add_index :process_events, :event_id, unique: true
    add_index :process_events, [ :occurred_at, :id ]
    add_check_constraint :process_events, "pid > 0", name: "process_event_positive_pid"
  end
end
