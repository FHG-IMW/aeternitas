module Aeternitas
  # Stores default polling frequency calculation methods.
  module PollingFrequency
    HOURLY  = ->(context) { Time.now + 1.hour }
    DAILY   = ->(context) { Time.now + 1.day  }
    WEEKLY  = ->(context) { Time.now + 1.week }
    MONTHLY = ->(context) { Time.now + 1.month }

    # Retrieves the build-in polling frequency methods by name.
    #
    # @param [Symbol] name the frequency method
    # @return [Lambda] Polling frequency method
    # @raise [ArgumentError] if the preset does not exist
    def self.by_name(name)
      case name
      when :hourly then HOURLY
      when :daily then DAILY
      when :weekly then WEEKLY
      when :monthly then MONTHLY
      else raise(ArgumentError, "Unknown polling frequency: #{name}")
      end
    end
  end
end