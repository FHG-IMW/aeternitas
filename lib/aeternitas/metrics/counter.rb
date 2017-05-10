module Aeternitas
  module Metrics
    # Wrapper for {Tabs::Metrics::Counter::Stats}.
    # It is for Counter metrics.
    class Counter
      include Enumerable
      extend Forwardable

      def_delegators :@tabs_stats, :min, :max, :avg, :each, :to_a, :first, :last

      # Create a new Wrapper
      # @param [Tabs::Metrics::Counter::Stats] tabs_stats the wrapped stats.
      def initialize(tabs_stats)
        @tabs_stats = tabs_stats
      end
    end
  end
end