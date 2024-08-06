require 'spec_helper'

describe Aeternitas do
  it 'has a version number' do
    expect(Aeternitas::VERSION).not_to be nil
  end

  describe '.enqueue_due_pollables' do
    it 'enqueues all due pollables with next polling < Time.now ' do
      due_pollable = FullPollable.create(name: 'Foo')
      meta_data = due_pollable.pollable_meta_data
      meta_data.update!(state: 'waiting', next_polling: 10.days.ago)
      Aeternitas.enqueue_due_pollables
      expect(Aeternitas::Sidekiq::PollJob).to(
        have_enqueued_job(due_pollable.pollable_meta_data.id)
      )
    end

    it 'enqueues jobs in the right queue' do
      FullPollable.create(name: 'Foo')
      SimplePollable.create(name: 'Bar')
      Aeternitas.enqueue_due_pollables
      expect(Sidekiq::Queues['full_pollables'].size).to be(1)
      expect(Sidekiq::Queues['polling'].size).to be(1)
    end

    it 'does not enqueue pollables with state other than waiting' do
      enqueued_pollable = FullPollable.create(name: 'Foo')
      meta_data = enqueued_pollable.pollable_meta_data
      meta_data.update!(state: 'enqueued', next_polling: 10.days.ago)
      Aeternitas.enqueue_due_pollables
      expect(Aeternitas::Sidekiq::PollJob).not_to have_enqueued_job(enqueued_pollable.pollable_meta_data.id)
    end

    it 'does not enqueue undue pollables' do
      undue_pollable = FullPollable.create(name: 'Foo')
      meta_data = undue_pollable.pollable_meta_data
      meta_data.update!(state: 'waiting', next_polling: 10.days.from_now)
      Aeternitas.enqueue_due_pollables
      expect(Aeternitas::Sidekiq::PollJob).not_to have_enqueued_job(undue_pollable.pollable_meta_data.id)
    end
  end
end
