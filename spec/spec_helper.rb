$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'active_record'
require 'aeternitas'
require 'database_cleaner'
require 'memfs'

# configure active record
ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"
load File.dirname(__FILE__) + '/schema.rb'
require File.dirname(__FILE__) + '/pollables.rb'
# configure aeternitas
Aeternitas.configure do |conf|
  conf.redis = { host: "127.0.0.1" }
end

DatabaseCleaner[:active_record].strategy = :transaction
DatabaseCleaner[:redis].strategy = :truncation

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

  config.around(:each, memfs: true) do |example|
    MemFs.activate { example.run }
  end
end