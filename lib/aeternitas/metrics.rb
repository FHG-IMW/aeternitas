require 'aeternitas/metrics/ten_minutes_resolution'
require 'aeternitas/metrics/counter'
require 'aeternitas/metrics/values'
require 'aeternitas/metrics/ratio'

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
  #   - pollables_created => Number of created pollables
  #   - sources_created => Number of created sources
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
      guard_timeout_exceeded: :counter,
      sources_created: :counter,
      pollables_created: :counter
    }.freeze

    TabsTabs.configure do |tabstabs_config|
      tabstabs_config.unregister_resolutions(:week, :month, :year)

      tabstabs_config.register_resolution Aeternitas::Metrics::TenMinutesResolution

      tabstabs_config.set_expirations(
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
    # @param [Pollable] pollable_class pollable instance
    def self.log(name, pollable_class)
      raise('Metric not found') unless AVAILABLE_METRICS.key? name
      raise ArgumentError, "#{name} isn't a Counter" unless AVAILABLE_METRICS[name] == :counter
      TabsTabs.increment_counter(get_key(name, pollable_class))
      TabsTabs.increment_counter(get_key(name, Aeternitas::Pollable))
    end

    # Logs a value in a value metric for the given pollable.
    # @param [Symbol String] name the metric
    # @param [Pollable] pollable_class pollable instance
    # @param [Object] value the value
    def self.log_value(name, pollable_class, value)
      raise('Metric not found') unless AVAILABLE_METRICS.key? name
      raise(ArgumentError, "#{name} isn't a Value") unless AVAILABLE_METRICS[name] == :value
      TabsTabs.record_value(get_key(name, pollable_class), value)
      TabsTabs.record_value(get_key(name, Aeternitas::Pollable), value)
    end

    # Retrieves the stats of the given metric in the given time frame and resolution.
    # @param [Symbol String] name the metric
    # @param [Object] pollable_class the pollable class
    # @param [DateTime] from begin of the time frame
    # @param [DateTime] to end of the timeframe
    # @param [Symbol] resolution resolution
    # @return [Aeternitas::Metrics::Counter, Aeternitas::Metrics::Value] stats
    def self.get(name, pollable_class, from: 1.hour.ago, to: Time.now, resolution: :minute)
      raise('Metric not found') unless AVAILABLE_METRICS.key? name
      raise('Invalid interval') if from > to
      result = TabsTabs.get_stats(get_key(name, pollable_class), from..to, resolution)
      if AVAILABLE_METRICS[name] == :counter
        Counter.new(result)
      else
        Values.new(result)
      end
    rescue TabsTabs::UnknownMetricError => _
      TabsTabs.create_metric(get_key(name, pollable_class), AVAILABLE_METRICS[name].to_s)
      get(name, pollable_class, from: from, to: to, resolution: resolution)
    end

    # Returns the failure ratio of the given job for given time frame and resolution
    # @param [Symbol String] name the metric
    # @param [Object] pollable_class the pollable class
    # @param [DateTime] from begin of the time frame
    # @param [DateTime] to end of the timeframe
    # @param [Symbol] resolution resolution
    # @return [Aeternitas::Metrics::Ratio] ratio time series
    def self.failure_ratio(pollable_class, from: 1.hour.ago, to: Time.now, resolution: :minute)
      polls = polls(pollable_class, from: from, to: to, resolution: resolution)
      failed_polls = failed_polls(pollable_class, from: from, to: to, resolution: resolution)
      Ratio.new(from, to, resolution, calculate_ratio(polls, failed_polls))
    end

    # Returns the lock ratio of the given job for given time frame and resolution
    # @param [Symbol String] name the metric
    # @param [Object] pollable_class the pollable class
    # @param [DateTime] from begin of the time frame
    # @param [DateTime] to end of the timeframe
    # @param [Symbol] resolution resolution
    # @return [Aeternitas::Metrics::Ratio] ratio time series
    def self.guard_locked_ratio(pollable_class, from: 1.hour.ago, to: Time.now, resolution: :minute)
      polls = polls(pollable_class, from: from, to: to, resolution: resolution)
      guard_locked = guard_locked(pollable_class, from: from, to: to, resolution: resolution)
      Ratio.new(from, to, resolution, calculate_ratio(polls, guard_locked))
    end

    # Computes the metric key of a given metric-pollable pair
    # @param [Symbol, String] name the metric
    # @param [Object] pollable_class pollable class
    # @return [String] the metric key
    def self.get_key(name, pollable_class)
      "#{name}:#{pollable_class.name}"
    end

    # Computes the ratio of a base counter time series and a target counter time series
    # @param [Array] base base time series data
    # @param [Array] target target time series data
    # @return [Array] ratio time series data
    def self.calculate_ratio(base, target)
      base.zip(target).map do |b, t|
        {
          timestamp: b['timestamp'],
          ratio: b['count'].to_i.zero? ? 0 : t['count'].to_i / b['count'].to_f
        }.with_indifferent_access
      end
    end
  end
end