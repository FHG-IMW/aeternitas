module Aeternitas
  module Pollable
    class Dsl
      def initialize(configuration, &block)
        @configuration = configuration
        instance_eval(&block)
      end

      private

      def polling_frequency(frequency)
        if frequency.is_a?(Symbol)
          @configuration.polling_frequency = Aeternitas::PollingFrequency.by_name(frequency)
        else
          @configuration.polling_frequency = frequency
        end
      end

      def before_polling(method)
        if method.is_a?(Symbol)
          @configuration.before_polling << ->(pollable) { pollable.send(method) }
        else
          @configuration.before_polling << method
        end
      end

      def after_polling(method)
        if method.is_a?(Symbol)
          @configuration.after_polling << ->(pollable) { pollable.send(method) }
        else
          @configuration.after_polling << method
        end
      end

      def deactivate_on(*error_class)
        @configuration.deactivation_errors |= error_class
      end

      def ignore_error(*error_class)
        @configuration.ignored_errors |= error_class
      end

      def queue(queue)
        @configuration.queue = queue
      end

      def lock_key(key)
        @configuration.lock_options[:key] = case key
                                when String
                                  ->(obj) { return key }
                                when Symbol
                                  ->(obj) { return obj.send(key) }
                                else
                                  key
                              end
      end

      def lock_options(options)
        @configuration.lock_options.merge!(options)
      end
    end
  end
end

