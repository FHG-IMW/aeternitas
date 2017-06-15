module Aeternitas
  module Metrics
    # Stores time series data for ratios
    # @!attribute [r] from
    #   @return [DateTime] start of the time series
    # @!attribute [r] to
    #   @return [DateTime] end of the time series
    # @!attribute [r] resolution
    #   @return [Symbol] resolution of the time series
    # @!attribute [r] values
    #   @return [Array] time series data
    # The time series values have the following format:
    #   {
    #     timestamp: DateTime("2000-01-01 00:00:00 UTC"),
    #     ratio: 0.01
    #   }
    class Ratio
      include Enumerable

      attr_reader :from, :to, :resolution, :values

      # Create a new ratio time series
      # @param [DateTime] from start of the time series
      # @param [DateTime] to end of the time series
      # @param [Symbol] resolution time series resolution
      # @param [Array] values time series data
      def initialize(from, to, resolution, values)
        @from = from
        @to = to
        @resolution = resolution
        @values = values
      end

      def each(&block)
        @values.each(&block)
      end

      def to_a
        @values.to_a
      end

      # Computes the minimum ration within the time series.
      # @return [Float] the minimum ratio
      def min
        @values.min_by { |v| v['ratio'] }['ratio']
      end

      # Computes the maximum ration within the time series.
      # @return [Float] the maximum ratio
      def max
        @values.max_by { |v| v['ratio'] }['ratio']
      end

      # Computes the average ration within the time series.
      # @return [Float] the average ratio
      def avg
        return 0 if count.zero?
        p @values
        @values.inject(0) { |sum, v| sum + v[:ratio] } / @values.count
      end

      def to_s
        values.to_s
      end
    end
  end
end