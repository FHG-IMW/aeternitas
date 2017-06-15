module Aeternitas
  module Metrics
    # Wrapper for {TabsTabs::Metrics::Counter::Stats}.
    # It is for Counter metrics.
    class Counter
      include Enumerable
      extend Forwardable

      def_delegators :@tabstabs_stats, :min, :max, :avg, :each, :to_a, :first, :last

      # Create a new Wrapper
      # @param [TabsTabs::Metrics::Counter::Stats] tabstabs_stats the wrapped stats.
      def initialize(tabstabs_stats)
        @tabstabs_stats = tabstabs_stats
      end
    end
  end
end