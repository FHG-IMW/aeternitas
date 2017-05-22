$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'active_record'
require 'aeternitas'
require 'database_cleaner'
require 'rspec-sidekiq'

# configure active record
ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"
load File.dirname(__FILE__) + '/schema.rb'
require File.dirname(__FILE__) + '/pollables.rb'
# configure aeternitas
Aeternitas.configure do |conf|
  conf.redis = { host: "127.0.0.1" }
  conf.storage_adapter_config = {
    directory: '/tmp/aeternitas_tests/'
  }
end

DatabaseCleaner[:active_record].strategy = :transaction
DatabaseCleaner[:redis].strategy = :truncation


Sidekiq::Testing.server_middleware do |chain|
  chain.add Aeternitas::Sidekiq::Middleware
end

RSpec::Sidekiq.configure do |config|
  config.clear_all_enqueued_jobs = true
  config.enable_terminal_colours = true
  config.warn_when_jobs_not_processed_by_sidekiq = true
end

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner[:active_record].strategy = :transaction
    DatabaseCleaner[:redis].strategy = :truncation
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  config.around(:each, tmpFiles: true) do |example|
    begin
      example.run
    ensure
      FileUtils.rm_rf(Aeternitas.config.storage_adapter_config[:directory])
    end
  end
end