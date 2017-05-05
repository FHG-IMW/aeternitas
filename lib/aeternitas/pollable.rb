require 'aeternitas/pollable/configuration'
require 'aeternitas/pollable/dsl'

module Aeternitas
  # Mixin that enables the frequent polling of the receiving class.
  # Classes including this method must implement the .poll method.
  # Polling behaviour can be configured via {.pollable_options}.
  # @note Can only be used by classes inheriting from ActiveRecord::Base
  # @example
  #   class MyWebsitePollable
  #     includes Aeternitas::Pollable
  #
  #     polling_options do
  #       polling_frequency :daily
  #       lock_key ->(obj) {obj.url}
  #     end
  #
  #     def poll
  #       response = HTTParty.get(self.url)
  #       raise StandardError, "#{self.url} responded with #{response.status}" unless response.success?
  #       HttpSource.create!(content: response.parsed_response)
  #     end
  #   end
  module Pollable
    extend ActiveSupport::Concern

    included do
      raise StandardError, 'Aeternitas::Pollable must inherit from ActiveRecord::Base' unless self.ancestors.include?(ActiveRecord::Base)

      has_one :pollable_meta_data, as: :pollable,
              dependent: :destroy,
              class_name: Aeternitas::PollableMetaData

      has_many :sources, as: :pollable,
               dependent: :destroy,
               class_name: Aeternitas::Source

      #validates :pollable_meta_data, presence: true

      before_create ->(pollable) { pollable.pollable_meta_data ||= pollable.build_pollable_meta_data(state: 'waiting' ); true }

      delegate :next_polling, :last_polling, :state, to: :pollable_meta_data
    end

    # This method runs the polling workflow
    def execute_poll
      _before_poll

      begin
        guard.with_lock { poll }
      rescue StandardError => e
        if pollable_configuration.deactivation_errors.include?(e.class)
          deactivate(e)
          return false
        elsif pollable_configuration.ignored_errors.include?(e.class)
          pollable_meta_data.has_errored!
          raise Aeternitas::Errors::Ignored, e
        else
          pollable_meta_data.has_errored!
          raise e
        end
      end

      _after_poll
    end

    # This method implements the class specific polling behaviour.
    # It is only called after the lock was acquired successfully.
    #
    # @abstract This method must be implemented when {Aeternitas::Pollable} is included
    def poll
      raise NotImplementedError, "#{self.class.name} does not implement #poll, required by Aeternitas::Pollable"
    end

    # Registers the instance as pollable.
    #
    # @note Manual registration is only needed if the object was created before
    #   {Aeternitas::Pollable} was included. Otherwise it is done automatically after creation.
    def register_pollable
      self.pollable_meta_data ||= create_pollable_meta_data(state: 'waiting')
    end

    # Deactivates polling of this instance
    #
    # @param [String] reason Reason for the deactivation. (E.g. an error message)
    def deactivate(reason = nil)
      meta_data = pollable_meta_data
      meta_data.deactivate
      meta_data.deactivation_reason = reason.to_s
      meta_data.save!
    end

    def guard
      guard_key = pollable_configuration.guard_options[:key].call(self)
      guard_timeout = pollable_configuration.guard_options[:timeout]
      guard_cooldown = pollable_configuration.guard_options[:cooldown]
      Aeternitas::Guard.new(guard_key, guard_cooldown, guard_timeout)
    end

    # Access the Pollables configuration
    #
    # @return [Aeternitas::Pollable::Configuration] the pollables configuration
    def pollable_configuration
      self.class.pollable_configuration
    end

    # Creates a new source with the given content if it does not exist
    # @example
    #   #...
    #   def poll
    #     response = HTTParty.get("http://example.com")
    #     add_source(response.parsed_response)
    #   end
    #   #...
    # @param [String] raw_content the sources raw content
    # @return [Aeternitas::Source] the newly created or existing source
    def add_source(raw_content)
      source = self.sources.build(raw_content: raw_content)
      return nil if sources.where(fingerprint: source.fingerprint).exists?
      source.save!
      source
    end

    private

    # Run all prepolling methods
    def _before_poll
      pollable_configuration.before_polling.each { |action| action.call(self) }
      pollable_meta_data.poll!
    end

    # Run all postpolling methods
    def _after_poll
      ActiveRecord::Base.transaction do
        pollable_meta_data.update_attributes!(
          last_polling: Time.now,
          next_polling: pollable_configuration.polling_frequency.call(self)
        )
        pollable_meta_data.wait!
      end

      pollable_configuration.after_polling.each { |action| action.call(self) }
    end

    class_methods do
      # Access the Pollables configuration
      # @return [Aeternitas::Pollable::Configuration] the pollables configuration
      def pollable_configuration
        @pollable_configuration ||= Aeternitas::Pollable::Configuration.new
      end

      def pollable_configuration=(config)
        @pollable_configuration = config
      end

      # Configure the polling process.
      # For available configuration options see {Aeternitas::Pollable::Configuration} and {Aeternitas::Pollable::DSL}
      def polling_options(&block)
        Aeternitas::Pollable::Dsl.new(self.pollable_configuration, &block)
      end

      def inherited(other)
        super
        other.pollable_configuration = @pollable_configuration.copy
      end
    end
  end
end