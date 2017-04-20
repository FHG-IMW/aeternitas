require ',,/polling_frequencies'

module Aeternitas
  module Pollable
    class Configuration
      attr_reader :polling_frequency, :before_polling, :after_polling, :queue, :deactivate_on,
                  :lock_key

      def initialize()
        @polling_frequency = Aeternitas::POLLING_FREQUENCIES[:daily]
        @before_polling = []
        @after_polling = []
        @lock_key = ->(obj) { return 'default' }
        @deactivate_on = []
        @queue = "polling"
      end

      def configure(&block)
        block.call
      end

      private

      def polling_frequency(frequency)
        if polling_frequency.is_a?(Symbol)
          @polling_frequency = Aeternitas::PollingFrequency.by_name(frequency)
        else
          @polling_frequency = frequency
        end
      end

      def before_polling(method)
        @before_polling << method
      end

      def after_polling(method)
        @after_polling << method
      end

      def deactivate_on(error_class)
        @deactivate_on << error_class
      end

      def queue(queue)
        @queue = queue
      end

      def lock_key(key)
        if key.is_a? String
          @lock_key = ->(obj) { return key }
        elsif key.is_a? Symbol
          @lock_key = ->(objs) { return obj.send(key) }
        else
          @lock_key = key
        end
      end
    end
  end
end

