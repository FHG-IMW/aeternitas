module Aeternitas
  # Stores default polling frequency calculation methods
  module PollingFrequency
    HOURLY  = ->(context) {}
    DAILY   = ->(context) {}
    WEEKLY  = ->(context) {}
    MONTHLY = ->(context) {}

    # Retrieves the build-in polling frequency methods by name
    #
    # @param [Symbol] name the frequency method
    # @return [Lambda] Polling frequency method
    def self.by_name(name)
      case name
      when :hourly then HOURLY
      when :daily then DAILY
      when :weekly then WEEKLY
      when :monthly then MONTHLY
      else raise(ArgumentError, "Unknown polling frequency: #{name}", self)
      end
    end
  end
end