module Aeternitas
  module PollablesIndexStatistics
    def self.available_pollables
      Aeternitas::PollableMetaData.distinct(:pollable_klass).pluck(:pollable_klass).map(&:constantize)
    end

    def self.failure_ratio(pollable)
      Aeternitas::Metrics.failure_ratio(
        pollable,
        from: 24.hours.ago,
        to: Time.now,
        resolution: :hour
      ).avg
    end

    def self.guard_locked_ratio(pollable)
      Aeternitas::Metrics.guard_locked_ratio(
          pollable,
          from: 24.hours.ago,
          to: Time.now,
          resolution: :hour
      ).avg
    end

    def self.polls(pollable)
      Aeternitas::Metrics.polls(
          pollable,
          from: 24.hours.ago,
          to: Time.now,
          resolution: :hour
      ).map { |v| v[:count] }.sum
    end
  end
end