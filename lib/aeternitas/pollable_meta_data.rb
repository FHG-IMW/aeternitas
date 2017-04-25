require 'aasm'

module Aeternitas
  class PollableMetaData < ActiveRecord::Base
    self.table_name = 'aeternitas_pollable_meta_data'

    include AASM
    ######
    # create_table aeternitas_pollable_meta_data do |t|
    #   t.string :pollable_type, null: false
    #   t.integer :pollable_id, null: false
    #   t.datetime :next_polling, null: false, default: "1970-01-01 00:00:00+002"
    #   t.datetime :last_polling
    #   t.string :state
    #   t.text :deactivation_reason
    #   t.datetime :deactivated_at
    # end
    ######

    belongs_to :pollable, polymorphic: true

    validates :pollable_type, presence: true, uniqueness: { scope: :pollable_id }
    validates :pollable_id, presence: true, uniqueness: { scope: :pollable_type }
    validates :next_polling, presence: true

    aasm :state do
      state :waiting, initial: true
      state :enqueued, :active, :deactivated, :errored

      event :enqueue do
        transitions from: %i[waiting deactivated], to: :enqueued
      end

      event :poll do
        transitions from: %i[waiting enqueued], to: :active
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

  end
end