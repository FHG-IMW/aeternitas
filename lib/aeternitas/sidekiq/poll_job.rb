require 'sidekiq'
module Aeternitas
  module Sidekiq
    # Sidekiq Worker that is responsible for executing the polling.
    class PollJob
      include ::Sidekiq::Worker

      sidekiq_options unique: :until_executed,
                      unique_args: [:pollable_meta_data_id],
                      unique_job_expiration: 1.month.to_i,
                      queue: :polling,
                      retry: 4

      sidekiq_retry_in do |count|
        [60, 3600, 86400, 604800][count]
      end

      sidekiq_retries_exhausted do |msg|
        deactivate_pollable(msg['args'].first, msg['error_message'])
      end

      def self.deactivate_pollable(meta_data_id, error_message)
        ActiveRecord::Base.transaction do
          meta_data = Aeternitas::PollableMetaData.find_by(id: meta_data_id)
          meta_data.deactivate
          meta_data.deactivation_reason = error_message
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
