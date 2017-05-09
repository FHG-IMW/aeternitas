require 'spec_helper'

describe Aeternitas::PollableMetaData do
  let(:simple_pollable) { SimplePollable.create!(name: 'Foo') }
  let(:full_pollable) { FullPollable.create!(name: 'Foo') }

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
end