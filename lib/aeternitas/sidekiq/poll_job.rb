module Aeternitas
  module Sidekiq
    # Sidekiq Worker that is responsible for executing the polling.
    class Polljob
      include Sidekiq::Worker

      sidekiq_options unique: true,
                      unique_args: [:pollable_meta_data_id],
                      unique_job_expiration: 1.month.to_i,
                      queue: :polling,
                      retry: 4

      sidekiq_retry_in do |count|
        [60, 3600, 86400, 604800][count]
      end

      sidekiq_retries_exhausted do |msg|
        ActiveRecord::Base.transaction do
          meta_data = Aeternitas::PollableMetaData.find_by(id: msg['args'].first)
          meta_data.deactivate
          meta_data.deactivation_message = msg['error_message']
          meta_data.deactivated_at = Time.now
          meta_data.save!
        end
      end

      def perform(pollable_meta_data_id)
        meta_data = Aeternitas::PollableMetaData.find_by(id: pollable_meta_data_id)
        pollable = meta_data.pollable
        pollable.execute_poll
      end
    end
  end
end
