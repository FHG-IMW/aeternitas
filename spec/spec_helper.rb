$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "aeternitas"
require "database_cleaner"

Aeternitas.configure do |conf|
  conf.redis = { host: "127.0.0.1" }
end

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end