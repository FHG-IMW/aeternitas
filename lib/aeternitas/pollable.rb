require 'aeternitas/pollable/configuration'
require 'aeternitas/pollable/dsl'

module Aeternitas
  # Mixin that enables the frequent polling of the receiving class.
  # Classes including this method must implement the .poll method.
  # Polling behaviour can be configured via {.pollable_options}.
  # @note Can only be used by classes inheriting from ActiveRecord::Base
  # @example
  #   class MyWebsitePollable < ActiveRecord::Base
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
              class_name: 'Aeternitas::PollableMetaData'

      has_many :sources, as: :pollable,
               dependent: :destroy,
               class_name: 'Aeternitas::Source'

      validates :pollable_meta_data, presence: true

      before_validation ->(pollable) { pollable.pollable_meta_data ||= pollable.build_pollable_meta_data(state: 'waiting' ); true }

      after_commit ->(pollable) { Aeternitas::Metrics.log(:pollables_created, pollable.class) }, on: :create

      delegate :next_polling, :last_polling, :disable_polling, to: :pollable_meta_data
    end

    # This method runs the polling workflow
    def execute_poll
      _before_poll

      begin
        guard.with_lock { poll }
      rescue StandardError => e
        if pollable_configuration.deactivation_errors.include?(e.class)
          disable_polling(e)
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
    rescue StandardError => e
      begin
        log_poll_error(e)
      ensure
        raise e
      end
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
      source = self.sources.create(raw_content: raw_content)
      return nil unless source.persisted?

      Aeternitas::Metrics.log(:sources_created, self.class)
      source
    end

    private

    # Run all prepolling methods
    def _before_poll
      @start_time = Time.now
      Aeternitas::Metrics.log(:polls, self.class)

      pollable_configuration.before_polling.each { |action| action.call(self) }
      pollable_meta_data.poll!
    end

    # Run all postpolling methods
    def _after_poll
      pollable_meta_data.wait! do
        pollable_meta_data.update_attributes!(
          last_polling: Time.now,
          next_polling: pollable_configuration.polling_frequency.call(self)
        )
      end

      pollable_configuration.after_polling.each { |action| action.call(self) }

      if @start_time
        execution_time = Time.now - @start_time
        Aeternitas::Metrics.log_value(:execution_time, self.class, execution_time)
        Aeternitas::Metrics.log(:guard_timeout_exceeded, self.class) if execution_time > pollable_configuration.guard_options[:timeout]
        @start_time = nil
      end
      Aeternitas::Metrics.log(:successful_polls, self.class)
    end

    def log_poll_error(e)
      if e.is_a? Aeternitas::Guard::GuardIsLocked
        Aeternitas::Metrics.log(:guard_locked, self.class)
        Aeternitas::Metrics.log_value(:guard_timeout, self.class, e.timeout - Time.now)
      elsif e.is_a? Aeternitas::Errors::Ignored
        Aeternitas::Metrics.log(:ignored_error, self.class)
        Aeternitas::Metrics.log(:failed_polls, self.class)
      else
        Aeternitas::Metrics.log(:failed_polls, self.class)
      end
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