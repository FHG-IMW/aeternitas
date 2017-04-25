module Aeternitas
  module Pollable
    class Configuration
      attr_accessor :deactivation_errors, :before_polling, :queue, :polling_frequency, :after_polling, :lock_options, :ignored_errors

      def initialize()
        @polling_frequency = Aeternitas::PollingFrequency::DAILY
        @before_polling = []
        @after_polling = []
        @lock_options = {
            key: ->(obj) { return "#{obj.class.name}-#{obj.id}"},
            timeout: 10.minutes,
            cooldown: 5.seconds
        }
        @deactivation_errors = []
        @ignored_errors = []
        @queue = 'polling'
      end
    end
  end
end

