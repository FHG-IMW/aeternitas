require "active_support/all"
require "redis"
require "connection_pool"
require "aeternitas/version"
require "aeternitas/lock_with_cooldown"
require "aeternitas/pollable"
require "aeternitas/pollable_meta_data"
require "aeternitas/polling_frequency"
require "aeternitas/errors"

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
    attr_accessor :redis

    def initialize
      @redis = nil
    end
  end
end
