# Æternitas 

A ruby gem for continuous source retrieval and data integration.

Aeternitas provides means to regularly "poll" resources (i.e. a website, twitter feed or API) and to permanently store the raw results.
By default we avoid putting too much load on external servers and store raw results as compressed files on disk.
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

## Usage

### Create Pollable

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
aeternitas will execute the poll method is determined by the pollable metadata stored in a seperate table and may be
checked using the `next_polling` method on a website (note: there are several advanced error states which may or may not
allow a pollable to be polled).

Assuming you have already setup sidekiq the only thing left is to regularly run `Aeternitas.enqueue_due_pollables`
and have a worker consuming the "polling" queue.

In most cases it makes sense to store polling results as sources to allow further work to be done in seperate jobs.
In above example we already added the `page_content`as a source to the website. Aeternitas thereby only stores a new source
if the sources fingerprint does not yet exist (i.e. MD5 Hash of the page_content). If we wanted to process the word count in 
a seperate job the following implementation would allow to do so.

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

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and spec backed pull requests are welcome on GitHub at https://github.com/FHG-IMW/aeternitas. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

