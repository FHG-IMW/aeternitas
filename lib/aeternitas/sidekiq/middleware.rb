module Aeternitas
  module Sidekiq
    # Aeternitas Sidekiq Middleware
    class Middleware

      def call(worker, msg, queue)
        yield
      rescue Aeternitas::Guard::GuardIsLocked => e
        raise e unless worker.is_a? Aeternitas::Sidekiq::PollJob

        # try deleting the sidekiq unique key so the job can be reenqueued
        Aeternitas.redis.del(
          SidekiqUniqueJobs::UniqueArgs.digest(msg)
        )

        # reenqueue the job
        worker.class.client_push msg

        # update the pollables state
        meta_data = Aeternitas::PollableMetaData.find_by(id: msg['args'].first)
        meta_data.enqueue!

        if meta_data.pollable.pollable_configuration.sleep_on_guard_locked
          # put the worker to rest for errors timeout
          sleep_duration = (e.timeout - Time.now).to_i
          sleep(sleep_duration + 1.0) if sleep_duration > 0
        end
      end
    end
  end
end
