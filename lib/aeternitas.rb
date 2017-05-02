require "active_support/all"
require "redis"
require "connection_pool"
require "aeternitas/version"
require "aeternitas/lock_with_cooldown"
require "aeternitas/pollable"
require "aeternitas/pollable_meta_data"
require "aeternitas/source"
require "aeternitas/polling_frequency"
require "aeternitas/errors"
require "aeternitas/storage_adapter"

module Aeternitas
  def self.redis
    @redis ||= ConnectionPool::Wrapper.new(size: 5, timeout: 3) { Redis.new(self.config.redis) }
  end

  def self.config
    @config ||= Configuration.new
  end

  def self.configure
    yield(self.config)
  end

  class Configuration
    attr_accessor :redis, :storage_adapter_config

    def initialize
      @redis = nil
      @storage_adapter = Aeternitas::StorageAdapter::File
      @storage_adapter_config = {
          directory: defined?(Rails) ? File.join(Rails.root, %w[public system raw_data_source_files]) : File.join(Dir.getwd, 'raw_data_source_files')
      }
    end

    def get_storage_adapter
      @storage_adapter.new(storage_adapter_config)
    end
  end
end
