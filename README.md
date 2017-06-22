![Aeternitas](https://github.com/FHG-IMW/aeternitas/blob/master/logo.png?raw=true)

[![Build Status](https://travis-ci.org/FHG-IMW/aeternitas.svg?branch=master)](https://travis-ci.org/FHG-IMW/aeternitas)

A ruby gem for continuous source retrieval and data integration.

Aeternitas provides means to regularly "poll" resources (i.e. a website, twitter feed or API) and to permanently store retrieved results.
By default it avoids putting too much load on external servers and stores raw results as compressed files on disk.
Aeternitas can be configured to a wide variety of polling strategies (e.g. frequencies, cooldown periods, ignoring exceptions, deactivating resources, ...).

Aeternitas is meant to be included in a rails application and expects a working sidekiq/redis setup and any kind of database backend.
All meta-data is stored in two database tables (aeternitas_pollable_meta_data and aeternitas_sources) while metrics are stored in Redis
and raw data as compressed files on disk.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'aeternitas'
```

And then execute:

    $ bundle install
    $ rails generate aeternitas:install
    $ rake db:migrate

to install gem and generate tables and initializers needed for aeternitas.

## Quickstart

Aeternitas expects you wanting to store single pollables as ActiveRecord Objects. For instance you might want to
monitor several Websites for the usage of the word æternitas and store the websites old states for later analysis.
Using Aeternitas you would create your website model and tables

    $ rails generate model Website url:string aeternitas_word_count:integer

And then include Aeternitas


```ruby
class Website < ApplicationRecord
  include Aeternitas::Pollable

  polling_options do
    polling_frequency :weekly
  end
end
```

For now we are satisfied with aeternitas default setting [TODO:link] except for the polling_frequency. We only want to 
check once a week.
Next up we have to implement the websites `poll` method.

```ruby
  def poll
    page_content = Net::HTTP.get(URI.parse(self.url))
    add_source(page_content) #store the retrieved page permanently
    aeternitas_word_count = page_content.scan('aeternitas').size
    update(aeternitas_word_count: aeternitas_word_count)
  end
```

The poll method is called every time a pollable is good to go. In our example this would be once a week. The time at which
aeternitas will execute the poll method is determined by the pollable metadata stored in a separate table and may be
checked using the `next_polling` method on a website (note: there are several advanced error states which may or may not
allow a pollable to be polled).

Assuming you have already setup sidekiq the only thing left is to regularly run `Aeternitas.enqueue_due_pollables`
and have a worker consuming the "polling" queue.

In most cases it makes sense to store polling results as sources to allow further work to be done in separate jobs.
In above example we already added the `page_content`as a source to the website. Aeternitas thereby only stores a new source
if the sources fingerprint does not yet exist (i.e. MD5 Hash of the page_content). If we wanted to process the word count in 
a separate job the following implementation would allow to do so.

```ruby
class Website < ApplicationRecord
  include Aeternitas::Pollable

  polling_options do
    polling_frequency :weekly
  end
  
  def poll
    page_content = Net::HTTP.get(URI.parse(self.url))
    new_source = add_source(page_content) #returns nil if source already exists
    CountWordJob.perform_async(new_source.id) if new_source
    
    
  end
end

class CountWordJob
  include Sidekiq::Worker
  
  def perform(source_id)
    source = Aeternitas::Source.find(source_id)
    page_content = source.raw_content
    aeternitas_word_count = page_content.scan('aeternitas').size
    website = source.pollable
    website.update(aeternitas_word_count: aeternitas_word_count)
  end
end
```

## Configuration

### Global Configuration

In this configuration you can specify the global settings for Æternitas. The configuration should be stored in
`config/initializers/aeternitas.rb`

#### redis

This option specifies the redis connection details. Æternitas uses redis to for resource locking and to store statistics.

```ruby
Aeternitas.configure do |config| 
  config.redis = {host: localhost, port: 6379}
end
```    

For configuration options you can have a look here: [redis-rb](https://github.com/redis/redis-rb)

#### storage_adapter
_Default: Aeternitas::StorageAdapter::File_

Æternitas by default stores source file in compressed files on disk. If you however want to store them in another way you 
can do so easily by implementing the `Aeternitas::StorageAdapter` interface. For an example you can have a look at 
`Aeternitas::StorageAdapter::File`.
To specify which storage adapter Æternitas should use, just pass the class name to this option:

```ruby
Aeternitas.configure do |config| 
  config.storage_adapter = Aeternitas::StorageAdapter::File
end
```

#### storage_adapter_options

Some storage adapter need some extra configuration. The file adapter for example needs to now where to store the files:

```ruby
Aeternitas.configure do |config| 
  config.storage_adapter_options = {
    directory: File.join(Rails.root, 'public', 'sources')
  }
end
```

### Pollable Configuration

Pollables can be configured on a per class base using the `polling_options` block.


#### polling_frequency
_Default: :daily_

This option controls how often a pollable is polled and can be configured in two different ways.
Either use one of the presets specified in `Aeternitas::PollingFrequency` by specifiey the presets name as a symbol

```ruby
polling_options do
  polling_frequency :weekly
end
```

If want to specify a more complex polling schema you can also us a custom method which returns the time and date of the
next polling. For example if you want to increase the frequency depending on the pollables age you could use the
following method:

```ruby
polling_options do
  # set frequency depending elements age (+ 1 month for every 3 months)
  polling_frequency ->(context) { 1.month + (Time.now - context.created_at).to_i / 3.month * 1.month }
end
```

#### before_polling
_Default: []_

Specifies methods that are run before the polling is executed. You can either specify a method name or a lamba
```ruby
polling_options do
  # run the pollables `foo` and `bar` methods
  before_polling :foo, :bar 
  # run a custom block
  before_polling ->(pollable) { puts "About to poll #{pollable.id}"}
end
```

#### after_polling

Specify methods run after polling was successful. See __before_polling__

#### deactivation_errors
_Default: []_

Specify error clases which, once they occur, will instantly deactivate the pollable. This can be useful for example if 
the error implied that the resource does not exist any more.

```ruby
polling_options do
  # deactivate the pollable if the tweet was not found
  deactivation_errors Twitter::Error::NotFound
end
```

#### ignored_errors
_Default: []_

Errors specified as ignored errors are wrapped within `Aeternitas::Errors::Ignored`. which is then raised instead.
This is supposed to be used in combination with error tracking systems like Airbrake. Instead globally telling Airbrake which errors to 
ignore, you can do this on a per pollable basis

```ruby
polling_options do
  # don't log an error if the twitter api is down
  ignored_errors Twitter::Error::ServiceUnavailable
end
```

#### sleep_on_guard_lock
_Default: false_

With this option set to true, if a pollable can't acquire the lock, it will sleep until the guard_timeout expires, 
effectively blocking the Sidekiq queue from processing any other jobs. 
This should *only* be used, if you know that all the jobs within this queue will try to access the same resource and you want to pause the entire queue.  
 
#### queue
_Default: 'polling'_

This option specifies the Sidekiq queue into which the poll job will be enqueued.

#### lock_key
_Default: "#{obj.class.name}"_

This option specifies the lock key. This can be done by either specifying a method name or a custom block. Default is to lock on pollable class level. Therefor only one job at a time per pollable class will be executed to avoid DDOSing by accident.

```ruby
polling_options do
  # use the urls host as lock key
  lock_key ->(website) { URI.parse(website.url).host }
end
```



## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and spec backed pull requests are welcome on GitHub at https://github.com/FHG-IMW/aeternitas. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

