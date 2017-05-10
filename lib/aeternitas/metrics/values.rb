module Aeternitas
  module Metrics
    # Wrapper for {Tabs::Metrics::Value::Stats}.
    # It is for Value metrics.
    class Values
      include Enumerable
      extend Forwardable

      def_delegators :@tabs_stats, :sum, :min, :max, :avg, :each, :to_a, :first, :last

      # Create a new Wrapper
      # @param [Tabs::Metrics::Value::Stats] tabs_stats the wrapped stats.
      def initialize(tabs_stats)
        @tabs_stats = tabs_stats
      end
    end
  end
end