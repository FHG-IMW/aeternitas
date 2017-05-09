require 'spec_helper'

describe Aeternitas::Sidekiq::PollJob do
  it { is_expected.to be_processed_in :polling }
  it { is_expected.to be_retryable 4 }
  # it { is_expected.to be_unique } -> Does not work with the new version

  describe 'retries exhausted' do
    it 'deactivates the pollable' do
      msg = {
          'args' => [42],
          'error_message' => 'ErrorMsg'
      }

      Aeternitas::Sidekiq::PollJob.within_sidekiq_retries_exhausted_block(msg) {
        expect(Aeternitas::Sidekiq::PollJob).to(
          receive(:deactivate_pollable).with(42, 'ErrorMsg')
        )
      }
    end
  end

  describe '.deactivate_pollable' do
    let(:meta_data) { FullPollable.create(name: 'Foo').pollable_meta_data }
    let(:error_msg) { 'ErrorMsg' }
    before(:each) {
      Aeternitas::Sidekiq::PollJob.deactivate_pollable(meta_data.id, error_msg)
      meta_data.reload
    }

    it 'deactivates the pollable' do
      expect(meta_data.deactivated?).to be(true)
    end

    it 'sets the deactivation message' do
      expect(meta_data.deactivation_reason).to eq(error_msg)
    end

    it 'sets the deactivation date to current date' do
      expect(meta_data.deactivated_at).to be_within(1.second).of(Time.now)
    end
  end
end
