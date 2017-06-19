module Aeternitas
  module DashboardStatistics
    def self.enqueued
      Aeternitas::PollableMetaData.enqueued.count
    end

    def self.count_polls_24h
      Aeternitas::Metrics.polls(Pollable, from: 24.hours.ago, to: Time.now, resolution: :day).map {|v| v[:count]}.sum
    end

    def self.count_failed_polls_24h
      Aeternitas::Metrics.failed_polls(Pollable, from: 24.hours.ago, to: Time.now, resolution: :day).map {|v| v[:count]}.sum
    end

    def self.polls_24h
      polls = Aeternitas::Metrics.polls(Pollable, from: 24.hours.ago, to: Time.now, resolution: :hour)
      failures = Aeternitas::Metrics.failed_polls(Pollable, from: 24.hours.ago, to: Time.now, resolution: :hour)

      {
          labels: polls.map {|v| v[:timestamp].strftime("%H:%M")},
          datasets: [
            {
                label: '# Polls',
                data: polls.map {|v| v[:count]},
                borderColor: "#96C0CE",
                backgroundColor: "rgba(171,221,235,0.5)"
            },
            {
                label: '# Failures',
                data: failures.map {|v| v[:count]},
                borderColor: "#C25B56",
                backgroundColor: "rgba(255,116,111,0.5)"
            }
          ]
      }
    end

    def self.future_polls
      labels = []
      datapoints = Hash.new do |k,v| k[v] = Array.new(0) end

      (Date.today..6.days.from_now.to_date).each_with_index do |day, i|
        labels[i] = day.strftime("%b %d")
        Aeternitas::PollableMetaData
            .where(next_polling: (day.beginning_of_day..day.end_of_day))
            .group(:pollable_class)
            .count
            .each_pair {|pollable, count| datapoints[pollable][i] = count }
      end

      colors = ColorGenerator.new(datapoints.count)

      {
          labels: labels,
          datasets: datapoints.map do |pollable, data|
            {
                label: pollable,
                data: data,
                backgroundColor: colors.next.hex,
                borderColor: colors.current.hex
            }
          end
      }
    end

    def self.pollable_growth
      pollable_classes = Aeternitas::PollableMetaData.distinct(:pollable_klass).pluck(:pollable_class)
      range = (7.days.ago.to_date..Date.today)

      colors = ColorGenerator.new(pollable_classes.count)

      datasets = pollable_classes.map do |type|
        values = Aeternitas::Metrics.pollables_created(
            type.constantize,
            from: range.begin.beginning_of_day,
            to: range.end.end_of_day,
            resolution: :day
        ).map { |v| v[:count] }

        {
          label: type,
          data: values,
          borderColor: colors.next.hex,
          backgroundColor: colors.current.hex
        }
      end

      {
        labels: range.to_a.map {|date| date.strftime("%B %d")},
        datasets: datasets
      }
    end
  end
end