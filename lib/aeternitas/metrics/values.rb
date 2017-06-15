module Aeternitas
  module Metrics
    # Wrapper for {TabsTabs::Metrics::Value::Stats}.
    # It is for Value metrics.
    class Values
      include Enumerable
      extend Forwardable

      def_delegators :@tabstabs_stats, :sum, :min, :max, :avg, :each, :to_a, :first, :last

      # Create a new Wrapper
      # @param [TabsTabs::Metrics::Value::Stats] tabstabs_stats the wrapped stats.
      def initialize(tabstabs_stats)
        @tabstabs_stats = tabstabs_stats
      end
    end
  end
end