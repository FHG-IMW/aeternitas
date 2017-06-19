module Aeternitas
  module PollableStatistics
    def self.enqueued(pollable)
      Aeternitas::PollableMetaData
        .where(pollable_klass: pollable.name)
        .enqueued
        .count
    end

    def self.deactivated(pollable)
      Aeternitas::PollableMetaData
        .where(pollable_klass: pollable.name)
        .deactivated
        .count
    end

    def self.guard_locked_ratio(pollable)
      Aeternitas::Metrics.guard_locked_ratio(
          pollable,
          from: 24.hours.ago,
          to: Time.now,
          resolution: :hour
      ).avg
    end

    def self.timeline(pollable, from, to)
      resolution = get_resolution(from, to)
      polls = Aeternitas::Metrics.polls(pollable, from: from, to: to, resolution: resolution)
      success = Aeternitas::Metrics.successful_polls(pollable, from: from, to: to, resolution: resolution)
      failures = Aeternitas::Metrics.failed_polls(pollable, from: from, to: to, resolution: resolution)
      locks = Aeternitas::Metrics.guard_locked(pollable, from: from, to: to, resolution: resolution)

      {
        labels: polls.map {|v| v[:timestamp].strftime("%B %d. %H:%M")},
        datasets: [
          {
            label: '# Polls',
            data: polls.map {|v| v[:count]},
            borderColor: "#96C0CE",
            backgroundColor: "rgba(171,221,235,0.5)",
            fill: false,
            type: 'line'
          },
          {
              label: '# Successfull Polls',
              data: polls.map {|v| v[:count]},
              borderColor: "#32b643",
              backgroundColor: "rgba(50,182,67,0.5)",
          },
          {
            label: '# Failures',
            data: failures.map {|v| v[:count]},
            borderColor: "#C25B56",
            backgroundColor: "rgba(255,116,111,0.5)",
          },
          {
            label: '# Guard Locked',
            data: locks.map {|v| v[:count]},
            borderColor: "#ffd59c",
            backgroundColor: "rgba(255,213,156,0.5)",
          }
        ]
      }
    end

    def self.execution_time(pollable, from, to)
      resolution = get_resolution(from, to)
      polling_time = Aeternitas::Metrics.execution_time(pollable, from: from, to: to, resolution: resolution)

      {
        labels: polling_time.map {|v| v[:timestamp].strftime("%B %d. %H:%M")},
        datasets: [
          {
            label: 'Average',
            data: polling_time.map {|v| (v[:avg] * 1000).to_i},
            borderColor: "#96C0CE",
            backgroundColor: "rgba(171,221,235,0.5)",
            fill: false,
            type: 'line'
          },
          {
            label: 'Minimum',
            data: polling_time.map {|v| (v[:min]).to_i},
            borderColor: "#32b643",
            backgroundColor: "rgba(50,182,67,0.5)",
            fill: false,
            type: 'line'
          },
          {
            label: 'Maximum',
            data: polling_time.map {|v| (v[:max]).to_i},
            borderColor: "#ffd59c",
            backgroundColor: "rgba(255,213,156,0.5)",
            fill: false,
            type: 'line'
          }
        ]
      }
    end

    def self.pollable_growth(pollable, from, to)
      data = Aeternitas::Metrics.pollables_created(
          pollable,
          from: from,
          to: to,
          resolution: get_resolution(from, to)
      )

      {
        labels: data.map  {|v| v[:timestamp].strftime('%B %d. %H:%M') },
        datasets: [{
          label: "# of created #{pollable.name.pluralize}",
          data: data.map { |v| v[:count] },
          borderColor: '#96C0CE',
          backgroundColor: 'rgba(171,221,235,0.5)',
          fill: false,
          type: 'line'
        }]
      }
    end

    def self.deactivated_pollables(pollable)
      Aeternitas::PollableMetaData.deactivated.includes(:pollable).where(pollable_class: pollable.name)
    end

    def self.get_resolution(from, to)
      case (to.to_time - from.to_time)
      when 0.hours..2.hours
        :minute
      when 2.hours..12.hours
        :ten_minutes
      when 12.hours..3.days
        :hour
      else
        :day
      end
    end
  end
end