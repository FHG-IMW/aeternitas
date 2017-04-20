module Aeternitas
  class PollingContext

    def initialize(pollable, poll_data)
      @poll_data = poll_data
      @pollable = pollable
      @configuration = pollable.class.configuration
    end

    def poll_time
      @poll_data.next_polling
    end

    def lock_key
      @lock_key ||= @configuration.lock_key.call(@pollable)
    end

  end
end