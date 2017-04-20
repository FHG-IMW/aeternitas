require 'active_support/duration'
require 'securerandom'

module Aeternitas
  # A distributed lock that can not be acquired after being unlocked for a certain time (cooldown).
  #
  # @example
  #   lock = Ciwor::LockWithCooldown.new("Twitter-MY_API_KEY", 5.seconds)
  #   begin
  #     lock.with_lock do
  #       twitter_client.user_timeline('Darth_Max')
  #     end
  #   rescue Twitter::TooManyRequests => e
  #     lock.sleep_until(e.rate_limit.reset_at)
  #     raise Ciwor::LockWithCooldown::LockInUseError(e.rate_limit.reset_at)
  #   end
  #
  # @!attribute [r] id
  #   @return [String] the locks id
  # @!attribute [r] timeout
  #   @return [ActiveSupport::Duration] the locks timeout duration
  # @!attribute [r] cooldown
  #   @return [ActiveSupport::Duration] cooldown time, in which the lock can't be acquired after being released
  class LockWithCooldown

    attr_reader :id, :timeout, :cooldown, :token

    # Create a new LockWithCooldown
    #
    # @param [String] id Lock id
    # @param [ActiveRecord::Duration] cooldown Cooldown time
    # @param [ActiveRecord::Duration] timeout Lock timeout
    # @return [Aeternitas::LockWithCooldown] Creates a new Instance
    def initialize(id, cooldown, timeout = 10.minutes)
      @id       = id
      @cooldown = cooldown
      @timeout  = timeout
      @token    = SecureRandom.hex(10)
    end

    # Runs a given block if the lock can be acquired and releases the lock afterwards.
    #
    # @raise [Ciwor::LockWithCooldown::LockInUseError] if the lock can not be acquired
    # @example
    #   LockWithCooldown.new("MyId", 5.seconds, 10.minutes).with_lock { do_request() }
    def with_lock
      acquire_lock!
      begin
        yield
      ensure
        unlock
      end
    end

    # Locks the lock until the given time.
    #
    # @param [Time] until_time sleep time
    # @param [String] msg hint why the resource sleeps
    def sleep_until(until_time, msg = nil)
      sleep(until_time, msg)
    end

    # Locks the lock for the given duration.
    #
    # @param [ActiveSupport::Duration] duration sleeping duration
    # @param [String] msg hint why the resource sleeps
    def sleep_for(duration, msg = nil)
      raise ArgumentError, 'duration must be an ActiveRecord::Duration' unless duration.is_a?(ActiveSupport::Duration)
      sleep_until(duration.from_now, msg)
    end

    private

    # Tries to acquire the lock.
    #
    # @example The Redis value looks like this
    #   {
    #     id: 'MyId'
    #     state: 'processing'
    #     timeout: '3600'
    #     cooldown: '5'
    #     locked_until: '2017-01-01 10:10:00'
    #     token: '1234567890'
    #   }
    # @raise [Ciwor::LockWithCooldown::LockInUseError] if the lock can not be acquired
    def acquire_lock!
      payload = {
        'id' => @id,
        'state' => 'processing',
        'timeout' => @timeout,
        'cooldown' => @cooldown,
        'locked_until' => @timeout.from_now,
        'token' => @token
      }

      has_lock = Aeternitas.redis.set(@id, JSON.unparse(payload), ex: @timeout.to_i, nx: true)

      raise(LockInUseError.new(@id, get_timeout)) unless has_lock
    end

    # Tries to unlock the lock. This starts the cooldown phase.
    #
    # @example The Redis value looks like this
    #   {
    #     id: 'MyId'
    #     state: 'cooldown'
    #     timeout: '3600'
    #     cooldown: '5'
    #     locked_until: '2017-01-01 10:00:05'
    #     token: '1234567890'
    #   }
    def unlock
      return unless holds_lock?

      payload = {
          'id' => @id,
          'state' => 'cooldown',
          'timeout' => @timeout,
          'cooldown' => @cooldown,
          'locked_until' => @cooldown.from_now,
          'token' => @token
      }

      Aeternitas.redis.set(@id, JSON.unparse(payload), ex: @cooldown.to_i)
    end

    # Locks the lock until the given date.
    #
    # @example The Redis value looks like this
    #   {
    #     id: 'MyId'
    #     state: 'sleeping'
    #     timeout: '3600'
    #     cooldown: '5'
    #     locked_until: '2017-01-01 13:00'
    #     message: "API Quota Reached"
    #   }
    # @todo Should this raise an error if the lock is not owned by this instance?
    # @param [Time] sleep_timeout for how long will the lock sleep
    # @param [String] msg hint why the resource sleeps
    def sleep(sleep_timeout, msg = nil)

      payload = {
          'id' => @id,
          'state' => 'sleeping',
          'timeout' => @timeout,
          'cooldown' => @cooldown,
          'locked_until' => sleep_timeout
      }
      payload.merge(message: msg) if msg

      Aeternitas.redis.set(@id, JSON.unparse(payload), ex: (sleep_timeout - Time.now).seconds.to_i)
    end

    # Checks if this instance holds the lock. This is done by retrieving the value from redis and
    # comparing the token value. If they match, than the lock is held by this instance.
    #
    # @todo Make the check atomic
    # @return [Boolean] if the lock is held by this instance
    def holds_lock?
      payload = get_payload
      payload['token'] == @token && payload['state'] == 'processing'
    end

    # Returns the locks current timeout.
    #
    # @return [Time] the locks current timeout
    def get_timeout
      payload = get_payload
      payload['state'] == 'processing' ? payload['cooldown'].to_i.seconds.from_now : Time.parse(payload['locked_until'])
    end

    # Retrieves the locks payload from redis.
    #
    # @return [Hash] the locks payload
    def get_payload
      value = Aeternitas.redis.get(@id)
      return {} unless value
      JSON.parse(value)
    end

    # Custom error class thrown when the lock can not be acquired
    # @!attribute [r] timeout
    #   @return [Time] the locks current timeout
    class LockInUseError < StandardError
      attr_reader :timeout

      def initialize(resource_id, timeout, reason = nil)
        msg = "Resource '#{resource_id}' is locked until #{timeout}."
        msg += " Reason: #{reason}" if reason
        super(msg)
        @timeout = timeout
      end
    end
  end
end