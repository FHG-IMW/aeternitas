# This migration creates the tables needed by Aeternitas
class AddAeternitas < ActiveRecord::Migration
  def change
    create_table :aeternitas_pollable_meta_data do |t|
      t.string :pollable_type, null: false
      t.integer :pollable_id, null: false
      t.datetime :next_polling, null: false, default: "1970-01-01 00:00:00+002"
      t.datetime :last_polling
      t.string :state
      t.text :deactivation_reason
      t.datetime :deactivated_at
    end
    add_index :aeternitas_pollable_meta_data, [:pollable_id, :pollable_type], name: 'aeternitas_pollable_unique', unique: true
    add_index :aeternitas_pollable_meta_data, [:next_polling, :state], name: 'aeternitas_pollable_enqueueing'

    create_table :aeternitas_sources, id: :string, primary_key: :fingerprint do |t|
      t.string :pollable_type, null: false
      t.integer :pollable_id, null: false
      t.datetime :created_at
    end
    add_index :aeternitas_sources, [:pollable_id, :pollable_type], name: 'aeternitas_pollable_source'
  end
end