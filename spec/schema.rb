ActiveRecord::Schema.define do
  self.verbose = false

  create_table :aeternitas_pollable_meta_data, force: true do |t|
    t.string :pollable_type, null: false
    t.integer :pollable_id, null: false
    t.string :pollable_class, null: false
    t.datetime :next_polling, null: false, default: "1970-01-01 00:00:00+002"
    t.datetime :last_polling
    t.string :state
    t.text :deactivation_reason
    t.datetime :deactivated_at

    t.timestamps
  end

  create_table :aeternitas_sources, id: :string, primary_key: :fingerprint do |t|
    t.string :pollable_type, null: false
    t.integer :pollable_id, null: false
    t.datetime :created_at
  end

  create_table :full_pollables, force: true do |t|
    t.string :name
    t.timestamps
    t.string :type
  end

  create_table :simple_pollables, force: true do |t|
    t.string :name
    t.timestamps
  end
end