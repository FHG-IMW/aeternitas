require 'spec_helper'

class TestJob < Aeternitas::Sidekiq::PollJob
  class_attribute :pushed

  def perform(id)
    raise Aeternitas::Guard::GuardIsLocked.new('foo', 10.second.from_now)
  end

  def self.client_push(msg)
    value = self.pushed
    self.pushed = true
    super(msg) unless value
  end
end

describe Aeternitas::Sidekiq::Middleware do
  around(:each) do |example|
    TestJob.pushed = false
    Sidekiq::Testing.inline! do
      example.run
    end
  end

  let(:meta_data) { FullPollable.create(name: 'foo').pollable_meta_data }

  it 'tries to delete the Sidekiq unique key' do
    expect(SidekiqUniqueJobs::UniqueArgs).to(
      receive(:digest)
    ).exactly(2).times.and_return("key")
    TestJob.perform_async(meta_data.id)
  end

  it 'enqueues the job again' do
    expect(TestJob).to receive(:client_push).twice.and_call_original
    TestJob.perform_async(meta_data.id)
  end

  it 'updates the pollables state' do
    meta_data.update!(state: 'errored')
    TestJob.perform_async(meta_data.id)
    meta_data.reload
    expect(meta_data.enqueued?).to be(true)
  end

  it 'does not sleep if sleep_on_guard_locked is false' do
    expect_any_instance_of(Object).not_to receive(:sleep)
    TestJob.perform_async(meta_data.id)
  end

  it 'sleeps if sleep_on_guard_locked is true' do
    expect_any_instance_of(Object).to(
      receive(:sleep).with(be_within(1.second).of(10.seconds))
    )

    simple_pollable = SimplePollable.create(name: 'foo')
    TestJob.perform_async(simple_pollable.pollable_meta_data.id)
  end
end
