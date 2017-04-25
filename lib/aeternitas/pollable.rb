require 'aeternitas/pollable/configuration'
require 'aeternitas/pollable/dsl'

module Aeternitas
  module Pollable
    extend ActiveSupport::Concern

    included do
      has_one :pollable_meta_data, as: :pollable,
              dependent: :destroy,
              class_name: Aeternitas::PollableMetaData

      #validates :pollable_meta_data, presence: true

      before_validation ->(pollable) { pollable.pollable_meta_data ||= pollable.build_pollable_meta_data(state: 'waiting' ) }

      delegate :next_polling, :last_polling, :state, to: :pollable_meta_data
    end

    def execute_poll()
      _before_poll

      begin
        with_lock { poll }
      rescue StandardError => e
        if configuration.deactivation_errors.include?(e.class)
          deactivate(e)
          return false
        elsif configuration.ignored_errors.include?(e.class)
          pollable_meta_data.has_errored!
          raise Aeternitas::Errors::Ignored, e
        else
          pollable_meta_data.has_errored!
          raise e
        end
      end

      _after_poll
    end

    # @abstract
    def poll
      raise "#{self.class.name} does not implement #poll, required by Ciwor::Pollable"
    end

    def register_pollable
      self.pollable_meta_data ||= create_pollable_meta_data(state: 'waiting')
    end

    def deactivate(reason = nil)
      meta_data = pollable_meta_data
      meta_data.deactivate
      meta_data.deactivation_reason = reason.to_s
      meta_data.save!
    end

    def with_lock(&block)
      lock_key = configuration.lock_options[:key].call(self)
      lock_timeout = configuration.lock_options[:timeout]
      lock_cooldown = configuration.lock_options[:cooldown]
      lock = LockWithCooldown.new(lock_key, lock_cooldown, lock_timeout)
      lock.with_lock(&block)
    end

    def configuration
      self.class.configuration
    end

    private

    def _before_poll
      configuration.before_polling.each { |action| action.call(self) }
      pollable_meta_data.poll!
    end

    def _after_poll
      pollable_meta_data.update_attributes!(
        last_polling: Time.now,
        next_polling: configuration.polling_frequency.call(self)
      )
      pollable_meta_data.wait!

      configuration.after_polling.each { |action| action.call(self) }
    end

    class_methods do
      def configuration
        @configuration ||= Aeternitas::Pollable::Configuration.new
      end

      def polling_options(&block)
        Aeternitas::Pollable::Dsl.new(configuration, &block)
      end
    end
  end
end