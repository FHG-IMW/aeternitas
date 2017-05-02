module Aeternitas
  module Sidekiq
    # Aeternitas Sidekiq Middleware
    class Middleware

      def call(worker, msg, queue)
        yield
      rescue Aeternitas::LockWithCooldown::LockInUseError => e

        # try deleting the sidekiq unique key so the job can be reenqueued
        Aeternitas.redis.del(
          SidekiqUniqueJobs::PayloadHelper.get_payload(msg['class'], msg['queue'], msg['args'])
        )

        # reenqueue the job
        worker.class.client_push msg

        if msg['class'] == 'Aeternitas::Sidekiq::PollJob'
          Aeternitas::PollableMetaData.find_by(id: args.first).enqueue!
        end

        # put the worker to rest for errors timeout
        sleep_duration = e.timeout - Time.now.to_f
        sleep(sleep_duration + 1.0) if sleep_duration > 0
      end
    end
  end
end
