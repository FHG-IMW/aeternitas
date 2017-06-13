# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170530150736) do

  create_table "aeternitas_pollable_meta_data", force: :cascade do |t|
    t.string "pollable_type", null: false
    t.integer "pollable_id", null: false
    t.datetime "next_polling", default: "1969-12-31 23:58:00", null: false
    t.datetime "last_polling"
    t.string "state"
    t.text "deactivation_reason"
    t.datetime "deactivated_at"
    t.index ["next_polling", "state"], name: "aeternitas_pollable_enqueueing"
    t.index ["pollable_id", "pollable_type"], name: "aeternitas_pollable_unique", unique: true
  end

  create_table "aeternitas_sources", primary_key: "fingerprint", id: :string, force: :cascade do |t|
    t.string "pollable_type", null: false
    t.integer "pollable_id", null: false
    t.datetime "created_at"
    t.index ["fingerprint"], name: "sqlite_autoindex_aeternitas_sources_1", unique: true
    t.index ["pollable_id", "pollable_type"], name: "aeternitas_pollable_source"
  end

  create_table "patents", force: :cascade do |t|
    t.string "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "websites", force: :cascade do |t|
    t.string "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
