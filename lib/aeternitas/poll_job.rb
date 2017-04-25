module Aeternitas
  class Polljob
    sidekiq_options unique: true,
                    unique_args: [:pollable_class, :pollable_id],
                    unique_job_expiration: 1.month.to_i,
                    queue: :polling

    sidekiq_retry_in do |count|
      [60,3600,86400,604800][count]
    end

    sidekiq_retries_exhausted do |msg|
      ActiveRecord::Base.transaction do
        meta_data = Aeternitas::PollableMetaData.find_by(id: msg['args'].first)
        meta_data.deactivate
        meta_data.deactivation_message = msg['error_message']
        meta_data.deactivated_at = Time.now
        meta_data.save
      end
    end

    def perform(polling_meta_data_id)
      meta_data = Aeternitas::PollingMetaData.find_by(id: polling_meta_data_id)
      pollable = meta_data.pollable
      pollable.execute_poll
    end
  end
end