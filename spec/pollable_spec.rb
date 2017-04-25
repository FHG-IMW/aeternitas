require 'spec_helper'

describe Aeternitas::Pollable do
  let(:simple_pollable) { SimplePollable.create!(name: 'Foo') }
  let(:full_pollable) { FullPollable.create!(name: 'Foo') }

  describe '#execute_poll' do
    context 'when the lock can be acquired' do
      it 'tries to grab the lock' do
        expect(full_pollable).to receive(:with_lock)
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
    end

    context 'when the lock can not be acquired' do
      before(:each) do
        allow(full_pollable).to(
          receive(:with_lock).
          and_raise(Aeternitas::LockWithCooldown::LockInUseError.new('key', 1.hour.from_now))
        )
      end

      it 'does not run the poll_method' do
        begin full_pollable.execute_poll; rescue ; end
        expect(full_pollable.polled).to be nil
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
        begin full_pollable.execute_poll; rescue ; end
        expect(full_pollable.after_polling).to be(nil)
      end

      it 'sets the state to `errored`' do
        begin full_pollable.execute_poll; rescue ; end
        expect(full_pollable.pollable_meta_data.errored?).to be(true)
      end
    end

    context 'when the poll method throws an deactivation error' do
      before(:each) {
        allow(full_pollable).to(
          receive(:poll).and_raise(FullPollable::DeactivationError.new('Foo'))
        )

      }
      it 'deactivates the pollable' do
        expect(full_pollable).to receive(:deactivate).with(FullPollable::DeactivationError.new('Foo')).and_call_original
        full_pollable.execute_poll
        expect(full_pollable.pollable_meta_data.deactivated?).to be(true)
        expect(full_pollable.pollable_meta_data.deactivation_reason).to be('Foo')
      end

      it 'does not run after_poll methods' do
        expect(full_pollable).not_to receive(:_after_poll)
        full_pollable.execute_poll
        expect(full_pollable.after_polling).to be(nil)
      end
    end
  end
end