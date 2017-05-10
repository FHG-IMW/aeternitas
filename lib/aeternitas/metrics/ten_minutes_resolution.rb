module Aeternitas
  module Metrics
    # A tabs resolution represeting 10 minute intervals.
    module TenMinutesResolution
      include Tabs::Resolutionable
      extend self

      PATTERN = '%Y-%m-%d-%H-%M'.freeze

      def name
        :ten_minutes
      end

      def serialize(ts)
        Time.utc(ts.year, ts.month, ts.day, ts.hour, (ts.min / 10).to_i).strftime(PATTERN)
      end

      def deserialize(str)
        dt = DateTime.strptime(str, PATTERN)
        normalize(dt)
      end

      def from_seconds(s)
        s / 10.minutes
      end

      def to_seconds
        10.minutes
      end

      def add(ts, number)
        ts + number * 10.minutes
      end

      def normalize(ts)
        Time.utc(ts.year, ts.month, ts.day, ts.hour, ts.min)
      end
    end
  end
end