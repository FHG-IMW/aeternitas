require 'spec_helper'

describe Aeternitas::Pollable do
  let(:simple_pollable) { SimplePollable.create!(name: 'Foo') }
  let(:full_pollable) { FullPollable.create!(name: 'Foo') }

  describe '#execute_poll' do
    before(:each) do
      allow(Aeternitas::Metrics).to receive(:log).and_return(nil)
      allow(Aeternitas::Metrics).to receive(:log_value).and_return(nil)
    end

    it 'logs the poll' do
      expect(Aeternitas::Metrics).to receive(:log).with(:polls, FullPollable)
      full_pollable.execute_poll
    end

    context 'when the lock can be acquired' do
      it 'tries to grab the lock' do
        expect(full_pollable).to receive(:guard).and_call_original
        full_pollable.execute_poll
      end

      it 'calls all before_polling methods' do
        full_pollable.execute_poll
        expect(full_pollable.before_polling).to eq(%i[block method])
      end

      it 'calls the poll method' do
        expect(full_pollable).to receive(:poll)
        full_pollable.execute_poll
      end

      it 'updates the polling_times' do
        expected_next_polling = full_pollable.next_polling + 3.days
        full_pollable.execute_poll
        expect(full_pollable.pollable_meta_data.last_polling).to be_within(1.second).of(Time.now)
        expect(full_pollable.pollable_meta_data.next_polling).to be_within(1.second).of(expected_next_polling)

        simple_pollable.execute_poll
        expect(simple_pollable.pollable_meta_data.last_polling).to be_within(1.second).of(Time.now)
        expect(simple_pollable.pollable_meta_data.next_polling).to be_within(1.second).of(1.day.from_now)
      end

      it 'calls all after_polling methods' do
        full_pollable.execute_poll
        expect(full_pollable.after_polling).to eq(%i[block method])
      end

      it 'logs the execution time' do
        allow(full_pollable).to(
          receive(:poll) { full_pollable.instance_variable_set(:@start_time, 20.seconds.ago) }
        )

        expect(Aeternitas::Metrics).to receive(:log_value).with(
          :execution_time,
          FullPollable,
          be_within(1.second).of(20.seconds)
        )

        full_pollable.execute_poll
      end

      it 'does not log guard timeout transgression if it does not exceed' do
        allow(full_pollable).to(
          receive(:poll) { full_pollable.instance_variable_set(:@start_time, 20.seconds.ago) }
        )
        expect(Aeternitas::Metrics).not_to receive(:log).with(:guard_timeout_exceeded, FullPollable)
        full_pollable.execute_poll
      end

      it 'logs guard timeout transgression if it exceeds' do
        allow(full_pollable).to(
          receive(:poll) { full_pollable.instance_variable_set(:@start_time, 20.minutes.ago) }
        )
        expect(Aeternitas::Metrics).to receive(:log).with(:guard_timeout_exceeded, FullPollable)
        full_pollable.execute_poll
      end

      it 'logs a successful execution' do
        expect(Aeternitas::Metrics).to receive(:log).with(:successful_polls, FullPollable)
        full_pollable.execute_poll
      end
    end

    context 'when the lock can not be acquired' do
      before(:each) do
        allow_any_instance_of(Aeternitas::Guard).to(
          receive(:with_lock).
          and_raise(Aeternitas::Guard::GuardIsLocked.new('key', 1.hour.from_now))
        )
      end

      it 'does not run the poll_method' do
        full_pollable.execute_poll rescue nil
        expect(full_pollable.polled).to be nil
      end

      it 'logs the guard_locked occurrence' do
        expect(Aeternitas::Metrics).to receive(:log).with(:guard_locked, FullPollable)
        full_pollable.execute_poll rescue nil
      end

      it 'logs the timeout' do
        expect(Aeternitas::Metrics).to receive(:log_value).with(
          :guard_timeout,
          FullPollable,
          be_within(1.second).of(1.hour)
        )
        full_pollable.execute_poll rescue nil
      end
    end

    context 'when the poll method throws an ignored error' do
      let(:ignored_error) { FullPollable::IgnoredError.new('Foo') }

      before(:each) {
        allow(full_pollable).to(
            receive(:poll).and_raise( ignored_error )
        )
      }

      it 'throws a Aeternitas::IgnoredError' do
        expect { full_pollable.execute_poll }.to(
          raise_error(Aeternitas::Errors::Ignored) { |e| expect(e.original_error).to be(ignored_error) }
        )
      end

      it 'does not run after_poll methods' do
        expect(full_pollable).not_to receive(:_after_poll)
        full_pollable.execute_poll rescue nil
        expect(full_pollable.after_polling).to be(nil)
      end

      it 'sets the state to `errored`' do
        full_pollable.execute_poll rescue nil
        expect(full_pollable.pollable_meta_data.errored?).to be(true)
      end

      it 'logs an ignored error' do
        expect(Aeternitas::Metrics).to receive(:log).with(:ignored_error, FullPollable)
        full_pollable.execute_poll rescue nil
      end

      it 'logs a failed poll' do
        expect(Aeternitas::Metrics).to receive(:log).with(:failed_polls, FullPollable)
        full_pollable.execute_poll rescue nil
      end
    end

    context 'when the poll method throws an deactivation error' do
      let(:deactivation_error) { FullPollable::DeactivationError.new('Foo') }
      before(:each) do
        allow(full_pollable).to(
          receive(:poll).and_raise(deactivation_error)
        )
      end

      it 'deactivates the pollable' do
        expect(full_pollable).to receive(:disable_polling).with(deactivation_error).and_call_original
        full_pollable.execute_poll
        expect(full_pollable.pollable_meta_data.deactivated?).to be(true)
        expect(full_pollable.pollable_meta_data.deactivation_reason).to eq('Foo')
      end

      it 'does not run after_poll methods' do
        expect(full_pollable).not_to receive(:_after_poll)
        full_pollable.execute_poll
        expect(full_pollable.after_polling).to be(nil)
      end
    end
  end

  describe '#register_pollable' do
    context 'when the pollable is not registered' do
      before(:each) do
        full_pollable.pollable_meta_data.destroy!
        full_pollable.reload
      end

      it 'creates a new pollable meta data' do
        full_pollable.register_pollable
        expect(Aeternitas::PollableMetaData.count).to be(1)
        expect(full_pollable.pollable_meta_data.present?).to be(true)
        expect(full_pollable.pollable_meta_data.state).to eq 'waiting'
      end
    end

    context 'when the pollable is registered' do
      it 'does not create a new pollable meta data' do
        meta_data = full_pollable.pollable_meta_data
        full_pollable.register_pollable
        expect(Aeternitas::PollableMetaData.count).to be(1)
        expect(full_pollable.pollable_meta_data).to eq(meta_data)
      end
    end
  end

  describe '#disable_polling' do
    it 'sets the state to \'deactivated\'' do
      full_pollable.disable_polling
      expect(full_pollable.pollable_meta_data.deactivated?).to be(true)
    end

    it 'sets the deactivation reason' do
      full_pollable.disable_polling('It broke')
      expect(full_pollable.pollable_meta_data.deactivation_reason).to eq('It broke')
    end
  end

  describe '#guard' do
    it 'returns a guard instance with the given configured options' do
      key = full_pollable.pollable_configuration.guard_options[:key].call(full_pollable)
      guard = Aeternitas::Guard.new("foo", 1.second, 10.minutes)
      expect(Aeternitas::Guard).to receive(:new).with(key, 1.second, 5.minutes).and_return(guard)
      full_pollable.guard
    end
  end

  describe '#add_source' do
    context 'when the source is new' do
      it 'creates a new source' do
        allow_any_instance_of(Aeternitas::StorageAdapter::File).to receive(:store).and_return(true)
        source = full_pollable.add_source('foobar')
        expect(source.raw_content).to eq('foobar')
        expect(source.persisted?).to be(true)
        expect(full_pollable.sources).to contain_exactly(source)
      end

      it 'logs a created source', tmpFiles: true do
        expect(Aeternitas::Metrics).to receive(:log).with(:pollables_created, FullPollable)
        expect(Aeternitas::Metrics).to receive(:log).with(:sources_created, FullPollable)
        full_pollable.add_source('foobar')
      end
    end

    context 'when the source exists' do
      it 'does not create a new source' do
        allow_any_instance_of(Aeternitas::StorageAdapter::File).to receive(:store).and_return(true)
        old_source = Aeternitas::Source.create(pollable: full_pollable, raw_content: 'foobar')
        expect(full_pollable.add_source('foobar')).to be(nil)
        expect(full_pollable.sources.count).to be(1)
      end

      it 'doesnt log a created source', tmpFiles: true do
        full_pollable.add_source('foobar')
        expect(Aeternitas::Metrics).not_to receive(:log).with(:sources_created, FullPollable)
        full_pollable.add_source('foobar')
      end
    end
  end

  describe '.polling_options' do
    it 'runs the pollable dsl' do
      block = proc { }
      expect(Aeternitas::Pollable::Dsl).to receive(:new) do |c, &b|
        expect(c).to be(FullPollable.pollable_configuration)
        expect(b).to be(block)
      end
      FullPollable.polling_options(&block)
    end
  end

  describe '.create' do
    it 'logs a created pollable' do
      expect(Aeternitas::Metrics).to receive(:log).with(:pollables_created, FullPollable)
      FullPollable.create(name: 'foo')
    end
  end
end