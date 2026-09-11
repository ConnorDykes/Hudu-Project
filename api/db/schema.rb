# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_11_000003) do
  create_table "lookups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip"
    t.string "mac", null: false
    t.string "status", default: "unknown", null: false
    t.datetime "updated_at", null: false
    t.string "vendor"
    t.index ["created_at", "id"], name: "index_lookups_on_created_at_and_id"
    t.check_constraint "status IN ('resolved', 'unknown', 'failed')", name: "lookup_status"
  end

  create_table "process_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_id", null: false
    t.datetime "occurred_at", null: false
    t.bigint "pid", null: false
    t.string "process_name", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_process_events_on_event_id", unique: true
    t.index ["occurred_at", "id"], name: "index_process_events_on_occurred_at_and_id"
    t.check_constraint "pid > 0", name: "process_event_positive_pid"
  end

  create_table "vendors", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "oui", null: false
    t.string "source", default: "user", null: false
    t.datetime "updated_at", null: false
    t.index ["oui"], name: "index_vendors_on_oui", unique: true
    t.check_constraint "source IN ('seed', 'user')", name: "vendor_source"
  end
end
