require 'spec_helper'

describe Aeternitas::Sidekiq::PollJob do
  it { is_expected.to be_processed_in :polling }
  it { is_expected.to be_retryable 4 }
  # it { is_expected.to be_unique } -> Does not work with the new version

  describe 'retries exhausted' do
    let(:meta_data) { FullPollable.create(name: 'Foo').pollable_meta_data }

    it 'deactivates the pollable' do
      msg = {
          'args' => [meta_data.id],
          'error_message' => 'ErrorMsg'
      }

      Aeternitas::Sidekiq::PollJob.within_sidekiq_retries_exhausted_block(msg) {
        expect(Aeternitas::PollableMetaData).to(
          receive(:find_by).with(id: meta_data.id).and_return(meta_data)
        )

        expect(meta_data).to(
          receive(:disable_polling).with(msg['error_message'])
        )
      }
    end
  end
end
