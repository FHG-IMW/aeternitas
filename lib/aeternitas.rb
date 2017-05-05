require "active_support/all"
require "redis"
require "connection_pool"
require "sidekiq-unique-jobs"
require "aeternitas/version"
require "aeternitas/guard"
require "aeternitas/pollable"
require "aeternitas/pollable_meta_data"
require "aeternitas/source"
require "aeternitas/polling_frequency"
require "aeternitas/errors"
require "aeternitas/storage_adapter"
require "aeternitas/sidekiq"

# Aeternitas
module Aeternitas

  # Get the configured redis connection
  # @return [ConnectionPool::Wrapper] returns a redis connection from the pool
  def self.redis
    @redis ||= ConnectionPool::Wrapper.new(size: 5, timeout: 3) { Redis.new(self.config.redis) }
  end

  # Access the configuration
  # @return [Aeternitas::Configuration] the Aeternitas configuration
  def self.config
    @config ||= Configuration.new
  end

  # Configure Aeternitas
  # @see Aeternitas::Configuration
  # @yieldparam [Aeternitas::Configuration] config the aeternitas configuration
  def self.configure
    yield(self.config)
  end

  # Enqueues all active pollables who's next polling is lower than the current time
  def self.enqueue_due_pollables
    Aeternitas::PollableMetaData.due.find_each do |pollable_meta_data|
      Aeternitas::Sidekiq::PollJob
        .set(queue: pollable_meta_data.pollable.pollable_configuration.queue)
        .perform_async(pollable_meta_data.id)
      pollable_meta_data.enqueue
      pollable_meta_data.save
    end
  end

  # Stores the global Aeternitas configuration
  # @!attribute [rw] redis
  #   Redis configuration hash, Default: nil
  # @!attribute [rw] storage_adapter_config
  #   Storage adapter configuration, See {Aeternitas::StorageAdapter} for configuration options
  # @!attribute [rw] storage_adapter
  #   Storage adapter class. Default: {Aeternitas::StorageAdapter::File}
  class Configuration
    attr_accessor :redis, :storage_adapter, :storage_adapter_config

    def initialize
      @redis = nil
      @storage_adapter = Aeternitas::StorageAdapter::File
      @storage_adapter_config = {
          directory: defined?(Rails) ? File.join(Rails.root, %w[public system raw_data_source_files]) : File.join(Dir.getwd, 'raw_data_source_files')
      }
    end

    # Creates a new StorageAdapter instance with the given options
    # @return [Aeternitas::StoragesAdapter] new storage adapter instance
    def get_storage_adapter
      @storage_adapter.new(storage_adapter_config)
    end
  end
end
