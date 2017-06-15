require 'aasm'

module Aeternitas
  # Stores the meta data of all pollables
  # Every pollable needs to have exactly one meta data object
  class PollableMetaData < ActiveRecord::Base
    self.table_name = 'aeternitas_pollable_meta_data'

    include AASM
    ######
    # create_table aeternitas_pollable_meta_data do |t|
    #   t.string :pollable_type, null: false
    #   t.integer :pollable_id, null: false
    #   t.string :pollable_class, null: false
    #   t.datetime :next_polling, null: false, default: "1970-01-01 00:00:00+002"
    #   t.datetime :last_polling
    #   t.string :state
    #   t.text :deactivation_reason
    #   t.datetime :deactivated_at
    # end
    # create_index :aeternitas_pollable_meta_data, [:pollable_id, :pollable_type], name: 'aeternitas_pollable_unique', unique: true
    # create_index :aeternitas_pollable_meta_data, [:next_polling, :state], name: 'aeternitas_pollable_enqueueing'
    # create_index :aeternitas_pollable_meta_data, [:pollable_class], name: 'aeternitas_pollable_class'
    ######

    belongs_to :pollable, polymorphic: true

    validates :pollable_type, presence: true, uniqueness: { scope: :pollable_id }
    validates :pollable_id, presence: true, uniqueness: { scope: :pollable_type }
    validates :pollable_class, presence: true
    validates :next_polling, presence: true

    aasm column: :state do
      state :waiting, initial: true
      state :enqueued
      state :active
      state :deactivated
      state :errored

      event :enqueue do
        transitions from: %i[waiting deactivated errored], to: :enqueued
      end

      event :poll do
        transitions from: %i[waiting enqueued errored], to: :active
      end

      event :has_errored do
        transitions from: :active, to: :errored
      end

      event :wait do
        transitions from: :active, to: :waiting
      end

      event :deactivate do
        transitions to: :deactivated
      end
    end

    scope(:due, ->() { waiting.where('next_polling < ?', Time.now) })

    # Disables polling of this instance
    #
    # @param [String] reason Reason for the deactivation. (E.g. an error message)
    def disable_polling(reason = nil)
      self.deactivate
      self.deactivation_reason = reason.to_s
      self.deactivated_at = Time.now
      self.save!
    end
  end
end