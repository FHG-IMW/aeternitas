require 'ActiveSupport::Concern'
require '../ciwor/pollable/configuration'

module Aeternitas
  module Pollable
    extend ActiveSupport::Concern

    included do
      class_attribute :configuration
    end

    def execute_poll(polling_context)

      begin
        poll
      rescue StandardError => e
        if self.class.deactivation_errors.contains(e)
          polling_context.deactivate!
          raise ActiveRecord::Rollback
        end
      end
      update_polling_times()
    end

    def poll
      raise "#{self.class.name} does not implement #poll, required by Ciwor::Pollable"
    end

    def update_polling_times(polling_context)
      polling_context.set_last_polling(Time.now)
      polling_context.set_next_polling(self.class.configuration.polling_frequency.call(polling_context))
    end

    class_methods do
      def configuration
        self.configuration ||= Aeternitas::Pollable::Configuration.new
      end

      def polling_options(&block)
        self.configuration.configure(&block)
      end
    end
  end
end