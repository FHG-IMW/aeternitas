require 'spec_helper'

describe Aeternitas::Metrics do
  let(:pollable) {FullPollable.create(name: 'Foo')}

  it 'integrates' do
    Aeternitas::Metrics.log(:polls, pollable)
    Aeternitas::Metrics.log(:polls, pollable)
    Aeternitas::Metrics.log_value(:execution_time, pollable, 42)
    Aeternitas::Metrics.log_value(:execution_time, pollable, 21)
    Aeternitas::Metrics.log(:successful_polls, pollable)

    expect(Aeternitas::Metrics.polls(FullPollable).max).to be(2)
    expect(Aeternitas::Metrics.polls(SimplePollable).max).to be(0)
    expect(Aeternitas::Metrics.execution_time(FullPollable).sum).to eq(63)
    expect(Aeternitas::Metrics.guard_timeout(SimplePollable).sum).to eq(0)
  end

  describe '.log' do
    it 'increases the counter' do
      expect(Tabs).to receive(:increment_counter).with('polls:FullPollable')
      Aeternitas::Metrics.log(:polls, FullPollable.new)
    end

    it 'raises an error if the metric does not exist' do
      expect { Aeternitas::Metrics.log(:unknown, pollable) }.to(
        raise_error(StandardError, 'Metric not found')
      )
    end

    it 'raises an error if the metric is not a counter' do
      expect { Aeternitas::Metrics.log(:execution_time, pollable) }.to(
        raise_error(ArgumentError, 'execution_time isn\'t a Counter')
      )
    end
  end

  describe '.log_value' do
    it 'logs the values' do
      expect(Tabs).to receive(:record_value).with('execution_time:FullPollable', 42)
      Aeternitas::Metrics.log_value(:execution_time, pollable, 42)
    end

    it 'raises an error if the metric does not exist' do
      expect { Aeternitas::Metrics.log_value(:unknown, pollable, 42) }.to(
        raise_error(StandardError, 'Metric not found')
      )
    end

    it 'raises an error if the metric is not a values metric' do
      expect { Aeternitas::Metrics.log_value(:polls, pollable, 42) }.to(
        raise_error(ArgumentError, 'polls isn\'t a Value')
      )
    end
  end

  describe '.get' do
    let(:from) { 10.minutes.ago }
    let(:to) { Time.now }
    let(:resolution) { :hour }

    before(:each) {  }

    it 'it calls get get_stats method' do
      expect(Tabs).to receive(:get_stats).with('polls:FullPollable', from..to, resolution)
      Aeternitas::Metrics.get(:polls, pollable.class, from: from, to: to, resolution: resolution)
    end

    it 'wraps the response inside Aeternitas::Metrics::Counter if the metric is a counter' do
      Tabs.create_metric('polls:FullPollable', 'counter')
      expect(Aeternitas::Metrics.get(:polls, pollable.class)).to(
        be_a(Aeternitas::Metrics::Counter)
      )
    end

    it 'wraps the response inside Aeternitas::Metrics::Value if the metric is a value metric' do
      Tabs.create_metric('polls:FullPollable', 'counter')
      expect(Aeternitas::Metrics.get(:execution_time, pollable.class)).to(
        be_a(Aeternitas::Metrics::Values)
      )
    end

    it 'raises an error if the metric does not exist' do
      expect { Aeternitas::Metrics.get(:unknown, FullPollable) }.to(
        raise_error(StandardError, 'Metric not found')
      )
    end

    it 'returns an empty metric if the redis key does not exist' do
      expect(Aeternitas::Metrics.get(:polls, pollable.class).max).to(
        be(0)
      )
    end
  end

  describe 'metric getters' do
    it 'creates a getter for every metric' do
      Aeternitas::Metrics::AVAILABLE_METRICS.each_key do |metric|
        expect(Aeternitas::Metrics).to respond_to(metric)
      end
    end

    it 'calls the get method when a metric getter is called' do
      from = 10.minutes.ago
      to = Time.now
      resolution = :hour
      Aeternitas::Metrics::AVAILABLE_METRICS.each_key do |metric|
        expect(Aeternitas::Metrics).to receive(:get).with(metric, FullPollable, from: from, to: to, resolution: resolution)
        Aeternitas::Metrics.send(metric, FullPollable, from: from, to: to, resolution: resolution)
      end
    end
  end

  describe '.calculate_ratio' do
    it 'calculates the right ratio' do
      base = [
        { 'timestamp' => "2017-01-01 00:00:00 UTC", 'count' => 100 },
        { 'timestamp' => "2017-01-01 00:01:00 UTC", 'count' => 50 },
        { 'timestamp' => "2017-01-01 00:02:00 UTC", 'count' => 300 }
      ]

      target = [
        { 'timestamp' => "2017-01-01 00:00:00 UTC", 'count' => 10 },
        { 'timestamp' => "2017-01-01 00:01:00 UTC", 'count' => 25 },
        { 'timestamp' => "2017-01-01 00:02:00 UTC", 'count' => 0 }
      ]

      expect(Aeternitas::Metrics.calculate_ratio(base, target)).to(
        eq(
          [
            { timestamp: DateTime.parse('2017-01-01 00:00:00 UTC'), ratio: 0.1 },
            { timestamp: DateTime.parse('2017-01-01 00:01:00 UTC'), ratio: 0.5 },
            { timestamp: DateTime.parse('2017-01-01 00:02:00 UTC'), ratio: 0.0 }
          ]
        )
      )
    end
  end
end