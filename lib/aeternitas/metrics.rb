require 'aeternitas/metrics/ten_minutes_resolution'
require 'aeternitas/metrics/counter'
require 'aeternitas/metrics/values'

module Aeternitas
  # Provides extensive metrics for Aeternitas.
  # Every metric is scoped by pollable class.
  # Available metrics are:
  #   - polls => Number of polling runs
  #   - successful_polls => Number of successful polling runs
  #   - failed_polls => Number of failed polling runs (includes IgnoredErrors,
  #     excludes deactivation errors and Lock errors)
  #   - ignored_errors => Number of raised {Aeternitas::Errors::Ignored}
  #   - deactivation_errors => Number of errors raised which are declared as deactivation_errors
  #   - execution_time => Job execution time in seconds
  #   - guard_locked => Number of encountered locked guards
  #   - guard_timeout => Time until the guard is unlocked in seconds
  #   - guard_timeout_exceeded => Number of jobs that ran longer than the guards timeout
  #
  # Available Resolutions are:
  #   - :minute (stored for 3 days)
  #   - :ten_minutes (stored for 14 days)
  #   - :hour (stored for 2 months)
  #   - :day (stored indefinitely)
  #
  # Every metric can be accessed via a getter method:
  # @example
  #   Aeternitas::Metrics.polls MyPollable, from: 3.days.ago, to: Time.now, resolution: :hour
  #   Aeternitas::Metrics.execution_times MyPollable
  # @see #get
  module Metrics
    AVAILABLE_METRICS = {
      polls: :counter,
      successful_polls: :counter,
      failed_polls: :counter,
      ignored_errors: :counter,
      deactivations: :counter,
      execution_time: :value,
      guard_locked: :counter,
      guard_timeout: :value,
      guard_timeout_exceeded: :counter
    }.freeze

    Tabs.configure do |tabs_config|
      tabs_config.unregister_resolutions(:week, :month, :year)

      tabs_config.register_resolution Aeternitas::Metrics::TenMinutesResolution

      tabs_config.set_expirations(
        minute: 3.days,
        ten_minutes: 14.days,
        hour: 2.months
      )
    end

    AVAILABLE_METRICS.each_pair do |metric, _|
      module_eval <<-eoruby, __FILE__, __LINE__ + 1
        def self.#{metric}(pollable, from: 1.hour.ago, to: Time.now, resolution: :minute)
          self.get(:#{metric}, pollable, from: from, to: to, resolution: resolution )
        end
      eoruby
    end

    # Increses the specified counter metric for the given pollable.
    # @param [Symbol, String] name the metric
    # @param [Pollable] pollable pollable instance
    def self.log(name, pollable)
      raise('Metric not found') unless AVAILABLE_METRICS.key? name
      raise ArgumentError, "#{name} isn't a Counter" unless AVAILABLE_METRICS[name] == :counter
      Tabs.increment_counter(get_key(name, pollable.class))
    end

    # Logs a value in a value metric for the given pollable.
    # @param [Symbol String] name the metric
    # @param [Pollable] pollable pollable instance
    # @param [Object] value the value
    def self.log_value(name, pollable, value)
      raise('Metric not found') unless AVAILABLE_METRICS.key? name
      raise(ArgumentError, "#{name} isn't a Value") unless AVAILABLE_METRICS[name] == :value
      Tabs.record_value(get_key(name, pollable.class), value)
    end

    # Retrieves the stats of the given metric in the given time frame and resolution.
    # @param [Symbol String] name the metric
    # @param [Object] pollable the pollable class
    # @param [DateTime] from begin of the time frame
    # @param [DateTime] to end of the timeframe
    # @param [Symbol] resolution resolution
    # @return [Aeternitas::Metrics::Counter, Aeternitas::Metrics::Value] stats
    def self.get(name, pollable, from: 1.hour.ago, to: Time.now, resolution: :minute)
      raise('Metric not found') unless AVAILABLE_METRICS.key? name
      raise('Invalid interval') if from > to
      result = Tabs.get_stats(get_key(name, pollable), from..to, resolution)
      if AVAILABLE_METRICS[name] == :counter
        Aeternitas::Metrics::Counter.new(result)
      else
        Aeternitas::Metrics::Values.new(result)
      end
    rescue Tabs::UnknownMetricError => _
      Tabs.create_metric(get_key(name, pollable), AVAILABLE_METRICS[name].to_s)
      get(name, pollable, from: from, to: to, resolution: resolution)
    end

    # Computes the metric key of a given metric-pollable pair
    # @param [Symbol, String] name the metric
    # @param [Object] pollable_class pollable class
    # @return [String] the metric key
    def self.get_key(name, pollable_class)
      "#{name}:#{pollable_class.name}"
    end
  end
end