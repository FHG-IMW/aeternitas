module Aeternitas
  module Pollable
    # DSL wrapper to conveniently configure pollables
    class Dsl
      # Create a new DSL instance and configure the configuration with the given block
      # @param [Aeternitas::Pollable::Configuration] configuration a pollables configuration
      # @param [Proc] block configuration block
      def initialize(configuration, &block)
        @configuration = configuration
        instance_eval(&block)
      end

      # Configures the polling frequency. This can be either the name of a {Aeternitas::PollingFrequency}
      # or a lambda that recives a pollable instance and returns a DateTime
      #
      # @param [Symbol, Proc] frequency Sets the polling frequency.
      #   representing the next polling time.
      # @example using a preset
      #   polling_frequency :weekly
      # @example using a custom block
      #   polling_frequency ->(pollable) {Time.now + 1.month + Time.now - pollable.created_at.to_i / 3.month * 1.month}
      # @todo allow custom methods via reference
      def polling_frequency(frequency)
        if frequency.is_a?(Symbol)
          @configuration.polling_frequency = Aeternitas::PollingFrequency.by_name(frequency)
        else
          @configuration.polling_frequency = frequency
        end
      end

      # Configures a method that will be run before every poll
      #
      # @param [Symbol, Block] method method or method name
      # @example method by reference
      #   before_polling :my_method
      #   ...
      #   def my_method(pollable) do_something end
      # @example method by block
      #   before_polling ->(pollable) {do_something}
      def before_polling(method)
        if method.is_a?(Symbol)
          @configuration.before_polling << ->(pollable) { pollable.send(method) }
        else
          @configuration.before_polling << method
        end
      end

      # Configures a method that will be run after every successful poll
      #
      # @param [Symbol, Block] method method or method name
      # @example method by reference
      #   after:polling :my_method
      #   ...
      #   def my_method(pollable) do_something end
      # @example method by block
      #   after_polling ->(pollable) {do_something}
      def after_polling(method)
        if method.is_a?(Symbol)
          @configuration.after_polling << ->(pollable) { pollable.send(method) }
        else
          @configuration.after_polling << method
        end
      end

      # Configure errors that will cause the pollable instance to be deactivated imideately of they
      # occur during the poll.
      #
      # @param [Object] error_class error classes
      def deactivate_on(*error_class)
        @configuration.deactivation_errors |= error_class
      end

      # Configure errors that will be wrapped in {Aeternitas::Error::Ignored}.
      #
      # @param [Object] error_class error classes
      def ignore_error(*error_class)
        @configuration.ignored_errors |= error_class
      end

      # Configure the name of the Sidekiq queue in which the instances poll job will be enqueued.
      # @param [String] queue name of the Sidekiq queue
      def queue(queue)
        @configuration.queue = queue
      end

      # Configure the lock key. This can be either a fixes String, a method reference or a block
      #
      # @param [String, Symbol, Proc] key lock key
      # @example using a fixed String
      #   lock_key "MyLockKey"
      # @example using a method reference
      #   lock_key :url
      # @example using a block
      #   lock_key ->(pollable) {URI.parse(pollable.url).host}
      def lock_key(key)
        @configuration.lock_options[:key] = case key
                                when Symbol
                                  ->(obj) { return obj.send(key) }
                                when Proc
                                  key
                                else
                                  ->(obj) { return key.to_s }
                                end
      end

      # Configure the lock.
      # @see lock_key
      # @see Aeternitas::LockWithCooldown
      # @param [Hash] options lock options
      def lock_options(options)
        @configuration.lock_options.merge!(options)
      end
    end
  end
end

