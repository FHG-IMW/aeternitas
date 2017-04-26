class SimplePollable < ActiveRecord::Base
  include Aeternitas::Pollable

  attr_accessor :polled

  polling_options do
    polling_frequency :daily
  end

  def poll
    @polled = true
  end
end

class FullPollable < ActiveRecord::Base
  include Aeternitas::Pollable

  class DeactivationError < StandardError ; end
  class IgnoredError < StandardError ; end

  attr_accessor :before_polling, :after_polling, :polled

  polling_options do
    polling_frequency ->(pollable) { pollable.next_polling + 3.days }
    deactivate_on DeactivationError
    ignore_error IgnoredError, ArgumentError

    before_polling ->(pollable) { pollable.before_polling = [:block] }
    before_polling :do_something_before

    after_polling ->(pollable) { pollable.after_polling = [:block] }
    after_polling :do_something_after

    queue 'full_pollables'

    lock_options(
      lock_key: ->(pollable) { "#{pollable.created_at}-#{pollable.id}" },
      cooldown: 1.second,
      timeout:  2.years
    )
  end

  def poll
    @polled = true
  end

  def do_something_before
    @before_polling << :method
  end

  def do_something_after
    @after_polling << :method
  end
end